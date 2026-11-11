"""Скачивает CC0-текстуры и модели с Poly Haven (polyhaven.com) под короткими именами.

    python tools/fetch_assets.py            всё, чего ещё нет
    python tools/fetch_assets.py tex        только текстуры
    python tools/fetch_assets.py mdl radio  только модели с этими короткими именами

Текстуры → tex/<имя>_d.jpg (цвет), _n.jpg (нормали), _r.jpg (шероховатость), всё 1k.
Модели   → mdl/<имя>/m.gltf + m.bin + d.jpg/n.jpg/a.jpg. Короткие имена нужны из-за длинных путей Windows.
Если модель уже лежит в соседнем проекте (Downloads/бекрумс/models), берём её оттуда, а не из сети.
"""
import json, os, shutil, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "tex")
MDL = os.path.join(ROOT, "mdl")
LOCAL = os.path.expandvars(r"%USERPROFILE%\Downloads\бекрумс\models")
UA = {"User-Agent": "leer-game-build/1.0"}
RES = "1k"

TEXTURES = {
    "snow": "snow_02", "snowcrust": "snow_01",
    "sidegreen": "green_rough_planks", "sidebrown": "weathered_plank_siding", "plankold": "weathered_brown_planks",
    "wallpaint": "distressed_painted_planks", "wallblue": "blue_painted_planks", "wallraw": "weathered_planks",
    "floorwood": "old_wood_floor", "ceilwood": "raw_plank_wall", "plankgrey": "wood_planks_grey",
    "corrug": "corrugated_iron_02", "corrugrust": "rusty_corrugated_iron", "corrugworn": "worn_corrugated_iron",
    "metalwhite": "rusty_metal_02", "metalgreen": "green_metal_rust", "metalplate": "metal_plate", "metalrust": "rusty_metal_sheet",
    "caban": "caban", "fur": "curly_teddy_natural", "hessian": "hessian_230", "linen": "rough_linen", "terry": "terry_cloth",
    "concrete": "concrete_floor_worn_001", "rock": "rock_face", "plaster": "painted_plaster_wall",
}

MODELS = {
    "stove": "barrel_stove", "lantern": "Lantern_01", "walllamp": "industrial_wall_lamp", "socket": "pull_chain_light_socket",
    "bulb": "lightbulb_01", "desklamp": "desk_lamp_arm_01", "radio": "vintage_radio_transceiver",
    "rxpanel": "vintage_spacecraft_instrument", "meter": "retro_multimeter", "jerry": "metal_jerrycan_green",
    "jerryred": "metal_jerrycan", "drumred": "Barrel_01", "drumblue": "barrel_03", "oiltin": "oil_tin",
    "crate1": "wooden_crate_01", "crate2": "wooden_crate_02", "mcrate": "wooden_military_crate", "ocrate": "old_military_crate",
    "ammobox": "ammo_box", "medbox": "medical_box", "bed": "old_bed_frame", "nstand": "painted_wooden_nightstand",
    "cabinet": "painted_wooden_cabinet", "cupboard": "painted_wooden_cabinet_02", "table": "painted_wooden_table",
    "chair": "painted_wooden_chair_02", "chairw": "painted_wooden_chair_01", "stool": "painted_wooden_stool",
    "bench": "painted_wooden_bench", "wshelf": "painted_wooden_shelves", "stool2": "wooden_stool_01",
    "bookshelf": "wooden_bookshelf_worn", "shelves": "steel_frame_shelves_01", "rack": "worn_metal_rack",
    "desk": "metal_office_desk", "cardbox": "vintage_wooden_drawer_01", "diesel": "old_military_compressor",
    "breaker": "power_box_01", "feeder": "utility_box_01", "pump": "tire_pump", "toolchest": "metal_tool_chest",
    "toolbox": "metal_toolbox", "vice": "bench_vice_01", "axe": "wooden_axe", "spade": "rusted_spade_01",
    "binoc": "binoculars", "compass": "seadogs_compass", "sigflash": "signal_flashlight", "alarm": "alarm_clock_01",
    "mclock": "mantel_clock_01", "cans": "russian_food_cans_01", "pot": "pot_enamel_01", "thermos": "modified_thermos",
    "kettle": "vintage_electric_kettle", "rifle": "bolt_action_rifle_7_62", "boots": "rubber_boots",
    "books": "book_encyclopedia_set_01", "journal": "binder_notebook", "clipboard": "clipboard",
    "postcards": "postcard_set_01", "frame": "hanging_picture_frame_01", "chess": "chess_set",
    "bucket": "wooden_bucket_01", "broom": "wooden_broom", "gastank": "propane_tank", "drawers": "drawer_cabinet",
    "sideboard": "WoodenTable_03",
}


def get(url):
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
                return r.read()
        except Exception as e:
            print("    повтор:", type(e).__name__, flush=True)
            time.sleep(2 + attempt * 2)
    raise RuntimeError("не скачать: " + url)


def fetch_textures(only):
    os.makedirs(TEX, exist_ok=True)
    credits = []
    for short, tid in TEXTURES.items():
        credits.append(f"{short} — https://polyhaven.com/a/{tid}")
        if only and short not in only:
            continue
        want = {"d": "Diffuse", "n": "nor_gl", "r": "Rough"}
        if all(os.path.exists(os.path.join(TEX, f"{short}_{k}.jpg")) for k in want):
            continue
        info = json.loads(get(f"https://api.polyhaven.com/files/{tid}"))
        size = 0
        for k, key in want.items():
            node = info.get(key, {}).get(RES, {}).get("jpg")
            if not node:
                print("  нет карты", key, "у", tid)
                continue
            b = get(node["url"])
            open(os.path.join(TEX, f"{short}_{k}.jpg"), "wb").write(b)
            size += len(b)
        print(f"  tex {short} ({tid}): {size / 1048576:.1f} МБ", flush=True)
    return credits


def short_tex(uri, used):
    low = uri.lower()
    base = "t"
    for key, s in (("_diff", "d"), ("_nor_gl", "n"), ("_nor", "n"), ("_arm", "a"), ("_rough", "r"), ("_metal", "mt"),
                   ("_ao", "ao"), ("_emission", "e"), ("_emissive", "e"), ("_alpha", "al"), ("_opacity", "al"), ("_spec", "s")):
        if key in low:
            base = s
            break
    ext = os.path.splitext(uri)[1].lower()
    name = base + ext
    i = 2
    while name in used:
        name = f"{base}{i}{ext}"
        i += 1
    used.add(name)
    return name


def obtain(mid):
    """Возвращает (имя gltf, {относительный путь: байты})."""
    src = os.path.join(LOCAL, mid)
    if os.path.isdir(src):
        files = {}
        main = None
        for dp, _, fns in os.walk(src):
            for fn in fns:
                if fn.endswith(".import"):
                    continue
                p = os.path.join(dp, fn)
                rel = os.path.relpath(p, src).replace(os.sep, "/")
                files[rel] = open(p, "rb").read()
                if fn.endswith(".gltf"):
                    main = rel
        if main:
            return main, files
    info = json.loads(get(f"https://api.polyhaven.com/files/{mid}"))
    g = info.get("gltf", {}).get(RES) or info.get("gltf", {}).get("2k")
    if not g:
        return None, {}
    g = g["gltf"]
    main = os.path.basename(g["url"])
    files = {main: get(g["url"])}
    for rel, f in g.get("include", {}).items():
        files[rel] = get(f["url"])
    return main, files


def fetch_models(only):
    os.makedirs(MDL, exist_ok=True)
    credits = []
    total = 0
    for short, mid in MODELS.items():
        credits.append(f"{short} — https://polyhaven.com/a/{mid}")
        if only and short not in only:
            continue
        d = os.path.join(MDL, short)
        if os.path.exists(os.path.join(d, "m.gltf")):
            continue
        main, files = obtain(mid)
        if not main:
            print("  нет glTF:", mid)
            continue
        doc = json.loads(files[main].decode("utf-8"))
        os.makedirs(d, exist_ok=True)
        size = 0
        used = set()
        for img in doc.get("images", []):
            uri = img.get("uri")
            if not uri or uri not in files:
                continue
            nm = short_tex(uri, used)
            open(os.path.join(d, nm), "wb").write(files[uri])
            size += len(files[uri])
            img["uri"] = nm
        for i, buf in enumerate(doc.get("buffers", [])):
            uri = buf.get("uri")
            if not uri or uri not in files:
                continue
            nm = "m.bin" if i == 0 else f"m{i}.bin"
            open(os.path.join(d, nm), "wb").write(files[uri])
            size += len(files[uri])
            buf["uri"] = nm
        open(os.path.join(d, "m.gltf"), "w", encoding="utf-8").write(json.dumps(doc))
        total += size
        print(f"  mdl {short} ({mid}): {size / 1048576:.1f} МБ", flush=True)
    print(f"Модели: {total / 1048576:.1f} МБ")
    return credits


def main():
    a = sys.argv[1:]
    kind = a[0] if a and a[0] in ("tex", "mdl") else ""
    only = [x for x in a if x not in ("tex", "mdl")]
    lines = ["Текстуры и 3D-модели: Poly Haven (https://polyhaven.com), лицензия CC0 (общественное достояние).", ""]
    if kind in ("", "tex"):
        lines += ["Текстуры:"] + fetch_textures(only) + [""]
    if kind in ("", "mdl"):
        lines += ["Модели:"] + fetch_models(only)
    if not kind and not only:
        open(os.path.join(ROOT, "CREDITS.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("Готово")


if __name__ == "__main__":
    main()
