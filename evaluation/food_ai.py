"""
food_ai.py - Shared Gemini food-recognition & nutrition core.

Used by:
  - server.py            HTTP API for the Raspberry Pi scale and the mobile app
  - test_food.py         single-image CLI test
  - compare_models.py    side-by-side model comparison
  - evaluate_dataset.py  accuracy evaluation over the dataset

The schema, prompt, image preprocessing, retries and validation all live here,
so what you evaluate is exactly what production runs.
"""
from __future__ import annotations

import hashlib
import io
import logging
import os
import random
import threading
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple, Union

import httpx
from dotenv import load_dotenv
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field, ValidationError

load_dotenv()

from google import genai  # noqa: E402
from google.genai import errors as genai_errors  # noqa: E402
from google.genai import types  # noqa: E402

log = logging.getLogger("food_ai")
logging.getLogger("google").setLevel(logging.ERROR)
logging.getLogger("google.genai").setLevel(logging.ERROR)
logging.getLogger("httpx").setLevel(logging.WARNING)


# --------------------------------------------------------------------------- #
# Configuration (all overridable from .env)
# --------------------------------------------------------------------------- #
def _env_float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except ValueError:
        return default


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    api_key: Optional[str]
    model: str
    fallback_models: Tuple[str, ...]
    timeout_s: float          # per Gemini HTTP request
    total_deadline_s: float   # whole analyze() call, including retries/fallbacks
    attempts_per_model: int
    image_max_side: int       # <=384 px on both sides = smallest fixed image token cost
    max_image_bytes: int
    cache_size: int
    cache_ttl_s: float

    @classmethod
    def from_env(cls) -> "Settings":
        fallbacks = os.getenv("GEMINI_FALLBACK_MODELS", "gemini-3.5-flash-lite")
        return cls(
            api_key=os.getenv("GEMINI_API_KEY") or None,
            model=os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite").strip(),
            fallback_models=tuple(m.strip() for m in fallbacks.split(",") if m.strip()),
            timeout_s=_env_float("GEMINI_TIMEOUT_S", 20.0),
            total_deadline_s=_env_float("GEMINI_TOTAL_DEADLINE_S", 35.0),
            attempts_per_model=max(1, _env_int("GEMINI_ATTEMPTS_PER_MODEL", 2)),
            image_max_side=_env_int("IMAGE_MAX_SIDE", 384),
            max_image_bytes=_env_int("MAX_IMAGE_BYTES", 8 * 1024 * 1024),
            cache_size=_env_int("CACHE_SIZE", 256),
            cache_ttl_s=_env_float("CACHE_TTL_S", 24 * 3600),
        )


SETTINGS = Settings.from_env()

# Models a client is allowed to request explicitly (prevents arbitrary model strings).
KNOWN_MODELS = frozenset({
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.8-flash",
})


def allowed_models(settings: Settings = SETTINGS) -> frozenset:
    return KNOWN_MODELS | {settings.model} | set(settings.fallback_models)


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class FoodAIError(Exception):
    """A classified, user-presentable error.

    code         stable machine-readable code for the app (e.g. NOT_FOOD, RATE_LIMITED)
    http_status  status the HTTP API should return
    retryable    worth retrying the same model
    fallback     worth trying the next model in the chain
    """

    def __init__(self, code: str, message: str, http_status: int = 500,
                 retryable: bool = False, fallback: bool = False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.http_status = http_status
        self.retryable = retryable
        self.fallback = fallback

    def to_dict(self) -> Dict[str, Any]:
        return {"error_code": self.code, "error": self.message}


# --------------------------------------------------------------------------- #
# Structured-output schema (what Gemini must return)
# --------------------------------------------------------------------------- #
class Alternative(BaseModel):
    name_en: str
    name_ar: str


class FoodAnalysis(BaseModel):
    is_food: bool = Field(description="False if the image does not show food or a drink.")
    best_match_en: str = Field(description="Most likely dish, common English name.")
    best_match_ar: str = Field(description="Most likely dish, Arabic name a Saudi user would use.")
    preparation: str = Field(description="Cooking method in 1-3 words, e.g. 'grilled', 'deep fried', 'baked'.")
    visible_ingredients: List[str] = Field(description="Only ingredients that are clearly visible.")
    confidence: int = Field(ge=0, le=100, description="Confidence (0-100) that best_match is correct.")
    requires_user_confirmation: bool = Field(
        description="True if confidence < 70, the dish is ambiguous, or the plate mixes several dishes.")
    alternatives: List[Alternative] = Field(description="Up to 2 other plausible dishes, most likely first.")
    nutrition_basis: str = Field(
        description="Standard reference food the per-100g values come from, "
                    "e.g. 'USDA FDC: Cheeseburger, double patty, with condiments'.")
    calories_per_100g: float = Field(ge=0, le=900, description="kcal per 100 g of the dish as served.")
    protein_per_100g: float = Field(ge=0, le=100, description="Protein (g) per 100 g as served.")
    carbs_per_100g: float = Field(ge=0, le=100, description="Total carbohydrates (g) per 100 g as served.")
    fat_per_100g: float = Field(ge=0, le=100, description="Total fat (g) per 100 g as served.")


def build_prompt(weight_grams: float) -> str:
    return f"""You are the food-recognition component of a smart kitchen scale used in Saudi Arabia.
The scale measured {weight_grams:g} g. This weight is authoritative: do not estimate portion size from the image.

1. Decide whether the image shows food or a drink. If it does not, set is_food=false, confidence=0,
   and every nutrient value to 0.
2. Identify the single most likely dish (English and Arabic). Consider Saudi and Gulf dishes
   (kabsa, mandi, bukhari, jareesh, areeka, shawarma, etc.), but do not force a Saudi label when
   another dish is more likely.
3. Give the preparation method in 1-3 words.
4. List only ingredients that are clearly visible. Do not invent hidden ingredients.
5. Give nutrient density per 100 g of the dish as served (cooked, including visible sauces), using
   standard reference values (USDA FoodData Central, or Saudi/Gulf food composition tables for local
   dishes). Choose the closest standard reference item and name it in nutrition_basis.
   Values must be internally consistent: calories ~= 4*protein + 4*carbs + 9*fat.
   Report realistic values; never adjust them to look healthier or less healthy.
6. Set confidence from 0 to 100. Set requires_user_confirmation=true if confidence < 70 or the dish is
   ambiguous or mixed. Give up to 2 alternatives.
"""


# --------------------------------------------------------------------------- #
# Image preprocessing
# --------------------------------------------------------------------------- #
@dataclass
class PreparedImage:
    image: Image.Image
    sha256: str
    original_size: Tuple[int, int]


ImageSource = Union[bytes, bytearray, str, "os.PathLike[str]"]


def prepare_image(source: ImageSource, settings: Settings = SETTINGS) -> PreparedImage:
    """Load, validate, fix orientation, flatten transparency and downscale an image."""
    if isinstance(source, (bytes, bytearray)):
        raw = bytes(source)
    else:
        try:
            with open(source, "rb") as fh:
                raw = fh.read()
        except FileNotFoundError:
            raise FoodAIError("IMAGE_NOT_FOUND", f"Image not found: {source}", 404)
        except OSError as exc:  # e.g. iCloud placeholder that cannot be downloaded
            raise FoodAIError("IMAGE_UNREADABLE", f"Could not read image: {exc}", 400)

    if not raw:
        raise FoodAIError("INVALID_IMAGE", "Image is empty.", 400)
    if len(raw) > settings.max_image_bytes:
        raise FoodAIError("IMAGE_TOO_LARGE",
                          f"Image is {len(raw) / 1e6:.1f} MB; limit is "
                          f"{settings.max_image_bytes / 1e6:.0f} MB.", 413)
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
    except Image.DecompressionBombError:
        raise FoodAIError("IMAGE_TOO_LARGE", "Image resolution is too large.", 413)
    except (UnidentifiedImageError, OSError):
        raise FoodAIError("INVALID_IMAGE", "File is not a readable image.", 400)

    original_size = img.size
    img = ImageOps.exif_transpose(img)  # phone/camera photos are often stored rotated

    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        background = Image.new("RGB", rgba.size, (255, 255, 255))
        background.paste(rgba, mask=rgba.split()[-1])
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    side = settings.image_max_side
    img.thumbnail((side, side), Image.Resampling.LANCZOS)
    return PreparedImage(image=img, sha256=hashlib.sha256(raw).hexdigest(), original_size=original_size)


# --------------------------------------------------------------------------- #
# Validation & nutrition math
# --------------------------------------------------------------------------- #
def validate_analysis(analysis: FoodAnalysis) -> Tuple[FoodAnalysis, List[str]]:
    """Reject impossible output; flag suspicious output instead of silently changing it."""
    if not analysis.is_food:
        raise FoodAIError("NOT_FOOD", "No food detected in the image.", 422)

    warnings: List[str] = []
    p, c, f = analysis.protein_per_100g, analysis.carbs_per_100g, analysis.fat_per_100g
    kcal = analysis.calories_per_100g
    macro_sum = p + c + f

    if macro_sum > 105:
        raise FoodAIError("INVALID_MODEL_OUTPUT",
                          f"Impossible nutrient values (protein+carbs+fat = {macro_sum:.0f} g per 100 g).",
                          502, fallback=True)
    if kcal <= 0 and macro_sum > 1:
        raise FoodAIError("INVALID_MODEL_OUTPUT", "Calories are 0 but macronutrients are not.",
                          502, fallback=True)

    atwater = 4 * p + 4 * c + 9 * f
    if kcal > 0 and abs(atwater - kcal) > max(25.0, 0.20 * max(kcal, atwater)):
        warnings.append(
            f"Calories ({kcal:.0f} kcal/100g) do not match macronutrients "
            f"(4P+4C+9F = {atwater:.0f} kcal/100g); please confirm.")

    needs_confirmation = analysis.requires_user_confirmation or analysis.confidence < 70 or bool(warnings)
    if needs_confirmation != analysis.requires_user_confirmation:
        analysis = analysis.model_copy(update={"requires_user_confirmation": needs_confirmation})
    return analysis, warnings


def per_100g(analysis: FoodAnalysis) -> Dict[str, float]:
    return {
        "calories": round(analysis.calories_per_100g),
        "protein": round(analysis.protein_per_100g, 1),
        "carbs": round(analysis.carbs_per_100g, 1),
        "fat": round(analysis.fat_per_100g, 1),
    }


def portion_nutrition(analysis: FoodAnalysis, weight_grams: float) -> Dict[str, Any]:
    factor = weight_grams / 100.0
    return {
        "calories": round(analysis.calories_per_100g * factor),
        "protein": round(analysis.protein_per_100g * factor, 1),
        "carbs": round(analysis.carbs_per_100g * factor, 1),
        "fat": round(analysis.fat_per_100g * factor, 1),
        "per_100g": per_100g(analysis),
    }


def validate_weight(weight_grams: Any) -> float:
    try:
        w = float(weight_grams)
    except (TypeError, ValueError):
        raise FoodAIError("INVALID_WEIGHT", "weight_grams must be a number.", 400)
    if not (0 < w <= 10000):
        raise FoodAIError("INVALID_WEIGHT", "weight_grams must be between 0 and 10000.", 400)
    return w


# --------------------------------------------------------------------------- #
# Result
# --------------------------------------------------------------------------- #
@dataclass
class FoodResult:
    analysis: FoodAnalysis
    model: str
    latency_s: float
    weight_grams: float
    cached: bool = False
    warnings: List[str] = field(default_factory=list)
    attempts: List[Dict[str, Any]] = field(default_factory=list)

    @property
    def nutrition(self) -> Dict[str, Any]:
        return portion_nutrition(self.analysis, self.weight_grams)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "model": self.model,
            "latency_seconds": round(self.latency_s, 2),
            "cached": self.cached,
            "weight_grams": self.weight_grams,
            "recognition": self.analysis.model_dump(),
            "nutrition": self.nutrition,
            "warnings": self.warnings,
            "attempts": self.attempts,
        }


# --------------------------------------------------------------------------- #
# Thread-safe LRU cache with TTL (keyed by image bytes hash + model)
# --------------------------------------------------------------------------- #
class _LRUCache:
    def __init__(self, max_items: int, ttl_s: float):
        self._data: "OrderedDict[Tuple[str, str], Tuple[float, Any]]" = OrderedDict()
        self._lock = threading.Lock()
        self._max = max(0, max_items)
        self._ttl = ttl_s

    def get(self, key):
        with self._lock:
            item = self._data.get(key)
            if item is None:
                return None
            stored_at, value = item
            if time.monotonic() - stored_at > self._ttl:
                del self._data[key]
                return None
            self._data.move_to_end(key)
            return value

    def set(self, key, value) -> None:
        if self._max == 0:
            return
        with self._lock:
            self._data[key] = (time.monotonic(), value)
            self._data.move_to_end(key)
            while len(self._data) > self._max:
                self._data.popitem(last=False)

    def clear(self) -> int:
        with self._lock:
            n = len(self._data)
            self._data.clear()
            return n

    def __len__(self) -> int:
        with self._lock:
            return len(self._data)


# --------------------------------------------------------------------------- #
# Analyzer
# --------------------------------------------------------------------------- #
def _classify(exc: Exception) -> FoodAIError:
    """Map SDK / network exceptions to FoodAIError with retry/fallback policy."""
    if isinstance(exc, FoodAIError):
        return exc
    if isinstance(exc, genai_errors.ClientError):
        code = getattr(exc, "code", 400)
        msg = getattr(exc, "message", None) or str(exc)
        if code == 429:
            return FoodAIError("RATE_LIMITED", "Gemini quota or rate limit reached.", 429,
                               retryable=True, fallback=True)
        if code in (401, 403):
            return FoodAIError("AUTH_ERROR", "Gemini rejected the API key (check GEMINI_API_KEY).", 500)
        if code == 404:
            return FoodAIError("MODEL_NOT_FOUND", f"Model not available: {msg}", 502, fallback=True)
        return FoodAIError("UPSTREAM_BAD_REQUEST", f"Gemini rejected the request: {msg}", 502, fallback=True)
    if isinstance(exc, genai_errors.ServerError):
        return FoodAIError("UPSTREAM_UNAVAILABLE", "Gemini is temporarily unavailable.", 503,
                           retryable=True, fallback=True)
    if isinstance(exc, httpx.TimeoutException):
        return FoodAIError("UPSTREAM_TIMEOUT", "Gemini did not respond in time.", 504, fallback=True)
    if isinstance(exc, httpx.TransportError):
        return FoodAIError("NETWORK_ERROR", f"Network error reaching Gemini: {exc}", 503,
                           retryable=True, fallback=True)
    return FoodAIError("INTERNAL_ERROR", f"Unexpected error: {exc}", 500)


class FoodAnalyzer:
    def __init__(self, settings: Settings = SETTINGS):
        if not settings.api_key:
            raise FoodAIError("CONFIG_ERROR", "GEMINI_API_KEY is not set (add it to .env).", 500)
        self.settings = settings
        # SDK-level retries are disabled; retry/fallback policy is handled below with a hard deadline.
        self.client = genai.Client(
            api_key=settings.api_key,
            http_options=types.HttpOptions(
                timeout=int(settings.timeout_s * 1000),
                retry_options=types.HttpRetryOptions(attempts=1),
            ),
        )
        self.cache = _LRUCache(settings.cache_size, settings.cache_ttl_s)

    def model_chain(self, model: Optional[str], allow_fallback: bool = True) -> List[str]:
        primary = model or self.settings.model
        chain = [primary] + (list(self.settings.fallback_models) if allow_fallback else [])
        return list(dict.fromkeys(m for m in chain if m))

    def _call(self, model: str, image: Image.Image, weight_grams: float, timeout_s: float) -> FoodAnalysis:
        response = self.client.models.generate_content(
            model=model,
            contents=[image, build_prompt(weight_grams)],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=FoodAnalysis,
                temperature=0,
                automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
                http_options=types.HttpOptions(timeout=int(timeout_s * 1000)),
            ),
        )
        if isinstance(response.parsed, FoodAnalysis):
            return response.parsed
        text = response.text
        if not text:
            raise FoodAIError("EMPTY_RESPONSE", "Gemini returned an empty response (possibly blocked).",
                              502, fallback=True)
        try:
            return FoodAnalysis.model_validate_json(text)
        except ValidationError as exc:
            raise FoodAIError("INVALID_MODEL_OUTPUT", f"Gemini output did not match the schema: {exc.errors()[:2]}",
                              502, fallback=True)

    def analyze(self, source: ImageSource, weight_grams: Any, model: Optional[str] = None,
                use_cache: bool = True, allow_fallback: bool = True) -> FoodResult:
        weight = validate_weight(weight_grams)
        prepared = prepare_image(source, self.settings)
        chain = self.model_chain(model, allow_fallback)

        t0 = time.perf_counter()
        cache_key = (prepared.sha256, chain[0])
        if use_cache:
            hit = self.cache.get(cache_key)
            if hit is not None:
                analysis, used_model, warnings = hit
                return FoodResult(analysis, used_model, time.perf_counter() - t0, weight,
                                  cached=True, warnings=list(warnings))

        deadline = t0 + self.settings.total_deadline_s
        attempts: List[Dict[str, Any]] = []
        last_error: Optional[FoodAIError] = None

        for model_name in chain:
            for attempt in range(1, self.settings.attempts_per_model + 1):
                remaining = deadline - time.perf_counter()
                if remaining < 2.0:
                    break
                call_start = time.perf_counter()
                try:
                    analysis = self._call(model_name, prepared.image, weight,
                                          min(self.settings.timeout_s, remaining))
                    analysis, warnings = validate_analysis(analysis)
                except Exception as exc:  # noqa: BLE001 - classified below
                    err = _classify(exc)
                    last_error = err
                    attempts.append({"model": model_name, "attempt": attempt, "error_code": err.code,
                                     "seconds": round(time.perf_counter() - call_start, 2)})
                    log.warning("Gemini %s attempt %d failed: %s %s", model_name, attempt, err.code, err.message)
                    if err.code in ("NOT_FOOD", "AUTH_ERROR", "INTERNAL_ERROR", "CONFIG_ERROR"):
                        raise err
                    if err.retryable and attempt < self.settings.attempts_per_model:
                        backoff = min(0.8 * (2 ** (attempt - 1)) + random.uniform(0, 0.3),
                                      max(0.0, deadline - time.perf_counter() - 2.0))
                        time.sleep(backoff)
                        continue
                    break  # go to next model (or stop if no fallback is sensible)
                attempts.append({"model": model_name, "attempt": attempt, "error_code": None,
                                 "seconds": round(time.perf_counter() - call_start, 2)})
                self.cache.set(cache_key, (analysis, model_name, tuple(warnings)))
                return FoodResult(analysis, model_name, time.perf_counter() - t0, weight,
                                  warnings=warnings, attempts=attempts)
            if last_error is not None and not last_error.fallback:
                break
            if deadline - time.perf_counter() < 2.0:
                break

        if last_error is None:
            last_error = FoodAIError("UPSTREAM_TIMEOUT", "No time left to call Gemini.", 504)
        raise last_error


_default: Optional[FoodAnalyzer] = None
_default_lock = threading.Lock()


def get_analyzer() -> FoodAnalyzer:
    """Process-wide analyzer (one HTTP client, one cache)."""
    global _default
    with _default_lock:
        if _default is None:
            _default = FoodAnalyzer()
        return _default


def analyze_food(source: ImageSource, weight_grams: Any, model: Optional[str] = None, **kwargs) -> FoodResult:
    return get_analyzer().analyze(source, weight_grams, model=model, **kwargs)
