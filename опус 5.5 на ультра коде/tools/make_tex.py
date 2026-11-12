"""Свои текстуры: луч фонаря, пар, волосы, кожа Хозяйки, таблички, записки, план, мозаика и т. п.

    python tools/make_tex.py
Записки берутся из src/story/notes.json (тот же текст показывает игра).
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tex", "ui")
GEN = os.path.join(ROOT, "tex", "gen")
F = os.path.join(ROOT, "fonts")
os.makedirs(OUT, exist_ok=True)
os.makedirs(GEN, exist_ok=True)
random.seed(7)
np.random.seed(7)


def font(name, size):
    return ImageFont.truetype(os.path.join(F, name), size)


def noise(w, h, scale=32, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        small = np.random.rand(h // s + 2, w // s + 2).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((w + 2 * s, h + 2 * s), Image.BICUBIC)
        out += np.asarray(im, np.float32)[s:s + h, s:s + w] / 255.0 * amp
        amp *= 0.5
    out -= out.min()
    out /= max(out.max(), 1e-6)
    return out


# ------------------------------------------------------------------ свет и пар

def flash_cookie():
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5) / (n / 2)
    hot = np.exp(-(r / 0.28) ** 2) * 0.55
    body = np.clip(1.0 - (r / 0.95) ** 3, 0, 1) * 0.6
    ring = np.exp(-((r - 0.62) / 0.05) ** 2) * 0.12
    halo = np.clip(1 - r, 0, 1) ** 0.5 * 0.08
    v = np.clip(hot + body + ring + halo, 0, 1)
    v *= 0.92 + noise(n, n, 24, 3) * 0.08
    v[r > 1.0] = 0
    Image.fromarray((v * 255).astype(np.uint8)).convert("RGB").save(os.path.join(OUT, "flash_cookie.png"))


def steam_puff():
    n = 128
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    a = np.clip(1 - r, 0, 1) ** 1.6 * (0.55 + 0.45 * noise(n, n, 20, 4))
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = 235
    img[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, "steam_puff.png"))


def hair_strands():
    """Текстура прядей: много тонких волос с альфой, мокрый блеск по центру."""
    w, h = 256, 1024
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(420):
        x0 = random.uniform(0, w)
        drift = random.uniform(-18, 18)
        thick = random.choice([1, 1, 1, 2, 2, 3])
        c = random.randint(4, 22)
        alpha = random.randint(150, 255)
        end = random.uniform(0.75, 1.0) * h
        pts = []
        for k in range(24):
            t = k / 23
            pts.append((x0 + drift * t + math.sin(t * 6 + i) * 3, t * end))
        d.line(pts, fill=(c, c, c + 2, alpha), width=thick)
    arr = np.asarray(img).astype(np.float32)
    # блики (мокрые)
    for i in range(70):
        x0 = int(random.uniform(0, w))
        y0 = int(random.uniform(0, h * 0.9))
        ln = int(random.uniform(20, 120))
        arr[y0:y0 + ln, x0:x0 + 1, :3] = np.maximum(arr[y0:y0 + ln, x0:x0 + 1, :3], 70)
    Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "hair.png"))


def skin():
    """Кожа Хозяйки из текстур Rocketbox: серая, мокрая, с венами; лицо — бельма и тёмные глазницы."""
    src = os.path.join(ROOT, "mdl", "rb", "hozyayka")
    body = Image.open(os.path.join(src, "body_color.png")).convert("RGB")
    head = Image.open(os.path.join(src, "head_color.png")).convert("RGB")

    def grey(im, tint=(0.62, 0.64, 0.6), dark=0.62):
        a = np.asarray(im).astype(np.float32) / 255.0
        lum = a @ np.array([0.3, 0.55, 0.15], np.float32)
        lum = lum ** 1.15
        n = noise(im.width, im.height, 64, 5)
        veins = noise(im.width, im.height, 8, 3)
        veins = np.clip((np.abs(veins - 0.5) < 0.035).astype(np.float32) * 0.5, 0, 1)
        out = np.stack([lum * tint[0], lum * tint[1], lum * tint[2]], -1)
        out *= (0.75 + n[..., None] * 0.35) * dark
        out[..., 0] -= veins * 0.10
        out[..., 1] -= veins * 0.06
        out[..., 2] += veins * 0.02
        # пятна грязи / синяков
        blot = noise(im.width, im.height, 128, 3)
        out *= (1 - np.clip(blot - 0.62, 0, 1)[..., None] * 1.6)
        return np.clip(out, 0, 1)

    b = grey(body)
    # одежда (свитер, блузка, бусы, юбка) → застиранная серая сорочка: размыть детали, наложить грязь
    W0 = body.width
    sx = W0 / 512.0
    cloth = np.asarray(Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9 * sx))).astype(np.float32) / 255.0
    mask = np.zeros((body.height, body.width), np.float32)
    mm = Image.new("L", body.size, 0)
    dm = ImageDraw.Draw(mm)
    dm.rectangle([150 * sx, 0, 362 * sx, 400 * sx], fill=255)        # торс
    dm.rectangle([30 * sx, 150 * sx, 482 * sx, 235 * sx], fill=255)  # рукава
    dm.rectangle([20 * sx, 270 * sx, 492 * sx, 390 * sx], fill=255)  # юбка
    mask = np.asarray(mm.filter(ImageFilter.GaussianBlur(6 * sx))).astype(np.float32) / 255.0
    dirt = noise(body.width, body.height, 48, 5)
    cl = cloth.mean(-1, keepdims=True) * np.array([0.55, 0.52, 0.47]) * (0.7 + dirt[..., None] * 0.5)
    b = b * (1 - mask[..., None]) + cl * mask[..., None]
    Image.fromarray((b * 255).astype(np.uint8)).save(os.path.join(GEN, "hoz_body.png"))
    hh = grey(head, (0.66, 0.66, 0.62), 0.7)
    src_a = np.asarray(head).astype(np.float32)
    bright = src_a.mean(-1)
    sat = src_a.max(-1) - src_a.min(-1)
    hairmask = ((bright < 120) & (sat < 70)).astype(np.float32)
    hairmask = np.asarray(Image.fromarray((hairmask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255.0
    hh = hh * (1 - hairmask[..., None]) + np.array([0.035, 0.03, 0.03])[None, None, :] * hairmask[..., None]
    W = head.width
    img = Image.fromarray((hh * 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    s = W / 512.0
    # глазницы (по развёртке Rocketbox: глаза около (221,145) и (291,145) при 512)
    for cx in (221, 291):
        for rr, a in ((40, 70), (30, 130), (20, 200)):
            d.ellipse([(cx - rr) * s, (145 - rr * 0.7) * s, (cx + rr) * s, (145 + rr * 0.7) * s], fill=(10, 8, 8, a))
    # рот — тёмная щель, уголки вниз
    d.polygon([(232 * s, 207 * s), (256 * s, 212 * s), (280 * s, 207 * s), (276 * s, 216 * s), (256 * s, 221 * s), (236 * s, 216 * s)], fill=(20, 8, 8, 220))
    # трупные пятна, трещинки на губах, тёмные потёки от глаз
    for _ in range(26):
        cx, cy = random.uniform(150, 360), random.uniform(60, 260)
        r = random.uniform(6, 22)
        d.ellipse([(cx - r) * s, (cy - r * 0.7) * s, (cx + r) * s, (cy + r * 0.7) * s], fill=(40, 45, 42, random.randint(25, 60)))
    for cx in (221, 291):
        for k in range(3):
            x0 = cx + random.uniform(-8, 8)
            d.line([(x0 * s, 155 * s), ((x0 + random.uniform(-4, 4)) * s, random.uniform(185, 230) * s)], fill=(15, 12, 12, 120), width=int(3 * s))
    img = img.filter(ImageFilter.GaussianBlur(1.2 * s))
    # глазное яблоко (кусок развёртки внизу слева) — бельмо
    eye = Image.new("RGBA", img.size, (0, 0, 0, 0))
    de = ImageDraw.Draw(eye)
    de.ellipse([100 * s, 432 * s, 170 * s, 500 * s], fill=(205, 210, 200, 255))
    de.ellipse([122 * s, 452 * s, 148 * s, 478 * s], fill=(170, 178, 170, 255))
    img = Image.alpha_composite(img.convert("RGBA"), eye.filter(ImageFilter.GaussianBlur(3 * s))).convert("RGB")
    img.save(os.path.join(GEN, "hoz_head.png"))
    # мужчина под простынёй — просто белёсая ткань
    cloth = np.ones((256, 256, 3), np.float32) * 0.82
    cloth *= (0.85 + noise(256, 256, 32, 4)[..., None] * 0.2)
    stain = noise(256, 256, 64, 3)
    cloth[..., 1] -= np.clip(stain - 0.6, 0, 1) * 0.5
    cloth[..., 2] -= np.clip(stain - 0.6, 0, 1) * 0.7
    Image.fromarray((cloth.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(GEN, "sheet.png"))


# ------------------------------------------------------------------ бумага и надписи

def paper(w, h, tone=(226, 218, 196), age=0.5, seed=0):
    rnd = np.random.RandomState(seed)
    n = noise(w, h, 48, 5)
    base = np.array(tone, np.float32)[None, None, :] * (0.9 + n[..., None] * 0.12)
    # пятна сырости
    blot = noise(w, h, 160, 3)
    base *= (1 - np.clip(blot - (0.7 - age * 0.2), 0, 1)[..., None] * np.array([0.3, 0.45, 0.8]))
    # края темнее
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(x, w - x), np.minimum(y, h - y)) / (min(w, h) * 0.12)
    base *= (0.75 + 0.25 * np.clip(edge, 0, 1))[..., None]
    return Image.fromarray(base.clip(0, 255).astype(np.uint8))


def wrap(text, fnt, width, draw):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        cur = ""
        for wd in words:
            t = (cur + " " + wd).strip()
            if draw.textlength(t, font=fnt) <= width:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = wd
        lines.append(cur)
    return lines


def text_block(img, text, fnt, x, y, width, fill, spacing=1.25, jitter=0.0):
    d = ImageDraw.Draw(img)
    lh = int(fnt.size * spacing)
    for ln in wrap(text, fnt, width, d):
        dx = random.uniform(-jitter, jitter)
        d.text((x + dx, y), ln, font=fnt, fill=fill)
        y += lh
    return y


def notes_textures():
    path = os.path.join(ROOT, "src", "story", "notes.json")
    if not os.path.exists(path):
        print("нет notes.json — записки пропущены")
        return
    notes = json.load(open(path, encoding="utf-8"))
    for nid, n in notes.items():
        kind = n.get("look", "paper")
        W, H = (512, 680)
        if kind == "typed":
            img = paper(W, H, (232, 226, 210), 0.5, hash(nid) % 1000)
            y = 40
            y = text_block(img, n["title"].upper(), font("PTMono-Regular.ttf", 22), 40, y, W - 80, (40, 35, 35))
            text_block(img, n["text"], font("PTMono-Regular.ttf", 17), 40, y + 16, W - 80, (45, 40, 40), 1.3)
        elif kind == "news":
            img = paper(W, H, (214, 206, 182), 0.8, hash(nid) % 1000)
            d = ImageDraw.Draw(img)
            d.text((30, 26), n.get("paper", "ЧЕРНОРЕЧЕНСКАЯ ПРАВДА"), font=font("PTSerif-Regular.ttf", 26), fill=(30, 28, 28))
            d.line((30, 64, W - 30, 64), fill=(40, 40, 40), width=2)
            y = text_block(img, n["title"], font("PTSans-Bold.ttf", 30), 30, 80, W - 60, (25, 22, 22), 1.1)
            text_block(img, n["text"], font("PTSerif-Regular.ttf", 18), 30, y + 14, W - 60, (40, 36, 34), 1.3)
        elif kind == "board":
            continue
        else:
            img = paper(W, H, (222, 214, 190) if kind != "cardboard" else (170, 140, 100), 0.6, hash(nid) % 1000)
            if kind == "notebook":
                d = ImageDraw.Draw(img)
                for yy in range(60, H, 28):
                    d.line((20, yy, W - 20, yy), fill=(150, 160, 190), width=1)
                d.line((60, 0, 60, H), fill=(200, 120, 120), width=2)
            fnt = font("Caveat.ttf", 30) if kind != "cardboard" else font("Neucha.ttf", 26)
            y = text_block(img, n["title"], fnt, 70 if kind == "notebook" else 34, 28, W - 90, (30, 30, 60), 1.05, 1.0)
            text_block(img, n["text"], fnt, 70 if kind == "notebook" else 34, y + 6, W - 100, (25, 25, 55) if kind != "cardboard" else (20, 15, 10), 1.0, 1.5)
        img.save(os.path.join(GEN, "note_" + nid + ".png"))


def rules_board():
    path = os.path.join(ROOT, "src", "story", "notes.json")
    notes = json.load(open(path, encoding="utf-8"))
    n = notes["rules"]
    W, H = 768, 1024
    img = paper(W, H, (225, 222, 205), 0.6, 3)
    d = ImageDraw.Draw(img)
    d.rectangle((14, 14, W - 14, H - 14), outline=(120, 30, 30), width=6)
    y = 40
    for ln in ["ПРАВИЛА", "ПОЛЬЗОВАНИЯ ГОРОДСКОЙ БАНЕЙ № 3"]:
        f = font("PTSans-Bold.ttf", 46 if ln == "ПРАВИЛА" else 30)
        tw = d.textlength(ln, font=f)
        d.text(((W - tw) / 2, y), ln, font=f, fill=(140, 25, 25))
        y += 56 if ln == "ПРАВИЛА" else 50
    printed, hand = n["text"].split("\n\n", 1) if "\n\n" in n["text"] else (n["text"], "")
    printed = printed.replace("ПРАВИЛА ПОЛЬЗОВАНИЯ ГОРОДСКОЙ БАНЕЙ № 3\n", "")
    y = text_block(img, printed, font("PTSans-Regular.ttf", 25), 50, y + 10, W - 100, (30, 30, 30), 1.3)
    # карандашные приписки
    pen = Image.new("RGBA", img.size, (0, 0, 0, 0))
    text_block(pen, hand, font("Caveat.ttf", 36), 60, y + 20, W - 110, (55, 55, 70, 235), 1.0, 2.0)
    pen = pen.rotate(-1.2, resample=Image.BICUBIC)
    img = Image.alpha_composite(img.convert("RGBA"), pen).convert("RGB")
    img.save(os.path.join(GEN, "rules.png"))


def price_list():
    W, H = 512, 640
    img = Image.new("RGB", (W, H), (22, 30, 26))
    d = ImageDraw.Draw(img)
    d.text((40, 30), "ПРЕЙСКУРАНТ", font=font("PTSans-Bold.ttf", 44), fill=(225, 220, 200))
    rows = [("Мытьё, общее отделение", "20 р."), ("Мытьё с парильней", "35 р."), ("Детский билет", "10 р."),
            ("Простыня", "10 р."), ("Веник берёзовый", "50 р."), ("Веник дубовый", "70 р."), ("Мыло", "8 р."),
            ("Мочалка", "15 р."), ("Стрижка", "60 р.")]
    y = 120
    for a, b in rows:
        d.text((40, y), a, font=font("PTSansNarrow-Regular.ttf", 30), fill=(215, 210, 190))
        tw = d.textlength(b, font=font("PTSansNarrow-Bold.ttf", 30))
        d.text((W - 40 - tw, y), b, font=font("PTSansNarrow-Bold.ttf", 30), fill=(215, 210, 190))
        y += 48
    d.text((40, H - 70), "Цены с 01.03.2004", font=font("PTSansNarrow-Regular.ttf", 24), fill=(160, 160, 150))
    n = noise(W, H, 40, 4)
    a = np.asarray(img).astype(np.float32) * (0.8 + 0.25 * n[..., None])
    Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(os.path.join(GEN, "prices.png"))


def sign(name, text, w=1024, h=256, bg=(230, 225, 210), fg=(30, 30, 30), fnt="PTSans-Bold.ttf", size=120, age=0.6):
    img = paper(w, h, bg, age, hash(name) % 999)
    d = ImageDraw.Draw(img)
    f = font(fnt, size)
    lines = text.split("\n")
    total = len(lines) * size * 1.1
    y = (h - total) / 2
    for ln in lines:
        tw = d.textlength(ln, font=f)
        d.text(((w - tw) / 2, y), ln, font=f, fill=fg)
        y += size * 1.1
    img.save(os.path.join(GEN, "sign_" + name + ".png"))


def signs():
    sign("bani", "БАНИ", 1024, 256, (40, 34, 30), (205, 190, 160), "Oswald.ttf", 190, 0.9)
    sign("no3", "№ 3", 256, 256, (40, 34, 30), (205, 190, 160), "Oswald.ttf", 140, 0.9)
    sign("kassa", "КАССА", 512, 160, (200, 205, 200), (30, 60, 40), "PTSans-Bold.ttf", 90)
    sign("male", "МУЖСКОЕ\nОТДЕЛЕНИЕ", 512, 256, (200, 205, 210), (25, 40, 90), "PTSans-Bold.ttf", 70)
    sign("female", "ЖЕНСКОЕ\nОТДЕЛЕНИЕ", 512, 256, (210, 200, 205), (110, 25, 40), "PTSans-Bold.ttf", 70)
    sign("parilnya", "ПАРИЛЬНЯ", 512, 140, (90, 60, 40), (225, 200, 160), "PTSans-Bold.ttf", 80)
    sign("staff", "ПОСТОРОННИМ\nВХОД ВОСПРЕЩЁН", 512, 256, (210, 210, 205), (150, 20, 20), "PTSans-Bold.ttf", 58)
    sign("pump", "НАСОСНАЯ", 512, 140, (210, 210, 205), (30, 30, 30), "PTSans-Bold.ttf", 80)
    sign("garderob", "ГАРДЕРОБ", 512, 140, (200, 205, 200), (30, 60, 40), "PTSans-Bold.ttf", 80)
    sign("bufet", "БУФЕТ", 512, 140, (200, 205, 200), (30, 60, 40), "PTSans-Bold.ttf", 80)
    sign("closed", "БАНЯ ЗАКРЫТА\nНА РЕМОНТ\nс 22.12.2004", 512, 400, (235, 232, 220), (30, 30, 30), "PTSansNarrow-Bold.ttf", 66)
    sign("vvod", "ЗАДВИЖКА № 1\nВВОД", 512, 256, (200, 40, 30), (240, 235, 220), "PTSans-Bold.ttf", 70)
    sign("wet", "ОСТОРОЖНО!\nСКОЛЬЗКИЙ ПОЛ", 512, 256, (230, 210, 60), (20, 20, 20), "PTSans-Bold.ttf", 60)
    sign("exit", "ВЫХОД", 512, 160, (30, 110, 50), (230, 250, 230), "PTSans-Bold.ttf", 100, 0.2)
    sign("rules_short", "МЫТЬСЯ ПОСЛЕ\n22:00 ЗАПРЕЩЕНО", 512, 256, (225, 222, 205), (120, 20, 20), "PTSans-Bold.ttf", 60)
    sign("wash_feet", "ПОЛЬЗУЙТЕСЬ\nРЕЗИНОВЫМИ ТАПОЧКАМИ", 512, 256, (220, 225, 215), (30, 60, 40), "PTSansNarrow-Bold.ttf", 54)
    sign("water_save", "БЕРЕГИ\nВОДУ!", 512, 300, (40, 90, 150), (240, 240, 230), "Oswald.ttf", 110)
    sign("sauna_lux", "САУНА «ЛЮКС»\nс 22.00 — по записи", 512, 256, (60, 20, 20), (230, 190, 120), "PTSans-Bold.ttf", 54)
    sign("tech", "ТЕХНИЧЕСКИЙ\nКОРИДОР", 512, 256, (210, 210, 205), (30, 30, 30), "PTSans-Bold.ttf", 70)
    sign("kotelnaya", "КОТЕЛЬНАЯ", 512, 140, (200, 200, 195), (30, 30, 30), "PTSans-Bold.ttf", 80)


def honor_board():
    """Доска почёта: фото отца."""
    W, H = 400, 520
    img = paper(W, H, (200, 190, 170), 0.7, 11)
    d = ImageDraw.Draw(img)
    # фото — силуэт мужчины в кепке, сепия
    ph = Image.new("RGB", (300, 360), (120, 105, 85))
    pd = ImageDraw.Draw(ph)
    pd.rectangle((0, 0, 300, 360), fill=(140, 125, 100))
    pd.ellipse((95, 70, 205, 200), fill=(70, 58, 48))
    pd.rectangle((80, 40, 220, 95), fill=(40, 34, 30))
    pd.ellipse((70, 70, 230, 100), fill=(40, 34, 30))
    pd.polygon([(40, 360), (70, 230), (150, 205), (230, 230), (260, 360)], fill=(55, 48, 40))
    pd.ellipse((122, 120, 138, 130), fill=(30, 25, 22))
    pd.ellipse((162, 120, 178, 130), fill=(30, 25, 22))
    pd.line((130, 170, 170, 172), fill=(35, 28, 24), width=3)
    ph = ph.filter(ImageFilter.GaussianBlur(2.2))
    a = np.asarray(ph).astype(np.float32) * (0.8 + 0.3 * noise(300, 360, 30, 4)[..., None])
    ph = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    img.paste(ph, (50, 30))
    f = font("PTSansNarrow-Bold.ttf", 26)
    for i, ln in enumerate(["КОВАЛЁВ", "Николай Андреевич", "истопник, 1998"]):
        tw = d.textlength(ln, font=f)
        d.text(((W - tw) / 2, 405 + i * 32), ln, font=f, fill=(35, 30, 28))
    img.save(os.path.join(GEN, "honor_father.png"))
    # остальные фото доски — размытые лица
    for k in range(3):
        img = paper(W, H, (200, 190, 170), 0.7, 20 + k)
        d = ImageDraw.Draw(img)
        ph = Image.new("RGB", (300, 360), (130 + k * 8, 118, 96))
        pd = ImageDraw.Draw(ph)
        pd.ellipse((100, 60, 200, 190), fill=(80, 68, 58))
        pd.polygon([(40, 360), (80, 220), (150, 200), (220, 220), (260, 360)], fill=(60, 52, 46))
        ph = ph.filter(ImageFilter.GaussianBlur(3))
        img.paste(ph, (50, 30))
        names = [["СОМОВА", "Анна Петровна", "банщица"], ["ЧЕРНОВА", "Раиса Семёновна", "заведующая"], ["ЛАПТЕВ", "Иван Ильич", "кассир"]][k]
        for i, ln in enumerate(names):
            tw = d.textlength(ln, font=f)
            d.text(((W - tw) / 2, 405 + i * 32), ln, font=f, fill=(35, 30, 28))
        img.save(os.path.join(GEN, "honor_%d.png" % k))


def evac_plan():
    """План эвакуации — тот же план, что в Layout (упрощённо)."""
    W, H = 1040, 640
    img = paper(W, H, (236, 236, 228), 0.3, 5)
    d = ImageDraw.Draw(img)
    d.text((30, 18), "ПЛАН ЭВАКУАЦИИ ПРИ ПОЖАРЕ. 1 ЭТАЖ", font=font("PTSans-Bold.ttf", 30), fill=(170, 20, 20))
    sx, sz, ox, oz = 18.5, 18.5, 40, 70
    rooms = {
        "Вестибюль": (14, 23, 38, 30), "Коридор": (16, 20, 36, 23), "Кабинет": (16, 17, 22, 20), "Бельевая": (22, 17, 27, 20),
        "Парикм.": (27, 17, 32, 20), "Буфет": (32, 17, 36, 20), "Ожид.": (0, 20, 4, 26), "Подс.": (0, 26, 4, 30),
        "Раздевальня М": (4, 20, 14, 30), "Мыльная М": (0, 9, 14, 20), "Парильня М": (0, 3, 8, 9), "Душ М": (8, 3, 14, 9),
        "Бассейн": (14, 6, 38, 17), "Насосная": (30, 3, 38, 6), "Лестн.": (23, 3, 28, 6), "Технический коридор": (0, 0, 52, 3),
        "Раздевальня Ж": (38, 20, 48, 30), "Суш.": (48, 20, 52, 24), "Банщица": (48, 24, 52, 30), "Мыльная Ж": (38, 9, 52, 20),
        "Парильня Ж": (44, 3, 52, 9), "Душ Ж": (38, 3, 44, 9),
    }
    f = font("PTSansNarrow-Regular.ttf", 17)
    for name, (x0, z0, x1, z1) in rooms.items():
        box = (ox + x0 * sx, oz + z0 * sz, ox + x1 * sx, oz + z1 * sz)
        d.rectangle(box, outline=(30, 30, 30), width=3, fill=(250, 250, 244) if name != "Бассейн" else (215, 232, 240))
        tw = d.textlength(name, font=f)
        d.text(((box[0] + box[2] - tw) / 2, (box[1] + box[3]) / 2 - 9), name, font=f, fill=(40, 40, 40))
    # чаша бассейна
    d.rectangle((ox + 19 * sx, oz + 8.5 * sz, ox + 33 * sx, oz + 14.5 * sz), outline=(60, 100, 140), width=2, fill=(170, 205, 225))
    # стрелки эвакуации
    for (a, b) in [((26, 21.5), (26, 29.5)), ((9, 15), (9, 26)), ((45, 15), (45, 26)), ((26, 12), (26, 21))]:
        d.line((ox + a[0] * sx, oz + a[1] * sz, ox + b[0] * sx, oz + b[1] * sz), fill=(40, 150, 60), width=5)
        d.polygon([(ox + b[0] * sx - 9, oz + b[1] * sz - 12), (ox + b[0] * sx + 9, oz + b[1] * sz - 12), (ox + b[0] * sx, oz + b[1] * sz + 4)], fill=(40, 150, 60))
    d.ellipse((ox + 24 * sx, oz + 27 * sz, ox + 25 * sx, oz + 28 * sz), fill=(220, 30, 30))
    d.text((ox + 25.3 * sx, oz + 27 * sz), "Вы здесь", font=f, fill=(200, 20, 20))
    d.text((40, H - 32), "Котельная — в подвале, вход из технического коридора. Ответственный: истопник Ковалёв Н.А.", font=f, fill=(50, 50, 50))
    img.save(os.path.join(GEN, "evac_plan.png"))


def mosaic():
    """Советская мозаика у бассейна: пловчиха, солнце, волны; со временем выпала часть смальты."""
    W, H = 1024, 512
    img = Image.new("RGB", (W, H), (60, 120, 150))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, H * 0.45), fill=(230, 200, 120))
    d.ellipse((700, 40, 900, 240), fill=(240, 150, 60))
    for i in range(12):
        a = i * math.pi / 6
        d.line((800, 140, 800 + math.cos(a) * 170, 140 + math.sin(a) * 170), fill=(240, 170, 80), width=10)
    for k in range(6):
        y = 250 + k * 40
        pts = [(x, y + math.sin(x / 60 + k) * 12) for x in range(0, W + 20, 20)]
        d.line(pts, fill=(40 + k * 6, 100, 140 + k * 8), width=14)
    # пловчиха
    d.ellipse((300, 220, 350, 270), fill=(230, 180, 150))
    d.polygon([(340, 250), (520, 270), (510, 300), (330, 280)], fill=(200, 40, 40))
    d.line((350, 240, 250, 190), fill=(230, 180, 150), width=18)
    d.line((500, 290, 620, 300), fill=(230, 180, 150), width=18)
    d.line((500, 285, 600, 330), fill=(230, 180, 150), width=18)
    d.text((40, 30), "ЗДОРОВЬЕ НАРОДА — БОГАТСТВО СТРАНЫ", font=font("Oswald.ttf", 46), fill=(150, 30, 30))
    # смальта: сетка квадратиков, часть выпала
    a = np.asarray(img).astype(np.float32)
    t = 16
    out = a.copy()
    for yy in range(0, H, t):
        for xx in range(0, W, t):
            c = a[yy:yy + t, xx:xx + t].mean((0, 1)) * random.uniform(0.85, 1.12)
            if random.random() < 0.07 + (0.25 if (xx > 280 and xx < 380 and yy < 300 and yy > 200) else 0):
                c = np.array([70, 66, 60]) * random.uniform(0.6, 1.0)
            out[yy:yy + t, xx:xx + t] = c
            out[yy:yy + t, xx:xx + 1] *= 0.6
            out[yy:yy + 1, xx:xx + t] *= 0.6
    # лицо пловчихи замазано чем-то чёрным
    img = Image.fromarray(out.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(40):
        d.line((random.uniform(290, 360), random.uniform(200, 300), random.uniform(290, 360), random.uniform(260, 420)), fill=(10, 10, 10, 160), width=random.randint(2, 6))
    img.save(os.path.join(GEN, "mosaic.png"))


def child_drawing():
    W, H = 512, 400
    img = paper(W, H, (235, 232, 222), 0.4, 9)
    d = ImageDraw.Draw(img)
    # папа с ведром
    d.ellipse((90, 120, 140, 170), outline=(30, 60, 180), width=4)
    d.line((115, 170, 115, 270), fill=(30, 60, 180), width=4)
    d.line((115, 200, 80, 240), fill=(30, 60, 180), width=4)
    d.line((115, 200, 150, 230), fill=(30, 60, 180), width=4)
    d.line((115, 270, 90, 330), fill=(30, 60, 180), width=4)
    d.line((115, 270, 140, 330), fill=(30, 60, 180), width=4)
    d.rectangle((145, 225, 175, 255), outline=(150, 150, 150), width=3)
    # тётя: высокая, волосы до земли, очень длинные руки
    d.ellipse((300, 30, 350, 80), outline=(20, 20, 20), width=4)
    for i in range(38):
        x = 296 + i * 1.6
        d.line((x, 40, x + random.uniform(-25, 25), 370), fill=(15, 15, 15), width=2)
    d.line((310, 120, 220, 330), fill=(15, 15, 15), width=3)
    d.line((340, 120, 440, 330), fill=(15, 15, 15), width=3)
    for i in range(5):
        d.line((220, 330, 205 + i * 7, 352), fill=(15, 15, 15), width=2)
        d.line((440, 330, 430 + i * 7, 352), fill=(15, 15, 15), width=2)
    d.text((40, 20), "ПАПА И ТЁТЯ ХОЗЯЙКА", font=font("Neucha.ttf", 34), fill=(200, 40, 40))
    d.text((360, 360), "АНДРЕЙ 6 ЛЕТ", font=font("Neucha.ttf", 22), fill=(40, 120, 40))
    img.save(os.path.join(GEN, "child_drawing.png"))


def mirror_code():
    """Код на зеркале — виден только в пару (альфа)."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font("Caveat.ttf", 170)
    d.text((70, 130), "21·12", font=f, fill=(255, 255, 255, 230))
    d.text((90, 330), "техн.", font=font("Caveat.ttf", 70), fill=(255, 255, 255, 200))
    img = img.filter(ImageFilter.GaussianBlur(2))
    img.save(os.path.join(GEN, "mirror_code.png"))
    # «помыться» — надпись в пару в женской раздевалке
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((40, 150), "ЧИСТЕНЬКИЙ", font=font("Caveat.ttf", 110), fill=(255, 255, 255, 230))
    img.filter(ImageFilter.GaussianBlur(2)).save(os.path.join(GEN, "mirror_word.png"))


def old_photo():
    W, H = 512, 360
    img = Image.new("RGB", (W, H), (150, 130, 100))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 220, W, H), fill=(120, 105, 80))
    d.polygon([(150, 220), (150, 120), (260, 70), (370, 120), (370, 220)], fill=(60, 50, 40))
    for y in range(125, 220, 12):
        d.line((150, y, 370, y), fill=(45, 38, 30), width=3)
    d.rectangle((240, 160, 275, 220), fill=(25, 20, 18))
    for i, x in enumerate([90, 115, 400, 425, 450]):
        d.ellipse((x, 160, x + 18, 180), fill=(50, 42, 35))
        d.rectangle((x - 2, 180, x + 20, 230), fill=(55, 46, 38))
    # фигура в дверях — едва различима
    d.rectangle((250, 168, 262, 220), fill=(70, 62, 55))
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(img).astype(np.float32) * (0.75 + 0.35 * noise(W, H, 20, 4)[..., None])
    img = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    img = ImageOps.expand(img, 18, (225, 215, 190))
    ImageDraw.Draw(img).text((24, H + 14), "Баня Пряхиных у реки. 1903 г.", font=font("Caveat.ttf", 22), fill=(60, 50, 60))
    img.save(os.path.join(GEN, "old_photo.png"))


def calendar():
    W, H = 400, 560
    img = paper(W, H, (235, 232, 222), 0.5, 13)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, 170), fill=(150, 40, 40))
    d.text((30, 30), "2004", font=font("Oswald.ttf", 90), fill=(240, 230, 210))
    d.text((30, 190), "ДЕКАБРЬ", font=font("PTSans-Bold.ttf", 40), fill=(40, 40, 40))
    f = font("PTSansNarrow-Regular.ttf", 28)
    day = 1
    for row in range(5):
        for col in range(7):
            n = row * 7 + col - 1
            if 0 <= n < 31:
                x, y = 30 + col * 50, 260 + row * 52
                d.text((x, y), str(n + 1), font=f, fill=(40, 40, 40) if col < 5 else (170, 30, 30))
                if n + 1 <= 21:
                    d.line((x - 4, y + 4, x + 30, y + 30), fill=(60, 60, 90), width=2)
                if n + 1 == 22:
                    d.ellipse((x - 10, y - 6, x + 40, y + 40), outline=(170, 30, 30), width=3)
    img.save(os.path.join(GEN, "calendar.png"))


if __name__ == "__main__":
    flash_cookie()
    steam_puff()
    hair_strands()
    skin()
    signs()
    price_list()
    honor_board()
    evac_plan()
    mosaic()
    child_drawing()
    mirror_code()
    old_photo()
    calendar()
    notes_textures()
    rules_board()
    print("текстуры готовы")
