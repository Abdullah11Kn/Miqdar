"""Makes the app icons (iOS and Android) from the color mark on black.

Run from mobile/:  python3 assets/branding/logo/build_app_icon.py   (needs numpy and pillow)

The mark is centred and scaled to fill about two thirds of the icon's width, on pure black, so it sits well inside
the rounded corners iOS and Android cut. JPEG noise in the background is cleared to true black.
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
MOBILE = HERE.parents[2]
SOURCE = HERE / "mark-color-on-black.jpg"
MARK_WIDTH = 0.66  # the mark's share of the icon's width

IOS = MOBILE / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def master() -> Image.Image:
    img = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.int16)
    # Near-black JPEG noise becomes true black; the mark's soft edges stay.
    dark = img.max(axis=2) < 36
    img[dark] = 0
    ys, xs = np.nonzero(img.max(axis=2) > 90)
    left, right, top, bottom = xs.min(), xs.max(), ys.min(), ys.max()
    cx, cy = (left + right) / 2, (top + bottom) / 2
    side = (right - left) / MARK_WIDTH
    box = (round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))
    mark = Image.fromarray(img.clip(0, 255).astype(np.uint8))
    canvas = Image.new("RGB", (round(side), round(side)), (0, 0, 0))
    canvas.paste(mark.crop(box), (0, 0))
    return canvas.resize((1024, 1024), Image.LANCZOS)


def main() -> None:
    icon = master()
    for path in IOS.glob("Icon-App-*.png"):
        # Icon-App-83.5x83.5@2x.png -> 83.5 * 2
        size_part, scale_part = path.stem.removeprefix("Icon-App-").split("@")
        pixels = round(float(size_part.split("x")[0]) * int(scale_part.rstrip("x")))
        icon.resize((pixels, pixels), Image.LANCZOS).save(path, optimize=True)
    for density, pixels in ANDROID.items():
        out = MOBILE / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        icon.resize((pixels, pixels), Image.LANCZOS).save(out, optimize=True)
    icon.save(HERE / "app-icon-1024.png", optimize=True)
    print("App icons written.")


if __name__ == "__main__":
    main()
