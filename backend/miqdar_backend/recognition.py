from __future__ import annotations

import base64
import hashlib
import io
import json
import math
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Protocol

from PIL import Image, ImageStat


@dataclass(frozen=True)
class Candidate:
    label: str
    confidence: float


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
    """Gemini multimodal classification with a constrained JSON response.

    Gemini supplies candidate food labels only. Nutrition always comes from the
    reviewed Miqdar database after the selected label is mapped to a food ID.
    """

    name = "gemini"
    canonical_labels = (
        "medjool dates", "ajwa dates", "white rice", "chicken breast",
        "hummus", "banana", "apple", "cucumber", "tomato", "boiled egg",
        "almonds", "whole milk", "cooked salmon",
    )

    def __init__(self, api_key: str, model: str, api_base: str) -> None:
        self.api_key = api_key
        self.model = model
        self.endpoint = (
            f"{api_base.rstrip('/')}/v1beta/models/{model}:generateContent"
        )

    @staticmethod
    def _mime_type(image_bytes: bytes) -> str:
        try:
            with Image.open(io.BytesIO(image_bytes)) as image:
                image_format = (image.format or "JPEG").upper()
        except Exception as exc:
            raise ValueError("image_base64 must contain a supported image") from exc
        return {
            "PNG": "image/png",
            "WEBP": "image/webp",
            "HEIC": "image/heic",
            "HEIF": "image/heif",
        }.get(image_format, "image/jpeg")

    def recognize(self, image_bytes: bytes, hint: str | None = None) -> list[Candidate]:
        if not image_bytes:
            raise ValueError("Gemini recognition requires image_base64")
        labels = ", ".join(self.canonical_labels)
        hint_text = f" The user supplied this optional hint: {hint}." if hint else ""
        prompt = (
            "Classify the primary food visible on the Miqdar scale. Return at most "
            "three ranked candidates. Prefer these database labels when visually "
            f"appropriate: {labels}.{hint_text} The hint is not authoritative. Do not "
            "estimate nutrients, health effects, portion mass, or ingredients."
        )
        payload = {
            "contents": [{
                "parts": [
                    {
                        "inline_data": {
                            "mime_type": self._mime_type(image_bytes),
                            "data": base64.b64encode(image_bytes).decode("ascii"),
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
        request = urllib.request.Request(
            self.endpoint,
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
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")[:500]
            raise RuntimeError(f"Gemini API returned HTTP {exc.code}: {details}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"Gemini API connection failed: {exc.reason}") from exc

        try:
            parts = body["candidates"][0]["content"]["parts"]
            text = "".join(str(part.get("text", "")) for part in parts)
            decoded = json.loads(text)
            raw_candidates = decoded["candidates"]
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            raise RuntimeError("Gemini returned an invalid recognition response") from exc

        candidates = []
        for item in raw_candidates[:3]:
            label = str(item.get("label", "")).casefold().strip()
            confidence = max(0.0, min(1.0, float(item.get("confidence", 0))))
            if label:
                candidates.append(Candidate(label, confidence))
        return candidates


def configured_provider() -> RecognitionProvider:
    provider_name = os.environ.get("MIQDAR_RECOGNITION_PROVIDER", "").casefold().strip()
    if provider_name == "mock":
        return MockRecognitionProvider()
    gemini_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if provider_name == "gemini" or (not provider_name and gemini_key):
        if not gemini_key:
            raise RuntimeError(
                "MIQDAR_RECOGNITION_PROVIDER=gemini requires GEMINI_API_KEY"
            )
        return GeminiRecognitionProvider(
            api_key=gemini_key,
            model=os.environ.get("GEMINI_MODEL", "gemini-3.1-flash-lite").strip(),
            api_base=os.environ.get(
                "GEMINI_API_BASE", "https://generativelanguage.googleapis.com"
            ).strip(),
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
            pixels = list(image.convert("L").resize((8, 8)).get_flattened_data())
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
