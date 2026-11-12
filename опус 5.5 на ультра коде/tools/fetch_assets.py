"""Скачивает сторонние ассеты (все CC0 / MIT / OFL) в tex/, mdl/, fonts/.

    python tools/fetch_assets.py            — скачать то, чего нет
    python tools/fetch_assets.py --force    — перекачать всё

Источники и лицензии записываются в CREDITS.txt.
"""
import io
import json
import os
import sys
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORCE = "--force" in sys.argv
UA = {"User-Agent": "Mozilla/5.0 (asset fetch for a hobby game)"}

# имя материала в игре: (источник, id)
TEX = {
    "tile_wall": ("acg", "Tiles141"),
    "tile_broken": ("acg", "Tiles133D"),
    "tile_pool": ("acg", "Tiles133A"),
    "tile_dark": ("acg", "Tiles140"),
    "tile_green": ("acg", "Tiles032"),
    "tile_floor": ("ph", "square_tiles_02"),
    "tile_floor2": ("ph", "brown_floor_tiles"),
    "terracotta": ("ph", "terracotta_floor_tiles"),
    "linoleum": ("ph", "old_linoleum_flooring_01"),
    "paint_green": ("acg", "PaintedPlaster003"),
    "paint_blue": ("acg", "PaintedPlaster002"),
    "plaster": ("ph", "worn_plaster_wall"),
    "plaster_dmg": ("ph", "damaged_plaster"),
    "peeling": ("ph", "peeling_painted_wall"),
    "wallpaper": ("ph", "decrepit_wallpaper"),
    "facade": ("ph", "yellow_plaster"),
    "concrete": ("ph", "concrete_floor_worn_001"),
    "concrete_dirty": ("ph", "dirty_concrete"),
    "brick_dark": ("ph", "dark_brick_wall"),
    "brick_red": ("ph", "red_brick"),
    "planks": ("ph", "old_planks_02"),
    "planks_dark": ("ph", "dark_wooden_planks"),
    "planks_weather": ("ph", "weathered_planks"),
    "logs": ("ph", "wood_trunk_wall"),
    "rust": ("ph", "rusty_metal_02"),
    "metal_green": ("ph", "green_metal_rust"),
    "grate": ("ph", "metal_grate_rusty"),
    "rust_paint": ("ph", "rusty_painted_metal"),
    "snow": ("ph", "snow_02"),
    "terry": ("ph", "terry_cloth"),
    "coal": ("acg", "Gravel024"),
    "cloth": ("acg", "Fabric032"),
}

PH_MODELS = [
    "crowbar_01", "pipe_wrench", "vintage_flashlight", "wooden_bucket_01", "wooden_bucket_02",
    "wooden_stool_01", "wooden_stool_02", "painted_wooden_bench", "painted_wooden_cabinet",
    "painted_wooden_chair_01", "painted_wooden_table", "BarberShopChair_01", "CashRegister_01",
    "wall_clock", "metal_office_desk", "metal_toolbox", "rusted_spade_01", "wooden_broom", "rubber_boots",
    "old_bed_frame", "wooden_candlestick", "vintage_oil_lamp", "vintage_radio_transceiver", "Television_01",
    "hanging_industrial_lamp", "power_box_01", "metal_trash_can",
    "wooden_crate_01", "cardboard_box_01", "rubber_duck_toy", "pot_enamel_01", "metal_jug",
    "standing_picture_frame_01", "wheelchair_01", "vintage_suitcase", "alarm_clock_01", "clipboard",
    "metal_stool_01", "wooden_ladder", "vintage_electric_kettle", "metal_tool_chest",
    "russian_food_cans_01", "cigarette_pack", "desk_lamp_arm_01", "wicker_basket_01",
    "WoodenTable_01", "WoodenChair_01", "wooden_crate_02", "cement_bag", "tea_set_01", "painted_wooden_chair_02",
    "cleaner_tin_01", "painted_wooden_stool",
]

RB = "https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/master/Assets/"
RB_FILES = {
    "mdl/rb/hozyayka/hozyayka.fbx": "Avatars/Adults/Female_Adult_02/Export/Female_Adult_02_facial.fbx",
    "mdl/rb/hozyayka/body_color.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_body_color.tga",
    "mdl/rb/hozyayka/body_normal.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_body_normal.tga",
    "mdl/rb/hozyayka/head_color.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_head_color.tga",
    "mdl/rb/hozyayka/head_normal.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_head_normal.tga",
    "mdl/rb/hozyayka/opacity_color.tga": "Avatars/Adults/Female_Adult_02/Textures/f002_opacity_color.tga",
    "mdl/rb/man/man.fbx": "Avatars/Adults/Male_Adult_01/Export/Male_Adult_01.fbx",
    "mdl/rb/man/body_color.tga": "Avatars/Adults/Male_Adult_01/Textures/m002_body_color.tga",
    "mdl/rb/man/head_color.tga": "Avatars/Adults/Male_Adult_01/Textures/m002_head_color.tga",
    "mdl/rb/anim/walk_injured.fbx": "Animations/all_animations_max_motextr_xy/f_walk_injured.max.fbx",
    "mdl/rb/anim/walk_bruised.fbx": "Animations/all_animations_max_motextr_xy/f_walk_bruised.max.fbx",
    "mdl/rb/anim/walk_drunk.fbx": "Animations/all_animations_max_motextr_xy/f_walk_drunk.max.fbx",
    "mdl/rb/anim/run_injured.fbx": "Animations/all_animations_max_motextr_xy/f_run_injured.max.fbx",
    "mdl/rb/anim/idle_breathe.fbx": "Animations/all_animations_max_motextr_static/f_idle_breathe_01.max.fbx",
    "mdl/rb/anim/look_around.fbx": "Animations/all_animations_max_motextr_static/f_idle_look_around_01.max.fbx",
    "mdl/rb/anim/crouch_idle.fbx": "Animations/all_animations_max_motextr_static/f_crouch_idle.max.fbx",
    "mdl/rb/anim/crouch_in.fbx": "Animations/all_animations_max_motextr_static/f_crouch_in.max.fbx",
    "mdl/rb/anim/m_sit.fbx": "Animations/all_animations_max_motextr_static/m_sit_chair_idle_neutral_01.max.fbx",
}

GF = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
FONTS = {
    "fonts/PTSans-Regular.ttf": "ptsans/PT_Sans-Web-Regular.ttf",
    "fonts/PTSans-Bold.ttf": "ptsans/PT_Sans-Web-Bold.ttf",
    "fonts/PTSansNarrow-Regular.ttf": "ptsansnarrow/PT_Sans-Narrow-Web-Regular.ttf",
    "fonts/PTSansNarrow-Bold.ttf": "ptsansnarrow/PT_Sans-Narrow-Web-Bold.ttf",
    "fonts/PTSerif-Regular.ttf": "ptserif/PT_Serif-Web-Regular.ttf",
    "fonts/PTSerif-Italic.ttf": "ptserif/PT_Serif-Web-Italic.ttf",
    "fonts/PTMono-Regular.ttf": "ptmono/PTM55FT.ttf",
    "fonts/MarckScript-Regular.ttf": "marckscript/MarckScript-Regular.ttf",
    "fonts/Neucha.ttf": "neucha/Neucha.ttf",
    "fonts/Caveat.ttf": "caveat/Caveat%5Bwght%5D.ttf",
    "fonts/RuslanDisplay.ttf": "ruslandisplay/RuslanDisplay-Regular.ttf",
    "fonts/Oswald.ttf": "oswald/Oswald%5Bwght%5D.ttf",
}


def get(url, tries=3):
    last = None
    for _ in range(tries):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()
        except Exception as e:  # noqa: BLE001
            last = e
    raise RuntimeError(f"{url}: {last}")


def save_img(data, path, size=1024, mode=None):
    im = Image.open(io.BytesIO(data))
    if mode:
        im = im.convert(mode)
    elif im.mode not in ("RGB", "L", "RGBA"):
        im = im.convert("RGB")
    if max(im.size) > size:
        im = im.resize((size, size), Image.LANCZOS)
    if path.endswith(".jpg") and im.mode == "RGBA":
        im = im.convert("RGB")
    im.save(path, quality=90)


def tex_job(name, src, aid):
    d = os.path.join(ROOT, "tex", name)
    if os.path.exists(os.path.join(d, "albedo.jpg")) and not FORCE:
        return f"tex {name}: есть"
    os.makedirs(d, exist_ok=True)
    if src == "ph":
        info = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
        for key, out in (("Diffuse", "albedo.jpg"), ("nor_gl", "normal.jpg"), ("Rough", "rough.jpg")):
            if key in info:
                save_img(get(info[key]["1k"]["jpg"]["url"]), os.path.join(d, out))
    else:
        z = zipfile.ZipFile(io.BytesIO(get(f"https://ambientcg.com/get?file={aid}_1K-JPG.zip")))
        for n in z.namelist():
            low = n.lower()
            out = None
            if low.endswith("_color.jpg"):
                out = "albedo.jpg"
            elif low.endswith("_normalgl.jpg"):
                out = "normal.jpg"
            elif low.endswith("_roughness.jpg"):
                out = "rough.jpg"
            if out:
                save_img(z.read(n), os.path.join(d, out))
    return f"tex {name}: {src}:{aid}"


def model_job(aid):
    d = os.path.join(ROOT, "mdl", "ph", aid)
    if os.path.exists(os.path.join(d, aid + ".gltf")) and not FORCE:
        return f"model {aid}: есть"
    os.makedirs(d, exist_ok=True)
    info = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
    g = info["gltf"]["1k"]["gltf"]
    with open(os.path.join(d, aid + ".gltf"), "wb") as f:
        f.write(get(g["url"]))
    for rel, inc in g["include"].items():
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        data = get(inc["url"])
        if rel.endswith(".jpg") or rel.endswith(".png"):
            im = Image.open(io.BytesIO(data))
            if max(im.size) > 512:  # предметы мелкие — хватит 512
                im = im.resize((512, 512), Image.LANCZOS)
            im.save(p, quality=88)
        else:
            with open(p, "wb") as f:
                f.write(data)
    return f"model {aid}"


def rb_job(dst, src):
    p = os.path.join(ROOT, dst)
    if dst.endswith(".tga"):
        p = p[:-4] + ".png"
    if os.path.exists(p) and not FORCE:
        return f"rb {dst}: есть"
    os.makedirs(os.path.dirname(p), exist_ok=True)
    data = get(RB + src)
    if dst.endswith(".tga"):
        save_img(data, p, 1024, "RGBA" if "opacity" in dst else "RGB")
    else:
        with open(p, "wb") as f:
            f.write(data)
    return f"rb {dst}"


def font_job(dst, src):
    p = os.path.join(ROOT, dst)
    if os.path.exists(p) and os.path.getsize(p) > 0 and not FORCE:
        return f"font {dst}: есть"
    os.makedirs(os.path.dirname(p), exist_ok=True)
    data = get(GF + src)
    with open(p, "wb") as f:
        f.write(data)
    return f"font {dst}"


def credits():
    lines = [
        "ТРЕТИЙ ПАР — источники сторонних ассетов", "",
        "Текстуры — ambientCG (ambientcg.com) и Poly Haven (polyhaven.com), лицензия CC0:",
    ]
    for name, (src, aid) in sorted(TEX.items()):
        lines.append(f"  {name}: {'ambientCG' if src == 'acg' else 'Poly Haven'} {aid}")
    lines += ["", "Модели предметов — Poly Haven, CC0:"]
    lines += ["  " + ", ".join(PH_MODELS)]
    lines += ["", "Люди и анимации — Microsoft Rocketbox (github.com/microsoft/Microsoft-Rocketbox), лицензия MIT:",
              "  Female_Adult_02 (основа Хозяйки, сильно изменена), Male_Adult_01, анимации f_walk_injured,",
              "  f_walk_bruised, f_walk_drunk, f_run_injured, f_idle_breathe_01, f_idle_look_around_01,",
              "  f_crouch_idle, f_crouch_in, m_sit_chair_idle_neutral_01.",
              "", "Шрифты — Google Fonts, SIL Open Font License 1.1:",
              "  PT Sans, PT Sans Narrow, PT Serif, PT Mono (ParaType), Marck Script, Neucha, Caveat, Ruslan Display, Oswald.",
              "", "Всё остальное (звук, голоса, таблички, записки, мозаика, волосы, здание) сделано для игры кодом."]
    with open(os.path.join(ROOT, "CREDITS.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    jobs = []
    with ThreadPoolExecutor(6) as ex:
        for name, (src, aid) in TEX.items():
            jobs.append(ex.submit(tex_job, name, src, aid))
        for aid in PH_MODELS:
            jobs.append(ex.submit(model_job, aid))
        for dst, src in RB_FILES.items():
            jobs.append(ex.submit(rb_job, dst, src))
        for dst, src in FONTS.items():
            jobs.append(ex.submit(font_job, dst, src))
        bad = 0
        for j in jobs:
            try:
                print(j.result(), flush=True)
            except Exception as e:  # noqa: BLE001
                bad += 1
                print("ОШИБКА", e, flush=True)
    credits()
    print("готово, ошибок:", bad)


if __name__ == "__main__":
    main()
