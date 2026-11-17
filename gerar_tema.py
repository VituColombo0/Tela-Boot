#!/usr/bin/env python3
"""Gera o tema do seletor de boot (Grubz/rEFInd) para tela 1280x1024.
Uso: python3 gerar_tema.py <pasta-origem-do-tema> <pasta-saida>"""
import sys, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

SRC, OUT = sys.argv[1], sys.argv[2]
W, H = 1280, 1024
ICON = 256           # big_icon_size
SEL = ICON * 9 // 8  # rEFInd desenha a seleção com 9/8 do ícone
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def src(n): return Image.open(f"{SRC}/{n}").convert("RGBA")

# ---------- ícone Ubuntu cromado, no mesmo estilo do Windows ----------
def ubuntu_icon():
    S = 4; N = 384 * S
    cx, cy = 182 * S, 190 * S           # centro do logo (mesma área do Windows)
    R_out, R_in = 122 * S, 82 * S
    head_r, head_d, gap = 27 * S, 124 * S, 13 * S
    m = Image.new("L", (N, N), 0); d = ImageDraw.Draw(m)
    d.ellipse([cx-R_out, cy-R_out, cx+R_out, cy+R_out], 255)
    d.ellipse([cx-R_in, cy-R_in, cx+R_in, cy+R_in], 0)
    heads = []
    for ang in (-60, 60, 180):
        a = math.radians(ang)
        hx, hy = cx + head_d*math.cos(a), cy + head_d*math.sin(a)
        heads.append((hx, hy))
        r = head_r + gap
        d.ellipse([hx-r, hy-r, hx+r, hy+r], 0)
    for hx, hy in heads:
        d.ellipse([hx-head_r, hy-head_r, hx+head_r, hy+head_r], 255)

    # metal escovado: gradiente diagonal + riscos finos
    random.seed(7)
    noise = Image.effect_noise((N, N), 60).filter(ImageFilter.BoxBlur(0))
    streak = noise.resize((N, N // 40)).resize((N, N), Image.BILINEAR)
    streak = streak.rotate(-28, resample=Image.BILINEAR, expand=False)
    grad = Image.linear_gradient("L").rotate(-40, expand=False).resize((N, N))
    grad = ImageChops.invert(grad)
    base = Image.blend(grad.point(lambda v: 40 + v * 0.62), streak, 0.30)

    # chanfro: luz vindo de cima-esquerda
    soft = m.filter(ImageFilter.GaussianBlur(7 * S))
    sh = 4 * S
    hl = ImageChops.subtract(soft, soft.transform(soft.size, Image.AFFINE, (1, 0, sh, 0, 1, sh)))
    dk = ImageChops.subtract(soft, soft.transform(soft.size, Image.AFFINE, (1, 0, -sh, 0, 1, -sh)))
    lum = ImageChops.add(base, hl.point(lambda v: min(255, v * 2.2)))
    lum = ImageChops.subtract(lum, dk.point(lambda v: min(255, v * 1.6)))

    # borda fina clara + toque lilás como no ícone do Windows
    edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(2 * S + 1)))
    rgb = Image.merge("RGB", (lum, lum, lum.point(lambda v: min(255, int(v * 1.06) + 4))))
    lilac = Image.new("RGB", (N, N), (206, 192, 232))
    rgb = Image.composite(lilac, rgb, edge.point(lambda v: int(v * 0.85)))
    icon = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    icon.paste(rgb, (0, 0), m)
    icon = icon.resize((384, 384), Image.LANCZOS)

    # rótulo igual ao do Windows (mesma fonte, tamanho, cor e posição)
    dr = ImageDraw.Draw(icon)
    f = ImageFont.truetype(FONT, 30)
    dr.text((26, 361), "Ubuntu", font=f, fill=(232, 232, 240, 255), anchor="ls")
    return icon

def to_icon(im): return im.resize((ICON, ICON), Image.LANCZOS)

# ---------- fundo 1280x1024 sem distorcer (original é 16:9) ----------
# A imagem fica inteira no meio (1280x720) e se dissolve no preto em cima e embaixo.
def background():
    bg = src("background.png").convert("RGB")
    sh = round(bg.height * W / bg.width)               # 720
    bg = bg.resize((W, sh), Image.LANCZOS)
    top = (H - sh) // 2
    fade = Image.new("L", (W, sh), 255); fd = ImageDraw.Draw(fade)
    F = 110
    for y in range(F):
        v = int(255 * (y / F) ** 1.6)
        fd.line([(0, y), (W, y)], v)
        fd.line([(0, sh - 1 - y), (W, sh - 1 - y)], v)
    out = Image.new("RGB", (W, H), (0, 0, 0))
    out.paste(bg, (0, top), fade)
    return out

if __name__ == "__main__":
    import os; os.makedirs(OUT, exist_ok=True)
    ub = ubuntu_icon()
    to_icon(ub).save(f"{OUT}/ubuntu.png")
    to_icon(src("windows.png")).save(f"{OUT}/windows.png")
    src("selection.png").resize((SEL, SEL), Image.LANCZOS).save(f"{OUT}/selection.png")
    background().save(f"{OUT}/background.png", optimize=True)
    print("ok", OUT)
