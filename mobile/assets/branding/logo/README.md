# The Miqdar logo

Abdullah's logo, as he supplied it on 2026-11-07. These files are the source; they are not bundled into the app.

| File | What |
|---|---|
| `mark-black-on-white.jpg`, `mark-white-on-black.jpg` | The mark in one color |
| `mark-color-on-black.jpg` | The mark with the green star. The traces come from this one |
| `wordmark-white-on-black.png` | The Latin wordmark "Miqdar" |
| `trace-*.svg` | Vector traces made by `build_logo.py`, for design tools |

The app draws the logo from vectors, not from these pictures, so it stays sharp at any size and can animate:
`lib/ui/widgets/miqdar_logo_paths.dart` holds the shapes, and `lib/ui/widgets/miqdar_logo.dart` paints them. The bowl and
wordmark use `ink`, and the star uses `logoGreen`, so both themes work.

If the logo changes, replace the files here and run, from `mobile/`:

```bash
brew install potrace      # once
python3 assets/branding/logo/build_logo.py   # needs numpy and pillow
```
