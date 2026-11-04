# Icon font

`MiqdarSymbols.ttf` is Google's Material Symbols Rounded (Apache License 2.0), reduced to the icons the app uses, with
only the FILL axis and weights 300 to 400 kept. The full font is 15 MB.

To add an icon, add its name to `build_icons.py` and run it with fontTools installed:

    python3 build_icons.py <MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf> <its .codepoints file> MiqdarSymbols.ttf ../../lib/miqdar_icons.dart

Both source files are in `variablefont/` of https://github.com/google/material-design-icons.

# Text fonts

The app is set in Thmanyah Sans, Thmanyah Serif Display and Thmanyah Serif Text. Their licence allows embedding them in the
built app but forbids hosting or changing the files, and this repository is public. So `thmanyah/` is ignored by git, and
the files stay unchanged. On a new Mac, put the three zips from https://font.thmanyah.com in `~/Downloads` and run
`./install_thmanyah.sh`. The app does not build without them.
