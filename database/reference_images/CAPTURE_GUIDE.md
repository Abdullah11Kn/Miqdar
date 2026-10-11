# Miqdar food-image capture guide

The safest production source is a controlled team capture set. Do not copy retail, restaurant, social-media, or search-engine images into the model database unless the project has explicit model-training rights.

For each food class, capture at least 60 original images before a prototype evaluation and 200+ before relying on class-specific metrics. Include:

- 5 top-down, 5 at 45 degrees, and 5 side-angle images per serving/packaging variant;
- at least 4 plates or containers, 3 backgrounds, and 3 lighting conditions;
- full portions, partial portions, mixed plates, mild occlusion, and realistic leftovers;
- the physical nutrition label and barcode for packaged products as separate evidence images;
- train/validation/test separation by capture session, not random near-duplicate frames.

Folder convention:

```text
reference_images/
  food_dates_medjool/
  food_rice_white_cooked/
  food_chicken_breast_roasted/
  rights.csv
```

Copy `rights.template.csv` to `rights.csv`, document every image, then run:

```bash
python database/scripts/import_reference_images.py
```

Images are rejected when the file is missing, the path escapes the image root, or rights fields are empty. The database records SHA-256, dimensions, split, angle, lighting, permission, and approval state for every accepted image.
