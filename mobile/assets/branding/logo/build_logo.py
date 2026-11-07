"""Rebuilds mobile/lib/ui/widgets/miqdar_logo_paths.dart from the logo files beside this script.

Needs potrace (brew install potrace) and a Python with numpy and pillow. From mobile/:
    python3 assets/branding/logo/build_logo.py
"""
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
TMP = tempfile.mkdtemp()

import numpy as np
from PIL import Image

a = np.asarray(Image.open(f"{HERE}/mark-color-on-black.jpg").convert("RGB")).astype(int)
r,g,b = a[...,0],a[...,1],a[...,2]
lum = (r+g+b)/3
green = (g - np.maximum(r,b) > 50)
white = (lum > 128) & ~green
def save(mask, name):
    # potrace traces black, so black = shape
    Image.fromarray(np.where(mask, 0, 255).astype(np.uint8)).convert("1").save(f"{TMP}/{name}.bmp")
save(white, "bowl"); save(green, "star")
w = np.asarray(Image.open(f"{HERE}/wordmark-white-on-black.png").convert("L")).astype(int)
save(w > 128, "word")
for n in ("bowl", "star", "word"):
    subprocess.run(["potrace", f"{TMP}/{n}.bmp", "-s", "-t", "8", "-a", "1.0", "-O", "0.2", "-o", f"{TMP}/{n}.svg"], check=True)

import re, json, textwrap

def parse(svg_file, H):
    txt = open(svg_file).read()
    subpaths = []
    for d in re.findall(r'<path d="([^"]+)"', txt, re.S):
        toks = re.findall(r'[MmLlCcZz]|-?\d+(?:\.\d+)?', d)
        i = 0; cmd = None; x = y = 0; cur = None
        def num():
            nonlocal i; v = float(toks[i]); i += 1; return v
        while i < len(toks):
            t = toks[i]
            if t.isalpha(): cmd = t; i += 1
            if cmd in 'zZ':
                if cur: subpaths.append(cur); cur = None
                continue
            if cmd in 'Mm':
                dx, dy = num(), num()
                if cmd == 'm': x, y = x + dx, y + dy
                else: x, y = dx, dy
                if cur: subpaths.append(cur)
                cur = [('M', [(x, y)])]
                cmd = 'l' if cmd == 'm' else 'L'
            elif cmd in 'Ll':
                dx, dy = num(), num()
                x, y = (x + dx, y + dy) if cmd == 'l' else (dx, dy)
                cur.append(('L', [(x, y)]))
            elif cmd in 'Cc':
                pts = [(num(), num()) for _ in range(3)]
                if cmd == 'c': pts = [(x + px, y + py) for px, py in pts]
                x, y = pts[-1]
                cur.append(('C', pts))
        if cur: subpaths.append(cur)
    # potrace transform: translate(0,H) scale(0.1,-0.1)
    return [[(c, [(px * 0.1, H - py * 0.1) for px, py in pts]) for c, pts in sp] for sp in subpaths]

def bbox(sps):
    xs = [p[0] for sp in sps for _, pts in sp for p in pts]
    ys = [p[1] for sp in sps for _, pts in sp for p in pts]
    return min(xs), min(ys), max(xs), max(ys)

def fmt(sps, ox, oy, k):
    out = []
    for sp in sps:
        for c, pts in sp:
            out.append(c + ' '.join(f"{(px-ox)*k:.1f},{(py-oy)*k:.1f}" for px, py in pts))
        out.append('Z')
    return ''.join(out)

tr = TMP
bowl = parse(f"{tr}/bowl.svg", 2048); star = parse(f"{tr}/star.svg", 2048)
x0, y0, x1, y1 = bbox(bowl + star)
k = 1000 / (x1 - x0)
mark = {"w": 1000, "h": round((y1 - y0) * k, 1), "bowl": fmt(bowl, x0, y0, k), "star": fmt(star, x0, y0, k)}
# star centre (for scaling around it)
sx0, sy0, sx1, sy1 = bbox(star)
mark["starCenter"] = [round(((sx0+sx1)/2 - x0)*k, 1), round(((sy0+sy1)/2 - y0)*k, 1)]
word = parse(f"{tr}/word.svg", 674)
wx0, wy0, wx1, wy1 = bbox(word); wk = 1000 / (wx1 - wx0)
# group subpaths into letters by overlapping x ranges
items = sorted(((bbox([sp])[0], bbox([sp])[2], sp) for sp in word), key=lambda t: t[0])
groups = []
for a, b, sp in items:
    if groups and a < groups[-1][1] - 2: groups[-1][1] = max(groups[-1][1], b); groups[-1][2].append(sp)
    else: groups.append([a, b, [sp]])
mark["word"] = {"w": 1000, "h": round((wy1 - wy0) * wk, 1), "letters": [fmt(g[2], wx0, wy0, wk) for g in groups]}

m = mark
def lit(s):
    lines, cur = [], ""
    for tok in s.split(" "):
        if cur and len(cur) + len(tok) > 96:
            lines.append(cur + " "); cur = tok
        else:
            cur = tok if not cur else cur + " " + tok
    lines.append(cur)
    return "\n".join("    '" + part + "'" for part in lines)
out = ["// Generated from the Miqdar logo files in assets/branding/logo/ by tracing them with potrace.",
       "// Do not edit by hand. See assets/branding/logo/README.md to regenerate.",
       "// Coordinates are absolute, in a box 1000 units wide; commands are M, L, C and Z only.",
       "",
       "const double kMarkWidth = 1000;",
       f"const double kMarkHeight = {m['h']};",
       f"const double kStarCenterX = {m['starCenter'][0]};",
       f"const double kStarCenterY = {m['starCenter'][1]};",
       "",
       "/// The bowl, in the ink color.",
       "const String kBowlPath =\n" + lit(m['bowl']) + ";",
       "",
       "/// The four-point star, in green.",
       "const String kStarPath =\n" + lit(m['star']) + ";",
       "",
       "const double kWordmarkWidth = 1000;",
       f"const double kWordmarkHeight = {m['word']['h']};",
       "",
       "/// The Latin wordmark, one entry per letter: M, i, q, d, a, r.",
       "const List<String> kWordmarkLetters = ["]
for L in m['word']['letters']:
    out.append(lit(L).replace("    '", "      '") + ",")
out.append("];")
open(os.path.join(HERE, '../../../lib/ui/widgets/miqdar_logo_paths.dart'), 'w').write("\n".join(out) + "\n")
