from __future__ import annotations

import base64
import hashlib
import io
import json
import math
import os
import urllib.error
import urllib.request
import threading
from collections import OrderedDict
from dataclasses import dataclass
from typing import Protocol

from PIL import Image, ImageOps, ImageStat


@dataclass(frozen=True)
class Candidate:
    label: str
    confidence: float


class _CandidateCache:
    """Process-wide, thread-safe LRU cache of recognition results.

    The provider object is re-created for every request, so the cache must live
    at module level to be useful. Keys include the model and hint so a changed
    image, hint, or model never returns a stale answer.
    """

    def __init__(self, max_items: int = 256) -> None:
        self.max_items = max_items
        self._items: OrderedDict[str, tuple[list[Candidate], str]] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: str) -> tuple[list[Candidate], str] | None:
        with self._lock:
            value = self._items.get(key)
            if value is not None:
                self._items.move_to_end(key)
            return value

    def put(self, key: str, candidates: list[Candidate], model: str) -> None:
        with self._lock:
            self._items[key] = (list(candidates), model)
            self._items.move_to_end(key)
            while len(self._items) > self.max_items:
                self._items.popitem(last=False)

    def clear(self) -> None:
        with self._lock:
            self._items.clear()


RECOGNITION_CACHE = _CandidateCache()


class RecognitionProvider(Protocol):
    name: str

    def recognize(self, image_bytes: bytes, hint: str | None = None) -> list[Candidate]: ...


class MockRecognitionProvider:
    name = "mock-offline"
    labels = (
        "medjool dates", "white rice", "chicken breast", "hummus",
        "banana", "apple", "cucumber", "tomato", "boiled egg", "almonds",
    )

    def recognize(self, image_bytes: bytes, hint: str | None = None) -> list[Candidate]:
        if hint:
            label = hint.casefold().strip()
        else:
            digest = hashlib.sha256(image_bytes or b"miqdar-demo").digest()
            label = self.labels[digest[0] % len(self.labels)]
        alternates = [item for item in self.labels if item != label][:2]
        return [Candidate(label, 0.94), Candidate(alternates[0], 0.04), Candidate(alternates[1], 0.02)]


class RemoteCloudRecognitionProvider:
    """Provider-neutral adapter. The remote endpoint must return candidates."""

    name = "remote-cloud"

    def __init__(self, endpoint: str, api_key: str) -> None:
        self.endpoint = endpoint
        self.api_key = api_key

    def recognize(self, image_bytes: bytes, hint: str | None = None) -> list[Candidate]:
        payload = json.dumps({
            "image_base64": base64.b64encode(image_bytes).decode("ascii"),
            "hint": hint,
        }).encode("utf-8")
        request = urllib.request.Request(
            self.endpoint,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}",
                "User-Agent": "Miqdar-252/1.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            body = json.load(response)
        candidates = body.get("candidates") or []
        return [Candidate(str(item["label"]), float(item["confidence"])) for item in candidates]


class GeminiRecognitionProvider:
    """Gemini multimodal classification with token-optimized image preparation,
    multi-model fallback, caching, and constrained structured JSON response.

    Gemini supplies candidate food labels only. Nutrition always comes from the
    reviewed Miqdar database after the selected label is mapped to a food ID.
    """

    name = "gemini"
    canonical_labels = (
        "medjool dates", "ajwa dates", "sukari dates", "white rice", "chicken breast",
        "hummus", "banana", "apple", "cucumber", "tomato", "boiled egg",
        "almonds", "whole milk", "cooked salmon", "chicken kabsa", "lamb kabsa",
        "chicken mandi", "lamb mandi", "bukhari rice", "jareesh", "margoog",
        "qursan", "saleeg", "lamb haneeth", "southern areeka", "masoub",
        "mutabbaq", "sayadieh fish rice", "chicken shawarma wrap",
        "beef shawarma wrap", "falafel wrap", "crispy chicken burger",
        "beef burger", "pizza pepperoni", "pizza margherita", "greek yogurt",
        "tuna salad", "green garden salad",
    )

    def __init__(
        self,
        api_key: str,
        model: str = "gemini-3.1-flash-lite",
        api_base: str = "https://generativelanguage.googleapis.com",
        fallback_models: tuple[str, ...] | None = None,
    ) -> None:
        self.api_key = api_key
        self.model = model
        self.api_base = api_base.rstrip("/")
        self.fallback_models = fallback_models or ()
        # Populated after each recognize() call so the API can report what happened.
        self.last_cache_hit = False
        self.last_model_used: str | None = None

    @property
    def endpoint(self) -> str:
        return f"{self.api_base}/v1beta/models/{self.model}:generateContent"

    def _endpoint_for_model(self, model_name: str) -> str:
        return f"{self.api_base}/v1beta/models/{model_name}:generateContent"

    @staticmethod
    def _prepare_image(image_bytes: bytes, max_side: int = 384) -> tuple[bytes, str]:
        if not image_bytes:
            raise ValueError("Gemini recognition requires image_base64")
        try:
            with Image.open(io.BytesIO(image_bytes)) as img:
                img = ImageOps.exif_transpose(img)
                if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                    rgba = img.convert("RGBA")
                    background = Image.new("RGB", rgba.size, (255, 255, 255))
                    background.paste(rgba, mask=rgba.split()[-1])
                    img = background
                elif img.mode != "RGB":
                    img = img.convert("RGB")
                img.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
                buf = io.BytesIO()
                img.save(buf, format="JPEG", quality=85)
                return buf.getvalue(), "image/jpeg"
        except Exception as exc:
            raise ValueError("image_base64 must contain a supported image") from exc

    def recognize(self, image_bytes: bytes, hint: str | None = None) -> list[Candidate]:
        if not image_bytes:
            raise ValueError("Gemini recognition requires image_base64")

        # SHA-256 LRU cache: an identical photo + hint + model is answered instantly.
        cache_key = hashlib.sha256(
            image_bytes + b"\x00" + (hint or "").encode("utf-8") + b"\x00" + self.model.encode("utf-8")
        ).hexdigest()
        cached = RECOGNITION_CACHE.get(cache_key)
        if cached is not None:
            self.last_cache_hit = True
            self.last_model_used = cached[1]
            return list(cached[0])
        self.last_cache_hit = False

        prepared_bytes, mime_type = self._prepare_image(image_bytes)

        labels = "; ".join(self.canonical_labels)
        hint_text = (
            f" The user typed this optional hint: {hint!r}. Treat it as weak context only; "
            "the photo always wins." if hint else ""
        )
        prompt = (
            "You are the food-recognition step of the Miqdar smart kitchen scale used in "
            "Saudi Arabia. Identify the primary food or dish in the photo and return up to "
            "three ranked candidates with confidence scores between 0 and 1 (the scores "
            "should reflect real uncertainty). When a candidate matches one of these "
            f"database labels, copy the label exactly: {labels}. If none match, use a short "
            "common English dish name. If the photo does not show food or drink, return a "
            f"single candidate labelled 'not food'.{hint_text} Do not estimate nutrients, "
            "health effects, portion mass, or ingredients."
        )
        payload = {
            "contents": [{
                "parts": [
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": base64.b64encode(prepared_bytes).decode("ascii"),
                        }
                    },
                    {"text": prompt},
                ]
            }],
            "generationConfig": {
                "temperature": 0.1,
                "responseMimeType": "application/json",
                "responseJsonSchema": {
                    "type": "object",
                    "properties": {
                        "candidates": {
                            "type": "array",
                            "maxItems": 3,
                            "items": {
                                "type": "object",
                                "properties": {
                                    "label": {"type": "string"},
                                    "confidence": {
                                        "type": "number", "minimum": 0, "maximum": 1
                                    },
                                },
                                "required": ["label", "confidence"],
                            },
                        }
                    },
                    "required": ["candidates"],
                },
            },
        }

        models_to_try = [self.model] + [m for m in self.fallback_models if m != self.model]
        last_error = None

        for model_name in models_to_try:
            url = self._endpoint_for_model(model_name)
            request = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "x-goog-api-key": self.api_key,
                    "User-Agent": "Miqdar/2.0",
                },
                method="POST",
            )
            try:
                with urllib.request.urlopen(request, timeout=25) as response:
                    body = json.load(response)

                parts = body["candidates"][0]["content"]["parts"]
                text = "".join(str(part.get("text", "")) for part in parts)
                decoded = json.loads(text)
                raw_candidates = decoded["candidates"]

                candidates = []
                for item in raw_candidates[:3]:
                    label = str(item.get("label", "")).casefold().strip()
                    confidence = max(0.0, min(1.0, float(item.get("confidence", 0))))
                    if label:
                        candidates.append(Candidate(label, confidence))

                if candidates:
                    RECOGNITION_CACHE.put(cache_key, candidates, model_name)
                    self.last_model_used = model_name
                    return candidates
            except urllib.error.HTTPError as exc:
                details = exc.read().decode("utf-8", errors="replace")[:500]
                last_error = RuntimeError(f"Gemini API returned HTTP {exc.code}: {details}")
                if exc.code in (404, 429, 500, 502, 503, 504) and model_name != models_to_try[-1]:
                    continue
                raise last_error from exc
            except urllib.error.URLError as exc:
                last_error = RuntimeError(f"Gemini API connection failed: {exc.reason}")
                if model_name != models_to_try[-1]:
                    continue
                raise last_error from exc
            except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
                last_error = RuntimeError("Gemini returned an invalid recognition response")
                if model_name != models_to_try[-1]:
                    continue
                raise last_error from exc

        if last_error:
            raise last_error
        return []


DEFAULT_GEMINI_MODEL = "gemini-3.1-flash-lite-preview"
DEFAULT_FALLBACKS = ("gemini-3-flash-preview", "gemini-2.5-flash-image", "gemini-flash-latest")


def _load_env_if_needed() -> None:
    try:
        from pathlib import Path
        for candidate in [
            Path(".env"),
            Path("backend/.env"),
            Path(__file__).resolve().parent.parent.parent / ".env",
            Path.home() / ".miqdar_env",
        ]:
            if candidate.is_file():
                with candidate.open(encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except Exception:
        pass


def configured_provider() -> RecognitionProvider:
    _load_env_if_needed()
    provider_name = os.environ.get("MIQDAR_RECOGNITION_PROVIDER", "").casefold().strip()
    if provider_name == "mock":
        return MockRecognitionProvider()
    gemini_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if provider_name == "gemini" or (not provider_name and gemini_key):
        if not gemini_key:
            raise RuntimeError(
                "MIQDAR_RECOGNITION_PROVIDER is set to 'gemini' but GEMINI_API_KEY is missing or empty. "
                "Please configure GEMINI_API_KEY in your .env file."
            )
        raw_fallbacks = os.environ.get("GEMINI_FALLBACK_MODELS", ",".join(DEFAULT_FALLBACKS))
        fallbacks = tuple(m.strip() for m in raw_fallbacks.split(",") if m.strip())
        return GeminiRecognitionProvider(
            api_key=gemini_key,
            model=os.environ.get("GEMINI_MODEL", DEFAULT_GEMINI_MODEL).strip(),
            api_base=os.environ.get(
                "GEMINI_API_BASE", "https://generativelanguage.googleapis.com"
            ).strip(),
            fallback_models=fallbacks,
        )
    endpoint = os.environ.get("MIQDAR_CLOUD_ENDPOINT", "").strip()
    api_key = os.environ.get("MIQDAR_CLOUD_API_KEY", "").strip()
    if provider_name == "remote" or (not provider_name and endpoint and api_key):
        if not endpoint or not api_key:
            raise RuntimeError(
                "MIQDAR_RECOGNITION_PROVIDER=remote requires MIQDAR_CLOUD_ENDPOINT "
                "and MIQDAR_CLOUD_API_KEY"
            )
        return RemoteCloudRecognitionProvider(endpoint, api_key)
    if provider_name:
        raise RuntimeError(
            "MIQDAR_RECOGNITION_PROVIDER must be gemini, remote, or mock"
        )
    return MockRecognitionProvider()


def image_sha256(image_bytes: bytes) -> str:
    return hashlib.sha256(image_bytes or b"miqdar-empty-frame").hexdigest()


def average_hash(image_bytes: bytes) -> int | None:
    if not image_bytes:
        return None
    try:
        with Image.open(io.BytesIO(image_bytes)) as image:
            pixels = list(image.convert("L").resize((8, 8)).getdata())
    except Exception:
        return None
    mean = sum(pixels) / len(pixels)
    value = 0
    for pixel in pixels:
        value = (value << 1) | int(pixel >= mean)
    return value


def mean_rgb(image_bytes: bytes) -> tuple[float, float, float] | None:
    if not image_bytes:
        return None
    try:
        with Image.open(io.BytesIO(image_bytes)) as image:
            means = ImageStat.Stat(image.convert("RGB").resize((32, 32))).mean
    except Exception:
        return None
    return float(means[0]), float(means[1]), float(means[2])


def frame_similarity(current_bytes: bytes, previous_bytes: bytes | None) -> float | None:
    current_hash = average_hash(current_bytes)
    previous_hash = average_hash(previous_bytes or b"")
    if current_hash is None or previous_hash is None:
        return None
    distance = (current_hash ^ previous_hash).bit_count()
    structure_similarity = 1.0 - (distance / 64.0)
    current_rgb = mean_rgb(current_bytes)
    previous_rgb = mean_rgb(previous_bytes or b"")
    if current_rgb is None or previous_rgb is None:
        return round(structure_similarity, 4)
    color_distance = math.sqrt(sum((a - b) ** 2 for a, b in zip(current_rgb, previous_rgb)))
    color_similarity = 1.0 - min(1.0, color_distance / (math.sqrt(3) * 255.0))
    return round(min(structure_similarity, color_similarity), 4)


def detect_new_food(
    *, current_bytes: bytes, previous_bytes: bytes | None,
    current_weight_g: float, previous_weight_g: float | None,
) -> tuple[bool, float | None, float]:
    weight_delta = current_weight_g - (previous_weight_g or 0.0)
    similarity = frame_similarity(current_bytes, previous_bytes)
    if previous_weight_g is None or not previous_bytes:
        return True, similarity, round(weight_delta, 2)
    image_changed = similarity is None or similarity < 0.985
    return bool(weight_delta >= 5.0 and image_changed), similarity, round(weight_delta, 2)
