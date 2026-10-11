from __future__ import annotations

import importlib.util
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DB = ROOT / "database" / "miqdar_nutrition.db"
SYNC_PATH = ROOT / "database" / "scripts" / "sync_sfda.py"


spec = importlib.util.spec_from_file_location("sync_sfda", SYNC_PATH)
sync_sfda = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(sync_sfda)


class SfdaImporterTests(unittest.TestCase):
    def test_registered_product_is_not_misrepresented_as_nutrition(self) -> None:
        temp_dir = Path(tempfile.mkdtemp(prefix="miqdar-sfda-test-"))
        try:
            db_path = temp_dir / "test.db"
            shutil.copy2(SOURCE_DB, db_path)
            payload = {
                "data": [{
                    "barcode": "6280000000012",
                    "referanceNumber": "SFDA-DEMO-001",
                    "brandName": "Official API sample",
                    "tradeName": "Registered Sample Product",
                    "itemWeight": "250",
                }]
            }
            items = sync_sfda.find_items(payload)
            with sqlite3.connect(db_path) as connection:
                written = sync_sfda.upsert_items(connection, items)
                connection.commit()
                row = connection.execute(
                    """
                    SELECT f.verification_status, n.food_id FROM foods f
                    LEFT JOIN nutrient_profiles n ON n.food_id=f.food_id
                    WHERE f.sfda_registration_no='SFDA-DEMO-001'
                    """
                ).fetchone()
            self.assertEqual(written, 1)
            self.assertEqual(row[0], "sfda_registered_nutrition_pending")
            self.assertIsNone(row[1])
        finally:
            shutil.rmtree(temp_dir)


if __name__ == "__main__":
    unittest.main()
