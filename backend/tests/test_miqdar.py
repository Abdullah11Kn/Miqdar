from __future__ import annotations

import io
import shutil
import sqlite3
import tempfile
import unittest
import json
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from miqdar_backend.alert_engine import evaluate_alerts
from miqdar_backend.database import (
    connect, health_profile_for_user, history, update_goals, update_health_profile,
)
from miqdar_backend.recognition import (
    RECOGNITION_CACHE, GeminiRecognitionProvider, detect_new_food,
)
from miqdar_backend.recommendations import normalise_profile, recommend_meals
from miqdar_backend.service import (
    InvalidImageError, NotFoodError, ProviderUnavailableError,
    UnmappedFoodError, decode_image, recognize_food,
)


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DB = ROOT / "database" / "miqdar_nutrition.db"


def image_bytes(color: tuple[int, int, int]) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (96, 96), color).save(buffer, format="PNG")
    return buffer.getvalue()


class MiqdarAcceptanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = Path(tempfile.mkdtemp(prefix="miqdar-test-"))
        self.db_path = self.temp_dir / "test.db"
        shutil.copy2(SOURCE_DB, self.db_path)
        RECOGNITION_CACHE.clear()
        self._env = patch.dict("os.environ", {"MIQDAR_RECOGNITION_PROVIDER": "mock"})
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()
        shutil.rmtree(self.temp_dir)

    def test_database_integrity_and_provenance(self) -> None:
        with connect(self.db_path) as connection:
            self.assertEqual(connection.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            missing_sources = connection.execute(
                """SELECT COUNT(*) FROM foods f LEFT JOIN source_registry s ON s.source_id=f.source_id
                   WHERE s.source_id IS NULL"""
            ).fetchone()[0]
            self.assertEqual(missing_sources, 0)
            self.assertGreaterEqual(connection.execute("SELECT COUNT(*) FROM foods").fetchone()[0], 12)

    def test_at_least_90_days_are_queryable(self) -> None:
        with connect(self.db_path) as connection:
            items = history(connection, "demo-user", 90)
            distinct_days = {item["eaten_at"][:10] for item in items}
            self.assertGreaterEqual(len(distinct_days), 90)

    def test_health_alert_is_evaluated_within_four_seconds(self) -> None:
        with connect(self.db_path) as connection:
            update_goals(connection, "demo-user", {"sugar_g": 5})
            alerts, elapsed_ms = evaluate_alerts(
                connection,
                user_id="demo-user",
                nutrients={
                    "calories_kcal": 277,
                    "protein_g": 1.81,
                    "carbohydrate_g": 74.97,
                    "fat_g": 0.15,
                    "sugar_g": 66.47,
                    "fiber_g": 6.7,
                    "sodium_mg": 1,
                    "potassium_mg": 696,
                },
            )
            self.assertTrue(any(item["nutrient_key"] == "sugar_g" for item in alerts))
            self.assertLessEqual(elapsed_ms, 4000)

    def test_recognition_maps_cloud_candidate_to_predefined_database(self) -> None:
        with connect(self.db_path) as connection:
            result = recognize_food(
                connection,
                user_id="demo-user",
                image_bytes=image_bytes((117, 72, 35)),
                weight_g=42,
                hint="medjool dates",
            )
            self.assertEqual(result["food"]["food_id"], "food_dates_medjool")
            self.assertEqual(result["weight_g"], 42)
            self.assertTrue(result["timing"]["alert_slo_met"])

    def test_sequential_detection_requires_weight_and_image_change(self) -> None:
        first = image_bytes((255, 255, 255))
        second = image_bytes((30, 120, 45))
        unchanged, _, _ = detect_new_food(
            current_bytes=first,
            previous_bytes=first,
            current_weight_g=150,
            previous_weight_g=100,
        )
        changed, similarity, delta = detect_new_food(
            current_bytes=second,
            previous_bytes=first,
            current_weight_g=150,
            previous_weight_g=100,
        )
        self.assertFalse(unchanged)
        self.assertTrue(changed)
        self.assertLess(similarity, 0.985)
        self.assertEqual(delta, 50)

    def test_health_profile_and_meal_recommendations_use_history(self) -> None:
        with connect(self.db_path) as connection:
            profile = normalise_profile({
                "conditions": ["diabetes", "hypertension", "unsupported"],
                "dietary_preferences": ["vegetarian"],
                "allergens": ["nuts"],
                "disliked_foods": [],
            })
            update_health_profile(connection, "demo-user", profile)
            self.assertEqual(
                health_profile_for_user(connection, "demo-user")["conditions"],
                ["diabetes", "hypertension"],
            )
            result = recommend_meals(
                connection, user_id="demo-user", profile=profile, limit=4
            )
            self.assertEqual(result["method"], "transparent_database_scoring_v1")
            self.assertEqual(len(result["suggestions"]), 4)
            self.assertNotIn(
                "food_almonds_raw",
                {item["food_id"] for item in result["suggestions"]},
            )
            self.assertTrue(all(item["why"] for item in result["suggestions"]))
            self.assertEqual(result["context"]["history_window_days"], 14)

    def test_gemini_provider_parses_structured_candidates(self) -> None:
        response_body = {
            "candidates": [{
                "content": {"parts": [{
                    "text": json.dumps({
                        "candidates": [
                            {"label": "medjool dates", "confidence": 0.98},
                            {"label": "ajwa dates", "confidence": 0.02},
                        ]
                    })
                }]}
            }]
        }
        provider = GeminiRecognitionProvider(
            api_key="test-key",
            model="gemini-3.1-flash-lite",
            api_base="https://generativelanguage.googleapis.com",
        )
        with patch(
            "urllib.request.urlopen",
            return_value=io.BytesIO(json.dumps(response_body).encode("utf-8")),
        ) as mocked:
            candidates = provider.recognize(image_bytes((117, 72, 35)))
        self.assertEqual(candidates[0].label, "medjool dates")
        self.assertEqual(candidates[0].confidence, 0.98)
        request = mocked.call_args.args[0]
        self.assertEqual(request.get_header("X-goog-api-key"), "test-key")
        self.assertIn("gemini-3.1-flash-lite:generateContent", request.full_url)

    def test_saudi_dishes_database_resolution(self) -> None:
        with connect(self.db_path) as connection:
            test_cases = [
                ("Chicken Kabsa", "food_chicken_kabsa", "Chicken Kabsa"),
                ("كبسة دجاج", "food_chicken_kabsa", "Chicken Kabsa"),
                ("Chicken Shawarma", "food_chicken_shawarma", "Chicken Shawarma Wrap"),
                ("شاورما", "food_chicken_shawarma", "Chicken Shawarma Wrap"),
                ("عريكة جنوبية", "food_areeka_southern", "Southern Areeka"),
                ("Saleeg", "food_saleeg", "Saleeg"),
                ("سليق", "food_saleeg", "Saleeg"),
                ("Pizza Pepperoni", "food_pizza_pepperoni", "Pizza Pepperoni"),
            ]
            for label, expected_id, expected_name in test_cases:
                result = recognize_food(
                    connection,
                    user_id="demo-user",
                    image_bytes=image_bytes((150, 100, 50)),
                    weight_g=250,
                    hint=label,
                )
                self.assertEqual(result["food"]["food_id"], expected_id)
                self.assertEqual(result["food"]["name_en"], expected_name)
                self.assertGreater(result["nutrients"]["calories_kcal"], 0)

    def test_gemini_image_preprocessing_and_caching(self) -> None:
        large_img = Image.new("RGBA", (1200, 800), (200, 100, 50, 255))
        buf = io.BytesIO()
        large_img.save(buf, format="PNG")
        raw_bytes = buf.getvalue()

        prepared_bytes, mime = GeminiRecognitionProvider._prepare_image(raw_bytes, max_side=384)
        self.assertEqual(mime, "image/jpeg")
        with Image.open(io.BytesIO(prepared_bytes)) as downscaled:
            self.assertLessEqual(max(downscaled.size), 384)
            self.assertEqual(downscaled.mode, "RGB")

        response_body = {
            "candidates": [{
                "content": {"parts": [{
                    "text": json.dumps({
                        "candidates": [
                            {"label": "chicken kabsa", "confidence": 0.95},
                        ]
                    })
                }]}
            }]
        }
        provider = GeminiRecognitionProvider(
            api_key="test-key",
            model="gemini-3.1-flash-lite",
            api_base="https://generativelanguage.googleapis.com",
        )
        with patch(
            "urllib.request.urlopen",
            side_effect=lambda *a, **k: io.BytesIO(json.dumps(response_body).encode("utf-8")),
        ) as mocked:
            res1 = provider.recognize(raw_bytes)
            self.assertFalse(provider.last_cache_hit)
            # The server builds a new provider per request; the cache must survive that.
            second_provider = GeminiRecognitionProvider(api_key="test-key")
            res2 = second_provider.recognize(raw_bytes)
            self.assertTrue(second_provider.last_cache_hit)
            self.assertEqual(second_provider.last_model_used, "gemini-3.1-flash-lite")
            self.assertEqual(mocked.call_count, 1)
            self.assertEqual(res1[0].label, "chicken kabsa")
            self.assertEqual(res2[0].label, "chicken kabsa")
            # A different hint must not reuse the cached answer.
            second_provider.recognize(raw_bytes, hint="lamb mandi")
            self.assertEqual(mocked.call_count, 2)

    def test_gemini_falls_back_to_secondary_model_on_overload(self) -> None:
        import urllib.error

        ok_body = {
            "candidates": [{"content": {"parts": [{"text": json.dumps(
                {"candidates": [{"label": "jareesh", "confidence": 0.9}]}
            )}]}}]
        }
        calls: list[str] = []

        def fake_urlopen(request, timeout=0):
            calls.append(request.full_url)
            if "gemini-3.1-flash-lite" in request.full_url:
                raise urllib.error.HTTPError(request.full_url, 503, "overloaded", {}, io.BytesIO(b"busy"))
            return io.BytesIO(json.dumps(ok_body).encode("utf-8"))

        provider = GeminiRecognitionProvider(
            api_key="k", fallback_models=("gemini-3.5-flash-lite",),
        )
        with patch("urllib.request.urlopen", side_effect=fake_urlopen):
            result = provider.recognize(image_bytes((10, 200, 10)))
        self.assertEqual(result[0].label, "jareesh")
        self.assertEqual(provider.last_model_used, "gemini-3.5-flash-lite")
        self.assertEqual(len(calls), 2)

    def test_top_candidates_are_mapped_with_their_own_nutrients(self) -> None:
        with connect(self.db_path) as connection:
            result = recognize_food(
                connection, user_id="demo-user",
                image_bytes=image_bytes((90, 60, 30)), weight_g=200, hint="lamb kabsa",
            )
        self.assertEqual(result["candidates"][0]["rank"], 1)
        self.assertTrue(result["candidates"][0]["selected"])
        for candidate in result["candidates"]:
            self.assertIsNotNone(candidate["food"])
            self.assertGreater(candidate["nutrients"]["calories_kcal"], 0)
        self.assertEqual(result["hint_used"], "lamb kabsa")

    def test_recognition_failures_are_classified(self) -> None:
        import urllib.error

        from miqdar_backend.recognition import Candidate

        class FakeProvider:
            name = "fake"

            def __init__(self, labels: list[str]) -> None:
                self.labels = labels

            def recognize(self, image_bytes: bytes, hint: str | None = None):
                return [Candidate(label, 0.5) for label in self.labels]

        def run(labels: list[str]) -> None:
            with patch("miqdar_backend.service.configured_provider", return_value=FakeProvider(labels)):
                with connect(self.db_path) as connection:
                    recognize_food(connection, user_id="demo-user",
                                   image_bytes=image_bytes((1, 1, 1)), weight_g=50)

        with self.assertRaises(NotFoodError):
            run(["not food"])
        with self.assertRaises(UnmappedFoodError) as ctx:
            run(["pad thai", "ramen"])
        self.assertEqual(ctx.exception.to_dict()["error"], "FOOD_NOT_IN_DATABASE")
        self.assertEqual(len(ctx.exception.to_dict()["candidates"]), 2)
        with self.assertRaises(InvalidImageError):
            decode_image("%%%not-base64%%%")

        env = {"MIQDAR_RECOGNITION_PROVIDER": "gemini", "GEMINI_API_KEY": "k",
               "GEMINI_FALLBACK_MODELS": "gemini-3.5-flash-lite"}
        with patch.dict("os.environ", env), \
                patch("urllib.request.urlopen", side_effect=urllib.error.URLError("no network")), \
                connect(self.db_path) as connection, \
                self.assertRaises(ProviderUnavailableError):
            recognize_food(connection, user_id="demo-user",
                           image_bytes=image_bytes((5, 5, 5)), weight_g=50)


if __name__ == "__main__":
    unittest.main()

