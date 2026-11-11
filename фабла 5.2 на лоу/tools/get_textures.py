"""Downloads CC0 textures from Poly Haven (1k jpg, diffuse + GL normal) into assets/tex."""
import json, os, sys, urllib.request

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "tex")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "godot-game-asset-fetch/1.0"}

ROLES = {
    "floor": ["wood_floor_deck", "old_wood_floor", "brown_planks_03", "wood_planks_grey"],
    "plaster": ["painted_plaster_wall", "plastered_wall", "white_plaster_02", "beige_wall_001"],
    "concrete": ["concrete_floor_02", "concrete_floor", "concrete_wall_006"],
    "rust": ["rusty_metal_02", "green_metal_rust", "rusty_metal", "metal_plate"],
    "snow": ["snow_02", "snow_field_aerial", "snow_03", "snow_01"],
    "iron": ["corrugated_iron", "corrugated_iron_02", "corrugated_iron_03"],
    "planks": ["wood_planks_grey", "weathered_brown_planks", "brown_planks_05", "wood_plank_wall"],
    "bark": ["bark_brown_02", "bark_brown_01", "pine_bark"],
}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()


def pick(files, keys):
    for k in keys:
        if k in files and "1k" in files[k] and "jpg" in files[k]["1k"]:
            return files[k]["1k"]["jpg"]["url"]
    return None


for role, cands in ROLES.items():
    if os.path.exists(os.path.join(OUT, role + "_d.jpg")):
        print(role, "exists")
        continue
    ok = False
    for cid in cands:
        try:
            files = json.loads(get("https://api.polyhaven.com/files/" + cid))
        except Exception as e:
            print("  miss", cid, e)
            continue
        d = pick(files, ["Diffuse", "diff", "Color"])
        n = pick(files, ["nor_gl", "Normal"])
        if not d:
            continue
        open(os.path.join(OUT, role + "_d.jpg"), "wb").write(get(d))
        if n:
            open(os.path.join(OUT, role + "_n.jpg"), "wb").write(get(n))
        print(role, "<-", cid)
        ok = True
        break
    if not ok:
        print("FAILED", role)
        sys.exit(1)
