#!/usr/bin/env python3
"""Simula a tela do rEFInd (mesma conta do refind/menu.c) com o tema gerado."""
import sys
from PIL import Image
th, out = sys.argv[1], sys.argv[2]
W, H, T, X = 1280, 1024, 288, 8
bg = Image.open(f'{th}/background.png').convert('RGBA')
sel = Image.open(f'{th}/selection.png').convert('RGBA')
x0 = (W + X - (T + X) * 2) // 2; y0 = H // 2 - T // 2
for i, n in enumerate(('ubuntu.png', 'windows.png')):
    ic = Image.open(f'{th}/{n}').convert('RGBA'); x = x0 + i * (T + X)
    if i == 0: bg.alpha_composite(sel, (x, y0))
    else:
        r, g, b, a = ic.split(); ic = Image.merge('RGBA', [c.point(lambda v: int(v * .55)) for c in (r, g, b)] + [a])
    bg.alpha_composite(ic, (x + (T - 256) // 2, y0 + (T - 256) // 2))
bg.convert('RGB').save(out)
