from __future__ import annotations

import argparse
import hmac
import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from .alert_engine import evaluate_alerts
from .database import (
    alerts, connect, find_food_for_label, food_search, goals_for_user,
    health_profile_for_user, history, save_meal, scaled_nutrients,
    update_goals, update_health_profile,
)
from .recognition import configured_provider
from .recommendations import normalise_profile, recommend_meals
from .service import RecognitionError, decode_image, recognize_food


DEFAULT_DB = Path(__file__).resolve().parents[2] / "database" / "miqdar_nutrition.db"
DEMO_USER = "demo-user"


class MiqdarHandler(BaseHTTPRequestHandler):
    server_version = "Miqdar/1.0"

    @property
    def db_path(self) -> Path:
        return self.server.db_path  # type: ignore[attr-defined]

    def log_message(self, format: str, *args: object) -> None:
        if os.environ.get("MIQDAR_QUIET") != "1":
            super().log_message(format, *args)

    def send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS, HEAD")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def authorized(self) -> bool:
        expected = os.environ.get("MIQDAR_API_TOKEN", "").strip()
        if not expected:
            return True
        supplied = self.headers.get("Authorization", "")
        return hmac.compare_digest(supplied, f"Bearer {expected}")

    def require_authorization(self) -> bool:
        if self.authorized():
            return True
        self.send_json(401, {"error": "unauthorized"})
        return False

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length > 15 * 1024 * 1024:
            raise ValueError("Request body exceeds the 15 MB API limit")
        payload = self.rfile.read(length) if length else b"{}"
        value = json.loads(payload)
        if not isinstance(value, dict):
            raise ValueError("JSON object required")
        return value

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS, HEAD")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_HEAD(self) -> None:
        self.do_GET()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        api_endpoints = {"/health", "/foods", "/history", "/goals", "/health-profile", "/alerts"}
        if parsed.path not in api_endpoints:
            web_dir = Path(__file__).resolve().parents[2] / "mobile" / "build" / "web"
            if web_dir.is_dir():
                clean_path = parsed.path.lstrip("/")
                target_file = (web_dir / clean_path) if clean_path else (web_dir / "index.html")
                if target_file.is_file() and not target_file.name.startswith("."):
                    mime, _ = mimetypes.guess_type(str(target_file))
                    mime = mime or "application/octet-stream"
                    if mime.startswith("text/") or mime in ("application/javascript", "application/json"):
                        mime += "; charset=utf-8"
                    content = target_file.read_bytes()
                    self.send_response(200)
                    self.send_header("Content-Type", mime)
                    self.send_header("Content-Length", str(len(content)))
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    if self.command != "HEAD":
                        self.wfile.write(content)
                    return
                elif not clean_path.startswith("api"):
                    target_file = web_dir / "index.html"
                    if target_file.is_file():
                        content = target_file.read_bytes()
                        self.send_response(200)
                        self.send_header("Content-Type", "text/html; charset=utf-8")
                        self.send_header("Content-Length", str(len(content)))
                        self.send_header("Access-Control-Allow-Origin", "*")
                        self.end_headers()
                        if self.command != "HEAD":
                            self.wfile.write(content)
                        return

        if parsed.path != "/health" and not self.require_authorization():
            return
        try:
            with connect(self.db_path) as connection:
                if parsed.path == "/health":
                    try:
                        provider = configured_provider()
                        provider_status = {
                            "provider": provider.name,
                            "model": getattr(provider, "model", None),
                            "configured": True,
                        }
                    except RuntimeError as exc:
                        provider_status = {
                            "provider": "configuration-error",
                            "configured": False,
                            "message": str(exc),
                        }
                    self.send_json(200, {
                        "status": "ok",
                        "database": str(self.db_path.name),
                        "recognition": provider_status,
                    })
                elif parsed.path == "/foods":
                    self.send_json(200, {"foods": food_search(connection, query.get("q", [""])[0])})
                elif parsed.path == "/history":
                    days = int(query.get("days", ["90"])[0])
                    user_id = query.get("user_id", [DEMO_USER])[0]
                    self.send_json(200, {"days": days, "items": history(connection, user_id, days)})
                elif parsed.path == "/goals":
                    user_id = query.get("user_id", [DEMO_USER])[0]
                    self.send_json(200, goals_for_user(connection, user_id))
                elif parsed.path == "/health-profile":
                    user_id = query.get("user_id", [DEMO_USER])[0]
                    self.send_json(200, health_profile_for_user(connection, user_id))
                elif parsed.path == "/alerts":
                    user_id = query.get("user_id", [DEMO_USER])[0]
                    self.send_json(200, {"alerts": alerts(connection, user_id)})
                else:
                    self.send_json(404, {"error": "route_not_found"})
        except Exception as exc:
            self.send_json(400, {"error": type(exc).__name__, "message": str(exc)})

    def do_PUT(self) -> None:
        parsed = urlparse(self.path)
        if not self.require_authorization():
            return
        try:
            payload = self.read_json()
            with connect(self.db_path) as connection:
                if parsed.path == "/goals":
                    user_id = str(payload.pop("user_id", DEMO_USER))
                    self.send_json(200, update_goals(connection, user_id, payload))
                elif parsed.path == "/health-profile":
                    user_id = str(payload.pop("user_id", DEMO_USER))
                    profile = normalise_profile(payload)
                    self.send_json(200, update_health_profile(connection, user_id, profile))
                else:
                    self.send_json(404, {"error": "route_not_found"})
        except Exception as exc:
            self.send_json(400, {"error": type(exc).__name__, "message": str(exc)})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if not self.require_authorization():
            return
        try:
            payload = self.read_json()
            with connect(self.db_path) as connection:
                if parsed.path == "/recognize":
                    result = recognize_food(
                        connection,
                        user_id=payload.get("user_id", DEMO_USER),
                        image_bytes=decode_image(payload.get("image_base64")),
                        weight_g=float(payload["weight_g"]),
                        hint=payload.get("hint"),
                        previous_image_bytes=decode_image(payload.get("previous_image_base64")) if payload.get("previous_image_base64") else None,
                        previous_weight_g=float(payload["previous_weight_g"]) if payload.get("previous_weight_g") is not None else None,
                    )
                    self.send_json(200, result)
                elif parsed.path == "/meals":
                    user_id = str(payload.get("user_id", DEMO_USER))
                    food = find_food_for_label(connection, payload["food_id"])
                    if not food:
                        row = connection.execute(
                            "SELECT f.*, n.* FROM foods f JOIN nutrient_profiles n ON n.food_id=f.food_id WHERE f.food_id=?",
                            (payload["food_id"],),
                        ).fetchone()
                        food = dict(row) if row else None
                    if not food:
                        raise KeyError("food_id does not have a nutrition profile")
                    weight_g = float(payload["weight_g"])
                    nutrients = scaled_nutrients(food, weight_g)
                    alerts_preview, _ = evaluate_alerts(connection, user_id=user_id, nutrients=nutrients)
                    meal_id = save_meal(
                        connection, user_id=user_id, food_id=food["food_id"],
                        weight_g=weight_g, confidence=float(payload.get("confidence", 1)),
                        nutrients=nutrients, meal_type=payload.get("meal_type", "Meal"),
                    )
                    persisted, alert_ms = evaluate_alerts(
                        connection, user_id=user_id, nutrients={}, persist=True, meal_id=meal_id,
                    )
                    self.send_json(201, {"meal_id": meal_id, "nutrients": nutrients, "alerts": alerts_preview or persisted, "alert_evaluation_ms": alert_ms})
                elif parsed.path == "/recommendations":
                    user_id = str(payload.get("user_id", DEMO_USER))
                    stored = health_profile_for_user(connection, user_id)
                    supplied_profile = payload.get("profile")
                    profile = normalise_profile(
                        supplied_profile if isinstance(supplied_profile, dict) else stored
                    )
                    result = recommend_meals(
                        connection,
                        user_id=user_id,
                        profile=profile,
                        limit=int(payload.get("limit", 5)),
                    )
                    self.send_json(200, result)
                else:
                    self.send_json(404, {"error": "route_not_found"})
        except RecognitionError as exc:
            self.send_json(exc.http_status, exc.to_dict())
        except KeyError as exc:
            self.send_json(400, {"error": "MISSING_FIELD", "message": f"Missing required field: {exc.args[0]}"})
        except Exception as exc:
            self.send_json(400, {"error": type(exc).__name__, "message": str(exc)})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), MiqdarHandler)
    server.db_path = args.db  # type: ignore[attr-defined]
    provider = configured_provider()
    provider_label = provider.name
    if getattr(provider, "model", None):
        provider_label += f" ({provider.model})"
    print(f"Miqdar API listening on {args.host}:{args.port}; recognition={provider_label}")
    server.serve_forever()


if __name__ == "__main__":
    main()
