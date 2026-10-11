from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from typing import Any

from .database import goals_for_user, scaled_nutrients, totals_for_day


SUPPORTED_CONDITIONS = {
    "diabetes",
    "hypertension",
    "high_cholesterol",
    "weight_management",
    "kidney_disease",
}
SUPPORTED_PREFERENCES = {"vegetarian", "vegan"}


def _normalise_list(value: object, *, limit: int = 20) -> list[str]:
    if not isinstance(value, list):
        return []
    result: list[str] = []
    for item in value[:limit]:
        text = str(item).casefold().strip()
        if text and text not in result:
            result.append(text)
    return result


def normalise_profile(value: dict[str, Any] | None) -> dict[str, list[str]]:
    source = value or {}
    conditions = [
        item for item in _normalise_list(source.get("conditions"))
        if item in SUPPORTED_CONDITIONS
    ]
    preferences = [
        item for item in _normalise_list(source.get("dietary_preferences"))
        if item in SUPPORTED_PREFERENCES
    ]
    return {
        "conditions": conditions,
        "dietary_preferences": preferences,
        "allergens": _normalise_list(source.get("allergens")),
        "disliked_foods": _normalise_list(source.get("disliked_foods")),
    }


def _portion_for(food: dict[str, Any]) -> float:
    name = food["canonical_name_en"].casefold()
    category = food["category"].casefold()
    if "almond" in name:
        return 30.0
    if category == "fruit":
        return 120.0
    if category == "dairy":
        return 200.0
    if category in {"vegetable", "legume"}:
        return 150.0
    return 140.0


def _exclusion_tokens(profile: dict[str, list[str]]) -> set[str]:
    tokens = set(profile["allergens"] + profile["disliked_foods"])
    expanded = set(tokens)
    aliases = {
        "nuts": {"nut", "almond"},
        "tree nuts": {"nut", "almond"},
        "dairy": {"milk", "dairy"},
        "fish": {"fish", "salmon"},
        "eggs": {"egg"},
    }
    for token in tokens:
        expanded.update(aliases.get(token, set()))
    return expanded


def _preference_excludes(food: dict[str, Any], preferences: set[str]) -> bool:
    name = food["canonical_name_en"].casefold()
    category = food["category"].casefold()
    animal = category == "protein" and any(
        token in name for token in ("chicken", "salmon", "egg", "beef", "lamb", "fish")
    )
    if "vegan" in preferences:
        return animal or category == "dairy" or "milk" in name
    if "vegetarian" in preferences:
        return animal and "egg" not in name
    return False


def recommend_meals(
    connection: sqlite3.Connection,
    *,
    user_id: str,
    profile: dict[str, Any] | None,
    limit: int = 5,
) -> dict[str, Any]:
    """Rank reviewed database foods using transparent, non-clinical rules."""

    profile = normalise_profile(profile)
    conditions = set(profile["conditions"])
    preferences = set(profile["dietary_preferences"])
    exclusions = _exclusion_tokens(profile)
    goals = goals_for_user(connection, user_id)
    today = datetime.now(timezone.utc).date().isoformat()
    totals = totals_for_day(connection, user_id, today)
    recent_rows = connection.execute(
        """
        SELECT mi.food_id, COUNT(*) AS occurrences
        FROM meals m JOIN meal_items mi ON mi.meal_id=m.meal_id
        WHERE m.user_id=? AND datetime(m.eaten_at) >= datetime('now', '-14 days')
        GROUP BY mi.food_id
        """,
        (user_id,),
    ).fetchall()
    recent_counts = {str(row["food_id"]): int(row["occurrences"]) for row in recent_rows}
    foods = connection.execute(
        """
        SELECT f.*, n.* FROM foods f
        JOIN nutrient_profiles n ON n.food_id=f.food_id
        WHERE f.active=1
        """
    ).fetchall()

    remaining_calories = max(0.0, float(goals["calories_kcal"]) - totals["calories_kcal"])
    target_meal_calories = min(650.0, max(180.0, remaining_calories * 0.35))
    ranked: list[dict[str, Any]] = []
    for row in foods:
        food = dict(row)
        haystack = " ".join(
            str(food.get(key) or "").casefold()
            for key in ("canonical_name_en", "canonical_name_ar", "category", "ingredients")
        )
        if exclusions and any(token in haystack for token in exclusions):
            continue
        if _preference_excludes(food, preferences):
            continue

        portion_g = _portion_for(food)
        nutrients = scaled_nutrients(food, portion_g)
        score = 55.0
        reasons: list[str] = []

        calorie_distance = abs(nutrients["calories_kcal"] - target_meal_calories)
        score += max(-12.0, 12.0 - calorie_distance / 22.0)
        protein_gap = max(0.0, float(goals["protein_g"]) - totals["protein_g"])
        if protein_gap > 15 and nutrients["protein_g"] >= 10:
            score += min(12.0, nutrients["protein_g"] / 2.5)
            reasons.append("adds protein toward today's remaining target")
        if nutrients["fiber_g"] >= 3:
            score += min(8.0, nutrients["fiber_g"])
            reasons.append("provides fibre")

        if "diabetes" in conditions:
            score += 10.0 if nutrients["sugar_g"] <= 8 else -min(30.0, nutrients["sugar_g"])
            score += min(8.0, nutrients["fiber_g"] * 1.5)
            if nutrients["sugar_g"] <= 8:
                reasons.append("lower-sugar option in the current database")
        if "hypertension" in conditions:
            score += 10.0 if nutrients["sodium_mg"] <= 200 else -min(30.0, nutrients["sodium_mg"] / 35.0)
            if nutrients["sodium_mg"] <= 200:
                reasons.append("lower in sodium for the suggested portion")
        if "high_cholesterol" in conditions:
            score += min(8.0, nutrients["fiber_g"] * 1.4)
            score -= max(0.0, nutrients["fat_g"] - 12.0) * 0.8
            reasons.append("ranked using fibre and total fat; saturated fat is not available")
        if "weight_management" in conditions:
            density = float(food["kcal_100g"])
            score += 10.0 if density <= 170 else -min(22.0, (density - 170.0) / 18.0)
            score += min(6.0, nutrients["fiber_g"] + nutrients["protein_g"] / 8.0)
            if density <= 170:
                reasons.append("lower energy density among available foods")
        if "kidney_disease" in conditions:
            score -= max(0.0, nutrients["sodium_mg"] - 150.0) / 20.0
            score -= max(0.0, nutrients["potassium_mg"] - 250.0) / 28.0
            reasons.append("requires clinician review of sodium, potassium, and portion size")

        occurrences = recent_counts.get(str(food["food_id"]), 0)
        if occurrences:
            score -= min(24.0, occurrences * 4.0)
        else:
            score += 8.0
            reasons.append("adds variety compared with the last 14 days")

        if not reasons:
            reasons.append("fits the remaining daily energy target")
        ranked.append({
            "food_id": food["food_id"],
            "name_en": food["canonical_name_en"],
            "name_ar": food["canonical_name_ar"],
            "portion_g": portion_g,
            "score": round(max(0.0, min(100.0, score)), 1),
            "nutrients": nutrients,
            "why": reasons[:3],
            "recent_occurrences_14d": occurrences,
            "verification_status": food["verification_status"],
        })

    ranked.sort(key=lambda item: (-item["score"], item["name_en"]))
    safe_limit = max(1, min(int(limit), 10))
    disclaimer = (
        "Suggestions are general meal-planning support based on configured targets and "
        "the foods currently available in Miqdar. They do not diagnose, treat, or replace "
        "advice from a physician or registered dietitian."
    )
    if "kidney_disease" in conditions:
        disclaimer += (
            " Kidney-related potassium and fluid needs vary substantially; use only "
            "clinician-approved targets."
        )
    return {
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "profile": profile,
        "context": {
            "today_totals": totals,
            "daily_goals": {
                key: float(goals[key])
                for key in (
                    "calories_kcal", "protein_g", "carbohydrate_g", "sugar_g",
                    "sodium_mg", "potassium_mg",
                )
            },
            "history_window_days": 14,
        },
        "suggestions": ranked[:safe_limit],
        "disclaimer": disclaimer,
        "method": "transparent_database_scoring_v1",
    }
