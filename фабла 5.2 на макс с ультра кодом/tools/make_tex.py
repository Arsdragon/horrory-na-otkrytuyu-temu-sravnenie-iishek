"""Свои текстуры (то, чего нет на Poly Haven): изморозь, снежинки, ореолы, шум, следы, лёд, бумага, значки.

    python tools/make_tex.py            всё
    python tools/make_tex.py frost ice  только названные
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tex")
R = np.random.default_rng(1987)
FONTS = r"C:\Windows\Fonts"


def font(name, size):
    for n in (name, "arial.ttf"):
        p = os.path.join(FONTS, n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def save(name, arr_or_img):
    os.makedirs(OUT, exist_ok=True)
    im = arr_or_img
    if isinstance(im, np.ndarray):
        a = np.clip(im, 0.0, 1.0)
        im = Image.fromarray((a * 255.0 + 0.5).astype(np.uint8))
    im.save(os.path.join(OUT, name))
    print("  ", name, im.size)


def fft_noise(n, beta, seed=0):
    """Бесшовный шум со спектром 1/f^beta, значения 0..1."""
    rg = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    amp = 1.0 / np.power(r, beta)
    amp[0, 0] = 0.0
    ph = rg.uniform(0, 2 * np.pi, (n, n))
    spec = amp * np.exp(1j * ph)
    x = np.real(np.fft.ifft2(spec))
    x -= x.min()
    x /= x.max() + 1e-9
    return x


def worley(n, cells, seed=0, tile=True):
    """Бесшовный шум Ворлея: возвращает (F1, F2) в долях размера ячейки."""
    rg = np.random.default_rng(seed)
    pts = rg.uniform(0, 1, (cells, cells, 2))
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    u = x / n * cells
    v = y / n * cells
    cu = np.floor(u).astype(int)
    cv = np.floor(v).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ix = (cu + dx) % cells
            iy = (cv + dy) % cells
            px = cu + dx + pts[iy, ix, 0]
            py = cv + dy + pts[iy, ix, 1]
            d = np.sqrt((px - u) ** 2 + (py - v) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            f1 = np.where(closer, d, f1)
    return f1, f2


def normal_from_height(h, strength=2.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    ln = np.sqrt(dx * dx + dy * dy + nz * nz)
    return np.dstack([(-dx / ln) * 0.5 + 0.5, (-dy / ln) * 0.5 + 0.5, (nz / ln) * 0.5 + 0.5])


def blur(a, rad):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(rad))).astype(np.float64) / 255.0


# ---------------------------------------------------------------- экран

def t_frost():
    """Изморозь на «стекле» экрана: папоротники льда растут от краёв к середине.
    R — когда иней дойдёт до точки (0 — сразу у края, 1 — в самую последнюю очередь), G — яркость кристаллов."""
    W, H = 1024, 576
    rg = np.random.default_rng(77)
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)

    def fern(x, y, ang, ln, width, bright, depth):
        if ln < 6 or depth > 3:
            return
        steps = max(3, int(ln / 7))
        px, py = x, y
        a = ang
        for i in range(steps):
            a += rg.uniform(-0.09, 0.09)
            nx = px + math.cos(a) * 7
            ny = py + math.sin(a) * 7
            k = 1.0 - i / steps
            d.line((px, py, nx, ny), fill=int(min(255, bright * (0.45 + 0.55 * k))), width=max(1, int(width * k + 0.5)))
            if i % 2 == 0 and depth < 3:
                for side in (-1, 1):
                    if rg.uniform() < 0.8:
                        fern(nx, ny, a + side * rg.uniform(0.75, 1.1), ln * k * rg.uniform(0.28, 0.42), max(1, width - 1), bright * 0.8, depth + 1)
            px, py = nx, ny

    for _ in range(170):
        e = int(rg.integers(0, 4))
        if e == 0:
            x, y, ang = rg.uniform(0, W), -4, math.pi / 2
        elif e == 1:
            x, y, ang = rg.uniform(0, W), H + 4, -math.pi / 2
        elif e == 2:
            x, y, ang = -4, rg.uniform(0, H), 0.0
        else:
            x, y, ang = W + 4, rg.uniform(0, H), math.pi
        fern(x, y, ang + rg.uniform(-0.5, 0.5), rg.uniform(90, 330), 3, 255, 0)
    cr = np.asarray(im.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float64) / 255.0
    soft = np.asarray(im.filter(ImageFilter.GaussianBlur(9))).astype(np.float64) / 255.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    u = np.abs(xx / (W - 1) - 0.5) * 2.0
    v = np.abs(yy / (H - 1) - 0.5) * 2.0
    edge = np.maximum(u, v) * 0.55 + np.sqrt(u * u + v * v) / 1.414 * 0.45     # 0 в центре .. 1 у края
    n1 = np.asarray(Image.fromarray((fft_noise(512, 1.8, 7) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float64) / 255.0
    grow = np.clip((1.0 - edge) * 1.15 + (n1 - 0.5) * 0.28 - soft * 0.5 - cr * 0.12, 0, 1)
    fine = np.asarray(Image.fromarray((fft_noise(512, 0.9, 8) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float64) / 255.0
    cryst = np.clip(cr * 0.85 + soft * 0.5 + fine * 0.22, 0, 1)
    save("frost.png", np.dstack([grow, cryst, soft]))


def t_cookie():
    # пятно налобного фонаря: горячий центр, мягкий край, слабые кольца отражателя
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    u = (x - (n - 1) / 2) / (n / 2)
    v = (y - (n - 1) / 2) / (n / 2)
    rr = np.sqrt(u * u + v * v)
    core = np.exp(-(rr / 0.34) ** 2) * 0.75
    wide = np.clip(1.0 - rr, 0, 1) ** 0.9 * 0.42
    ring = np.exp(-((rr - 0.62) / 0.05) ** 2) * 0.06 + np.exp(-((rr - 0.8) / 0.04) ** 2) * 0.03
    a = (core + wide + ring) * np.clip((1.0 - rr) / 0.12, 0, 1)
    a *= 0.95 + 0.05 * fft_noise(n, 1.5, 61)
    a = np.clip(a / a.max(), 0, 1)
    save("cookie.png", np.dstack([a, a * 0.97, a * 0.9]))


def t_noise():
    n = 256
    save("noise.png", np.dstack([fft_noise(n, 2.2, 11), fft_noise(n, 1.3, 12), fft_noise(n, 0.4, 13)]))


def t_flake():
    h, w = 128, 32
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    u = (x - (w - 1) / 2) / (w / 2)
    v = (y - (h - 1) / 2) / (h / 2)
    a = np.exp(-(u * u) * 5.0) * np.clip(1.0 - np.abs(v) ** 2.2, 0, 1)
    rgba = np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a])
    save("flake.png", rgba)
    n = 64
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    rr = np.sqrt((x - 31.5) ** 2 + (y - 31.5) ** 2) / 32.0
    a = np.clip(1.0 - rr, 0, 1) ** 2.0
    save("dot.png", np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a]))


def t_halo():
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    u = (x - (n - 1) / 2) / (n / 2)
    v = (y - (n - 1) / 2) / (n / 2)
    rr = np.sqrt(u * u + v * v)
    core = np.exp(-rr * rr * 60.0)
    glow = np.exp(-rr * 4.2) * 0.55
    spikes = np.exp(-np.abs(v) * 70.0) * np.exp(-np.abs(u) * 3.0) * 0.35 + np.exp(-np.abs(u) * 90.0) * np.exp(-np.abs(v) * 5.0) * 0.18
    a = np.clip(core + glow + spikes, 0, 1) * np.clip(1.0 - rr, 0, 1) ** 0.6
    save("halo.png", np.dstack([a, a, a]))
    # блик глаза: маленькая яркая точка с коротким крестом
    core = np.exp(-rr * rr * 26.0)
    spikes = np.exp(-np.abs(v) * 40.0) * np.exp(-np.abs(u) * 5.0) * 0.35
    a = np.clip(core + spikes + np.exp(-rr * 4.0) * 0.45, 0, 1) * np.clip(1.0 - rr, 0, 1)
    im = Image.fromarray((np.dstack([a, a, a]) * 255).astype(np.uint8)).resize((64, 64), Image.LANCZOS)
    save("eye.png", im)


def t_foot():
    # след унта: подошва и каблук, альфа = глубина
    w, h = 64, 128
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.ellipse((10, 6, 54, 86), fill=255)
    d.ellipse((14, 78, 50, 124), fill=235)
    d.rectangle((12, 40, 52, 96), fill=250)
    im = im.filter(ImageFilter.GaussianBlur(3.0))
    a = np.asarray(im).astype(np.float64) / 255.0
    rim = np.clip(blur(a, 5.0) - a * 0.85, 0, 1) * 1.5        # вал снега вокруг — светлее
    y = np.mgrid[0:h, 0:w][0]
    tread = 0.85 + 0.15 * np.sin(y * 0.9)
    depth = a * tread
    save("foot.png", np.dstack([rim, rim, rim, np.clip(depth, 0, 1)]))
    # босой след существа: узкая длинная стопа и пять длинных пальцев
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.ellipse((20, 44, 46, 122), fill=255)
    d.ellipse((17, 36, 49, 70), fill=255)
    for i, (x, top) in enumerate(((14, 14), (22, 4), (30, 2), (38, 6), (45, 16))):
        d.ellipse((x - 3, top, x + 3, top + 34), fill=240)
    im = im.filter(ImageFilter.GaussianBlur(2.2))
    a = np.asarray(im).astype(np.float64) / 255.0
    rim = np.clip(blur(a, 5.0) - a * 0.85, 0, 1) * 1.5
    save("footbare.png", np.dstack([rim, rim, rim, a]))


# ---------------------------------------------------------------- материалы мира

def t_ice():
    n = 512
    base = fft_noise(n, 2.0, 21)
    fine = fft_noise(n, 1.0, 22)
    f1, f2 = worley(n, 6, 23)
    cracks = np.clip(1.0 - (f2 - f1) * 14.0, 0, 1) ** 2
    f1b, f2b = worley(n, 15, 24)
    cracks2 = np.clip(1.0 - (f2b - f1b) * 18.0, 0, 1) ** 2 * 0.5
    h = base * 0.6 + fine * 0.25 - cracks * 0.5 - cracks2 * 0.2
    lum = 0.55 + base * 0.25 + fine * 0.12 + cracks * 0.3 + cracks2 * 0.15
    col = np.dstack([lum * 0.72, lum * 0.86, lum * 1.0])
    save("ice_d.jpg", Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)))
    save("ice_n.jpg", Image.fromarray((normal_from_height(blur(h, 1.0), 6.0) * 255).astype(np.uint8)))
    # иней на стенах и предметах: белые кристаллы с альфой
    f1, f2 = worley(n, 40, 25)
    cr = np.clip(1.0 - f1 * 2.2, 0, 1) ** 1.5
    mask = np.clip(fft_noise(n, 2.0, 26) * 1.8 - 0.45, 0, 1)
    a = np.clip(cr * 0.7 + fine * 0.5, 0, 1) * mask
    save("rime.png", np.dstack([np.ones_like(a) * 0.93, np.ones_like(a) * 0.96, np.ones_like(a), a]))


def t_paper():
    n = 512
    base = fft_noise(n, 2.0, 31)
    fib = fft_noise(n, 0.7, 32)
    lum = 0.80 + (base - 0.5) * 0.12 + (fib - 0.5) * 0.06
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    edge = np.minimum(np.minimum(x, n - 1 - x), np.minimum(y, n - 1 - y)) / n
    lum *= 0.86 + 0.14 * np.clip(edge * 9.0, 0, 1)
    col = np.dstack([lum * 1.0, lum * 0.95, lum * 0.82])
    save("paper.jpg", Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)))
    # тетрадный лист в клетку
    grid = np.ones((n, n))
    grid[(y % 21) < 1.2] = 0.78
    grid[(x % 21) < 1.2] = 0.78
    lum2 = (0.86 + (base - 0.5) * 0.08) * grid
    col = np.dstack([lum2 * 0.97, lum2 * 0.98, lum2 * 1.0])
    col[:, 58:60, :] = col[:, 58:60, :] * np.array([1.0, 0.45, 0.45])
    save("paper_grid.jpg", Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)))


def t_cloth():
    # матрас в полоску
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    weave = 0.92 + 0.08 * np.sin(x * 2.4) * np.sin(y * 2.4)
    stripe = np.where((x % 64) < 10, 0.45, np.where((x % 64) < 14, 0.9, np.where((x % 64) < 18, 0.45, 1.0)))
    dirt = 0.85 + 0.15 * fft_noise(n, 2.0, 41)
    lum = weave * dirt
    col = np.dstack([lum * (0.80 * stripe + 0.12), lum * (0.76 * stripe + 0.14), lum * (0.66 + 0.2 * stripe)])
    save("mattress.jpg", Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)))
    # армейское одеяло: серо-зелёная шерсть с двумя полосами
    wool = 0.8 + 0.2 * fft_noise(n, 0.6, 42)
    band = np.where(((y > 28) & (y < 40)) | ((y > 48) & (y < 54)), 1.9, 1.0)
    col = np.dstack([wool * 0.27 * band, wool * 0.30 * band, wool * 0.26 * band])
    save("blanket.jpg", Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)))
    # трос: витой, диагональные пряди
    n = 64
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    s = 0.5 + 0.5 * np.sin((x + y) * (2 * np.pi / 16.0))
    lum = 0.35 + 0.5 * s
    col = np.dstack([lum * 0.62, lum * 0.56, lum * 0.44])
    save("rope.png", Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)))


def t_glass():
    # замёрзшее окно: ледяные папоротники от рамы, в середине протаявшее тёмное пятно
    n = 512
    rg = np.random.default_rng(55)
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)

    def fern(x, y, ang, ln, width, bright, depth):
        if ln < 5 or depth > 3:
            return
        steps = max(3, int(ln / 6))
        px, py, a = x, y, ang
        for i in range(steps):
            a += rg.uniform(-0.1, 0.1)
            nx, ny = px + math.cos(a) * 6, py + math.sin(a) * 6
            k = 1.0 - i / steps
            d.line((px, py, nx, ny), fill=int(min(255, bright * (0.5 + 0.5 * k))), width=max(1, int(width * k + 0.5)))
            if i % 2 == 0 and depth < 3:
                for side in (-1, 1):
                    if rg.uniform() < 0.85:
                        fern(nx, ny, a + side * rg.uniform(0.7, 1.1), ln * k * rg.uniform(0.3, 0.45), max(1, width - 1), bright * 0.8, depth + 1)
            px, py = nx, ny
    for _ in range(90):
        e = int(rg.integers(0, 4))
        t = rg.uniform(0, n)
        x, y, ang = ((t, 0, math.pi / 2), (t, n, -math.pi / 2), (0, t, 0.0), (n, t, math.pi))[e]
        fern(x, y, ang + rg.uniform(-0.6, 0.6), rg.uniform(70, 230), 3, 255, 0)
    cr = np.asarray(im.filter(ImageFilter.GaussianBlur(0.7))).astype(np.float64) / 255.0
    soft = np.asarray(im.filter(ImageFilter.GaussianBlur(7))).astype(np.float64) / 255.0
    feather = fft_noise(n, 1.5, 52)
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    u = (x - n / 2) / (n / 2)
    v = (y - n / 2) / (n / 2)
    rr = np.sqrt(u * u * 1.2 + v * v)
    hole = np.clip((rr - 0.22 + (feather - 0.5) * 0.3) * 2.6, 0, 1)
    a = np.clip(0.3 + cr * 0.45 + soft * 0.6 + feather * 0.25, 0, 1) * hole
    a = np.clip(a + 0.05, 0, 1)
    lum = np.clip(0.55 + cr * 0.4 + soft * 0.2, 0, 1)
    save("glassfrost.png", np.dstack([lum * 0.82, lum * 0.9, lum, a]))


def t_hand():
    # отпечаток ладони на инее: протаявшее тёмное пятно с пятью пальцами
    w, h = 192, 256
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.ellipse((46, 120, 150, 236), fill=255)
    for x, top, wd in ((30, 96, 20), (56, 34, 22), (86, 16, 22), (116, 30, 22), (146, 70, 20)):
        d.rounded_rectangle((x, top, x + wd, 170), 10, fill=255)
    d.polygon([(40, 150), (14, 118), (26, 106), (56, 140)], fill=255)
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(3.5))).astype(np.float64) / 255.0
    rim = np.clip(np.asarray(im.filter(ImageFilter.GaussianBlur(9))).astype(np.float64) / 255.0 - a * 0.8, 0, 1)
    rgb = np.dstack([rim * 0.9 + 0.02, rim * 0.95 + 0.03, rim + 0.04])
    save("handprint.png", np.dstack([rgb, np.clip(a * 0.82 + rim * 0.5, 0, 1)]))


def t_map():
    """Схема станции — висит на стене и лежит в блокноте. Север сверху."""
    n = 1024
    base = fft_noise(n, 2.0, 71)
    lum = 0.8 + (base - 0.5) * 0.1
    im = Image.fromarray((np.dstack([lum, lum * 0.95, lum * 0.82]) * 255).astype(np.uint8)).convert("RGB")
    d = ImageDraw.Draw(im)
    ink = (28, 30, 52)
    red = (150, 30, 24)
    f_big = font("bahnschrift.ttf", 38)
    f_mid = font("bahnschrift.ttf", 25)
    f_sm = font("bahnschrift.ttf", 20)

    def P(x, z):
        return (512 + (x + 2.5) * 5.0, 532 + (z + 1.5) * 5.0)
    d.rectangle((14, 14, n - 14, n - 14), outline=ink, width=3)
    d.text((40, 940), "СТ. «ТИХАЯ». СХЕМА ЛЕЕРОВ", font=f_big, fill=ink)
    d.text((40, 984), "о. Немой, 1986 г.   В пургу — только по лееру", font=f_sm, fill=ink)
    lines = {"А": [(7.6, 1.6), (7.6, -4.6), (26.0, -49.3)], "Б": [(7.6, 1.6), (29.3, 1.6)],
             "В": [(29.3, 1.6), (29.3, 5.2), (35.3, 5.2), (77.6, 21.4)], "Г": [(7.6, 5.4), (-6.5, 5.4), (-77.5, 13.5)],
             "Д": [(7.6, 1.6), (7.6, 5.4), (11.6, 78.4)]}
    for k, pts in lines.items():
        d.line([P(*p) for p in pts], fill=red, width=4)
    # старый леер — пунктиром
    a, b2 = (19.4, -56.0), (-44.4, -87.2)
    for i in range(0, 20, 2):
        p0 = (a[0] + (b2[0] - a[0]) * i / 20, a[1] + (b2[1] - a[1]) * i / 20)
        p1 = (a[0] + (b2[0] - a[0]) * (i + 1) / 20, a[1] + (b2[1] - a[1]) * (i + 1) / 20)
        d.line([P(*p0), P(*p1)], fill=red, width=3)

    def rect(x0, z0, x1, z1, fill=None):
        d.rectangle((*P(x0, z0), *P(x1, z1)), outline=ink, width=3, fill=fill)
    rect(-5, -3.2, 5, 3.2, (200, 190, 160))
    rect(30, -1, 34.4, 4.2, (200, 190, 160))
    rect(20, -62, 32, -50)
    rect(77.5, 20, 82.5, 24, (200, 190, 160))
    rect(-80.6, 12.3, -78.2, 14.7, (200, 190, 160))
    rect(-50.5, -91, -45.5, -88, (200, 190, 160))
    cx, cy = P(12, 86)
    d.ellipse((cx - 36, cy - 36, cx + 36, cy + 36), outline=ink, width=3)
    mx, my = P(-83, 13.5)
    d.polygon([(mx, my - 16), (mx - 12, my + 10), (mx + 12, my + 10)], outline=ink, width=3)
    labels = [("ДОМ", -4, -10.5), ("ДИЗЕЛЬНАЯ", 26, -7.5), ("МЕТЕОПЛОЩАДКА", 12, -70.5), ("СКЛАД ГСМ", 66, 26.5),
              ("МАЧТА", -94, 19), ("ПЛОЩАДКА", 21, 83), ("СТАРАЯ СТ. (1961)", -76, -99)]
    for t, x, z in labels:
        d.text(P(x, z), t, font=f_mid, fill=ink)
    for t, x, z in (("А", 19, -28), ("Б", 17, -3.5), ("В", 55, 8), ("Г", -42, 4), ("Д", 12.5, 42), ("ст.", -18, -77)):
        d.text(P(x, z), t, font=f_mid, fill=red)
    # ветер и стороны света
    wx, wy = 130, 760
    d.line((wx, wy, wx + 90, wy + 90), fill=ink, width=5)
    d.polygon([(wx + 90, wy + 90), (wx + 62, wy + 80), (wx + 80, wy + 62)], fill=ink)
    d.text((wx - 80, wy - 44), "ВЕТЕР: с норд-веста", font=f_sm, fill=ink)
    d.line((900, 150, 900, 250), fill=ink, width=4)
    d.polygon([(900, 130), (888, 162), (912, 162)], fill=ink)
    d.text((891, 96), "С", font=f_mid, fill=ink)
    d.line((760, 950, 860, 950), fill=ink, width=4)
    d.text((772, 916), "20 м", font=f_sm, fill=ink)
    save("map.jpg", im.filter(ImageFilter.GaussianBlur(0.5)))


def t_calendar():
    w, h = 384, 540
    im = Image.new("RGB", (w, h), (214, 206, 180))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w, 96), fill=(120, 30, 26))
    d.text((34, 14), "ЯНВАРЬ", font=font("bahnschrift.ttf", 54), fill=(236, 228, 204))
    d.text((270, 30), "1987", font=font("bahnschrift.ttf", 36), fill=(236, 228, 204))
    f = font("bahnschrift.ttf", 30)
    fs = font("bahnschrift.ttf", 22)
    for i, dn in enumerate(("Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс")):
        d.text((22 + i * 50, 110), dn, font=fs, fill=(150, 30, 24) if i > 4 else (40, 40, 48))
    col, row = 3, 0          # 1 января 1987 — четверг
    for day in range(1, 32):
        x, y = 22 + col * 50, 150 + row * 62
        d.text((x, y), str(day), font=f, fill=(150, 30, 24) if col > 4 else (30, 30, 38))
        if day <= 15:
            d.line((x - 4, y + 2, x + 34, y + 34), fill=(30, 40, 110), width=3)
            d.line((x + 34, y + 2, x - 4, y + 34), fill=(30, 40, 110), width=3)
        if day == 20:
            d.ellipse((x - 8, y - 4, x + 40, y + 40), outline=(150, 30, 24), width=3)
        col += 1
        if col > 6:
            col, row = 0, row + 1
    d.text((22, 478), "20-го — борт", font=font("segoepr.ttf", 26), fill=(30, 40, 110))
    save("calendar.jpg", im.filter(ImageFilter.GaussianBlur(0.4)))


# ---------------------------------------------------------------- значки HUD

def t_icons():
    s = 96

    def canvas():
        im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        return im, ImageDraw.Draw(im)
    W = (255, 255, 255, 255)
    # рука на тросе
    im, d = canvas()
    d.line((4, 30, 92, 22), fill=W, width=5)
    d.rounded_rectangle((30, 14, 66, 62), 14, fill=W)
    d.rounded_rectangle((18, 30, 36, 56), 8, fill=W)
    d.rectangle((38, 58, 60, 92), fill=W)
    d.line((4, 30, 92, 22), fill=(0, 0, 0, 255), width=2)
    save("ico_rope.png", im)
    # фонарь
    im, d = canvas()
    d.polygon([(10, 34), (40, 22), (40, 74), (10, 62)], fill=W)
    d.rectangle((40, 30, 58, 66), fill=W)
    for ang in (-28, 0, 28):
        a = math.radians(ang)
        d.line((64, 48 + math.sin(a) * 6, 64 + math.cos(a) * 26, 48 + math.sin(a) * 30), fill=W, width=4)
    save("ico_lamp.png", im)
    # фальшфейер
    im, d = canvas()
    d.line((30, 88, 56, 36), fill=W, width=10)
    for ang in range(-150, -20, 26):
        a = math.radians(ang)
        d.line((58, 32, 58 + math.cos(a) * 26, 32 + math.sin(a) * 26), fill=W, width=3)
    d.ellipse((50, 24, 66, 40), fill=W)
    save("ico_flare.png", im)
    # снежинка (холод)
    im, d = canvas()
    for k in range(6):
        a = math.radians(k * 60)
        x2, y2 = 48 + math.cos(a) * 38, 48 + math.sin(a) * 38
        d.line((48, 48, x2, y2), fill=W, width=5)
        for side in (-1, 1):
            b = a + side * math.radians(40)
            mx, my = 48 + math.cos(a) * 24, 48 + math.sin(a) * 24
            d.line((mx, my, mx + math.cos(b) * 12, my + math.sin(b) * 12), fill=W, width=4)
    save("ico_cold.png", im)
    # канистра
    im, d = canvas()
    d.rounded_rectangle((22, 26, 74, 88), 6, fill=W)
    d.rectangle((30, 12, 50, 28), fill=W)
    d.line((30, 40, 66, 76), fill=(0, 0, 0, 255), width=4)
    d.line((66, 40, 30, 76), fill=(0, 0, 0, 255), width=4)
    save("ico_can.png", im)
    # дрова
    im, d = canvas()
    for (x, y) in ((30, 62), (56, 62), (43, 40)):
        d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=W)
        d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(0, 0, 0, 255))
    save("ico_wood.png", im)


def t_appicon():
    # значок игры: красный флажок на тросе в темноте
    n = 256
    im = Image.new("RGBA", (n, n), (6, 8, 12, 255))
    d = ImageDraw.Draw(im)
    for i in range(140):
        x, y = R.integers(0, n), R.integers(0, n)
        ln = R.integers(6, 22)
        c = int(R.integers(60, 190))
        d.line((x, y, x + ln, y + ln * 0.25), fill=(c, c, c + 10, 255), width=1)
    d.line((0, 150, 256, 118), fill=(150, 140, 120, 255), width=5)
    d.rectangle((120, 60, 132, 256), fill=(60, 52, 44, 255))
    d.polygon([(132, 132), (214, 150), (206, 184), (132, 176)], fill=(196, 28, 22, 255))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(ROOT, "icon.png"))
    im.save(os.path.join(ROOT, "icon.ico"), sizes=[(256, 256), (64, 64), (48, 48), (32, 32), (16, 16)])
    print("   icon.png, icon.ico")


ALL = {"frost": t_frost, "cookie": t_cookie, "noise": t_noise, "flake": t_flake, "halo": t_halo, "foot": t_foot, "ice": t_ice,
       "paper": t_paper, "cloth": t_cloth, "glass": t_glass, "hand": t_hand, "map": t_map, "calendar": t_calendar, "icons": t_icons, "appicon": t_appicon}

if __name__ == "__main__":
    want = sys.argv[1:] or list(ALL)
    for k in want:
        print(k)
        ALL[k]()
