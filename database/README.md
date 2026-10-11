# Miqdar data package

`miqdar_nutrition.db` is the ready-to-query SQLite database. Rebuild it from reviewed CSV seeds with `scripts/build_database.py`.

## Verification states

- `verified_official_record`: exact official source record and identifier are stored.
- `requires_usda_sync`: runnable prototype value that must be replaced by an exact USDA record.
- `sfda_registered_nutrition_pending`: officially registered Saudi product metadata exists, but no verified nutrient profile has been attached.

The application must display these states. A product must not move from “nutrition pending” to “verified” until its nutrient source record or verified physical label is stored.

## Key tables

- `source_registry`: authority, dataset, official URL, terms, retrieval date.
- `foods`: generic foods and SFDA registered products.
- `nutrient_profiles`: per-100 g values and exact nutrition provenance.
- `food_images`: rights, checksum, split, capture conditions, model approval.
- `image_embeddings`: provider/model-specific vectors for similarity reranking.
- `meals` and `meal_items`: persistent nutrition history.
- `nutrition_goals` and `health_alerts`: user thresholds and alert evidence.
- `recognition_events`: provider latency, alert latency, image/weight sequence evidence.

## Image rule

No image is imported unless both `rights_holder` and `license_or_permission` are populated. `approved_for_model_use` remains a separate explicit decision.
