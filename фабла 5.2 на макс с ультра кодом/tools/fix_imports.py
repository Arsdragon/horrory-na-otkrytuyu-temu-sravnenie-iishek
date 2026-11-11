"""Настройки импорта текстур 3D: VRAM-сжатие и мип-карты (иначе снег рябит, а память тратится зря).
Запускать после первого импорта, затем импортировать снова:  python tools/fix_imports.py && tools/dev.sh import
"""
import glob, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# экранные и мелкие текстуры остаются без сжатия
KEEP = ("frost", "cookie", "ico_", "halo", "eye", "flake", "dot", "foot")
changed = 0
files = glob.glob(os.path.join(ROOT, "tex", "*.import")) + glob.glob(os.path.join(ROOT, "mdl", "**", "*.import"), recursive=True)
for f in files:
    name = os.path.basename(f)
    if name.endswith((".gltf.import", ".bin.import")):
        continue
    if "tex" in os.path.basename(os.path.dirname(f)) and name.startswith(KEEP):
        continue
    s = open(f, encoding="utf-8").read()
    if "compress/mode" not in s:
        continue
    o = s
    s = re.sub(r"compress/mode=\d", "compress/mode=2", s)
    s = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", s)
    s = re.sub(r"detect_3d/compress_to=\d", "detect_3d/compress_to=0", s)
    base = name.split(".")[0]
    if base.endswith("_n") or base == "n":
        s = re.sub(r"compress/normal_map=\d", "compress/normal_map=1", s)
    if s != o:
        open(f, "w", encoding="utf-8", newline="\n").write(s)
        changed += 1
print("настроено файлов:", changed, "из", len(files))
