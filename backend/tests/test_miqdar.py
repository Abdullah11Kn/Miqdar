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
from miqdar_backend.recognition import GeminiRecognitionProvider, detect_new_food
from miqdar_backend.recommendations import normalise_profile, recommend_meals
from miqdar_backend.service import recognize_food


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

    def tearDown(self) -> None:
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


if __name__ == "__main__":
    unittest.main()
