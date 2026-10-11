PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS source_registry (
  source_id TEXT PRIMARY KEY,
  authority TEXT NOT NULL,
  dataset_name TEXT NOT NULL,
  source_type TEXT NOT NULL,
  official_url TEXT NOT NULL,
  license_or_terms TEXT NOT NULL,
  retrieved_at TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS foods (
  food_id TEXT PRIMARY KEY,
  canonical_name_en TEXT NOT NULL,
  canonical_name_ar TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL,
  is_packaged INTEGER NOT NULL DEFAULT 0 CHECK (is_packaged IN (0, 1)),
  barcode TEXT,
  sfda_registration_no TEXT,
  brand TEXT,
  trade_name TEXT,
  ingredients TEXT,
  package_warnings TEXT,
  package_weight_g REAL,
  serving_basis_g REAL NOT NULL DEFAULT 100,
  source_id TEXT NOT NULL REFERENCES source_registry(source_id),
  source_record_id TEXT,
  source_record_url TEXT,
  verification_status TEXT NOT NULL,
  verified_at TEXT,
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_foods_barcode
ON foods(barcode) WHERE barcode IS NOT NULL AND barcode <> '';
CREATE UNIQUE INDEX IF NOT EXISTS idx_foods_sfda_registration
ON foods(sfda_registration_no)
WHERE sfda_registration_no IS NOT NULL AND sfda_registration_no <> '';
CREATE INDEX IF NOT EXISTS idx_foods_names
ON foods(canonical_name_en, canonical_name_ar);

CREATE TABLE IF NOT EXISTS food_aliases (
  alias_id INTEGER PRIMARY KEY AUTOINCREMENT,
  food_id TEXT NOT NULL REFERENCES foods(food_id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  UNIQUE(food_id, alias, language)
);

CREATE TABLE IF NOT EXISTS nutrient_profiles (
  food_id TEXT PRIMARY KEY REFERENCES foods(food_id) ON DELETE CASCADE,
  kcal_100g REAL NOT NULL CHECK (kcal_100g >= 0),
  protein_g_100g REAL NOT NULL CHECK (protein_g_100g >= 0),
  carbohydrate_g_100g REAL NOT NULL CHECK (carbohydrate_g_100g >= 0),
  fat_g_100g REAL NOT NULL CHECK (fat_g_100g >= 0),
  sugar_g_100g REAL NOT NULL CHECK (sugar_g_100g >= 0),
  fiber_g_100g REAL NOT NULL CHECK (fiber_g_100g >= 0),
  sodium_mg_100g REAL NOT NULL CHECK (sodium_mg_100g >= 0),
  potassium_mg_100g REAL NOT NULL CHECK (potassium_mg_100g >= 0),
  nutrient_source_id TEXT NOT NULL REFERENCES source_registry(source_id),
  nutrient_source_record_id TEXT,
  verification_status TEXT NOT NULL,
  verified_at TEXT,
  notes TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS food_images (
  image_id TEXT PRIMARY KEY,
  food_id TEXT NOT NULL REFERENCES foods(food_id) ON DELETE CASCADE,
  relative_path TEXT NOT NULL UNIQUE,
  source_id TEXT NOT NULL REFERENCES source_registry(source_id),
  source_url TEXT,
  rights_holder TEXT NOT NULL,
  license_or_permission TEXT NOT NULL,
  sha256 TEXT NOT NULL UNIQUE,
  pixel_width INTEGER NOT NULL,
  pixel_height INTEGER NOT NULL,
  split TEXT NOT NULL CHECK (split IN ('train', 'validation', 'test', 'reference')),
  capture_angle TEXT NOT NULL DEFAULT 'unknown',
  lighting TEXT NOT NULL DEFAULT 'unknown',
  approved_for_model_use INTEGER NOT NULL DEFAULT 0 CHECK (approved_for_model_use IN (0, 1)),
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS image_embeddings (
  image_id TEXT NOT NULL REFERENCES food_images(image_id) ON DELETE CASCADE,
  model_name TEXT NOT NULL,
  vector_json TEXT NOT NULL,
  dimensions INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (image_id, model_name)
);

CREATE TABLE IF NOT EXISTS users (
  user_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS nutrition_goals (
  user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  calories_kcal REAL NOT NULL,
  sugar_g REAL NOT NULL,
  sodium_mg REAL NOT NULL,
  potassium_mg REAL NOT NULL,
  carbohydrate_g REAL NOT NULL,
  protein_g REAL NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS health_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  conditions_json TEXT NOT NULL DEFAULT '[]',
  dietary_preferences_json TEXT NOT NULL DEFAULT '[]',
  allergens_json TEXT NOT NULL DEFAULT '[]',
  disliked_foods_json TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS devices (
  device_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  paired INTEGER NOT NULL DEFAULT 0 CHECK (paired IN (0, 1)),
  wifi_ssid TEXT,
  firmware_version TEXT,
  last_sync_at TEXT
);

CREATE TABLE IF NOT EXISTS meals (
  meal_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  eaten_at TEXT NOT NULL,
  meal_type TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_meals_user_date ON meals(user_id, eaten_at DESC);

CREATE TABLE IF NOT EXISTS meal_items (
  meal_item_id TEXT PRIMARY KEY,
  meal_id TEXT NOT NULL REFERENCES meals(meal_id) ON DELETE CASCADE,
  food_id TEXT NOT NULL REFERENCES foods(food_id),
  weight_g REAL NOT NULL CHECK (weight_g > 0),
  recognition_confidence REAL CHECK (recognition_confidence BETWEEN 0 AND 1),
  calories_kcal REAL NOT NULL,
  protein_g REAL NOT NULL,
  carbohydrate_g REAL NOT NULL,
  fat_g REAL NOT NULL,
  sugar_g REAL NOT NULL,
  fiber_g REAL NOT NULL,
  sodium_mg REAL NOT NULL,
  potassium_mg REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS recognition_events (
  event_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  food_id TEXT REFERENCES foods(food_id),
  image_sha256 TEXT NOT NULL,
  previous_image_sha256 TEXT,
  current_weight_g REAL NOT NULL,
  previous_weight_g REAL,
  new_food_detected INTEGER NOT NULL CHECK (new_food_detected IN (0, 1)),
  confidence REAL,
  provider TEXT NOT NULL,
  recognition_ms INTEGER NOT NULL,
  alert_evaluation_ms INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS health_alerts (
  alert_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  meal_id TEXT REFERENCES meals(meal_id) ON DELETE SET NULL,
  nutrient_key TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
  current_value REAL NOT NULL,
  threshold_value REAL NOT NULL,
  message_en TEXT NOT NULL,
  message_ar TEXT NOT NULL,
  evaluation_ms INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  acknowledged_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_alerts_user_date ON health_alerts(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS sync_runs (
  sync_id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL REFERENCES source_registry(source_id),
  started_at TEXT NOT NULL,
  completed_at TEXT,
  status TEXT NOT NULL,
  records_seen INTEGER NOT NULL DEFAULT 0,
  records_written INTEGER NOT NULL DEFAULT 0,
  error_message TEXT
);
