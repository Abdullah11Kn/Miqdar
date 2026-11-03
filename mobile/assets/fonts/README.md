# Icon font

`MiqdarSymbols.ttf` is Google's Material Symbols Rounded (Apache License 2.0), reduced to the icons the app uses, with
weight 500 fixed and only the FILL axis kept. The full font is 15 MB.

To add an icon, add its name to `build_icons.py` and run it with fontTools installed:

    python3 build_icons.py <MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf> <its .codepoints file> MiqdarSymbols.ttf ../../lib/miqdar_icons.dart

Both source files are in `variablefont/` of https://github.com/google/material-design-icons.
