"""Полная сборка для Windows: импорт → экспорт Godot → папка без установки → установщик.

    python tools/build.py           → release/Leer_Setup.exe и release/Leer (играть без установки)
    python tools/build.py --assets  → сначала заново создать свои текстуры, звук и голоса
Нужно: Godot 4.7.2 и шаблоны экспорта (%USERPROFILE%\tools\godot), Python + Pillow + numpy + scipy + PyInstaller, ffmpeg.
Текстуры и модели Poly Haven скачиваются отдельно: python tools/fetch_assets.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.expandvars(r"%USERPROFILE%\tools\godot\Godot_v4.7.2-stable_win64_console.exe")
OUT = os.path.join(ROOT, "release")
SEP = ";"


def run(cmd, **kw):
    print(">", " ".join(os.path.basename(c) if i == 0 else c for i, c in enumerate(cmd[:4])), "…", flush=True)
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)
    if r.returncode:
        print(r.stdout[-3000:], r.stderr[-3000:])
        sys.exit("Ошибка: " + cmd[0])
    return r.stdout + r.stderr


def version():
    text = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    return re.search(r'config/version="([^"]+)"', text).group(1)


def main():
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    if "--assets" in sys.argv:
        run([sys.executable, "tools/make_tex.py"], env=env)
        subprocess.run([sys.executable, "make_audio.py"], cwd=os.path.join(ROOT, "tools", "audio"), env=env, check=True)
        run([sys.executable, "tools/voice/make_voice.py"], env=env)
    for junk in ("override.cfg",):
        p = os.path.join(ROOT, junk)
        if os.path.exists(p):
            os.remove(p)
    run([GODOT, "--headless", "--path", ROOT, "--import"])
    run([sys.executable, "tools/fix_imports.py"], env=env)
    run([GODOT, "--headless", "--path", ROOT, "--import"])
    build = os.path.join(ROOT, "build")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    exe = os.path.join(build, "Leer.exe")
    out = run([GODOT, "--headless", "--path", ROOT, "--export-release", "Windows Desktop", exe])
    if not os.path.exists(exe):
        print(out[-3000:])
        sys.exit("Экспорт не удался")
    print(f"Игра: {os.path.getsize(exe) / 1048576:.0f} МБ")
    # папка без установки
    portable = os.path.join(OUT, "Leer")
    shutil.rmtree(portable, ignore_errors=True)
    os.makedirs(portable)
    for f in os.listdir(build):
        shutil.copy(os.path.join(build, f), portable)
    for doc in ("README.txt", "CREDITS.txt"):
        if os.path.exists(os.path.join(ROOT, doc)):
            shutil.copy(os.path.join(ROOT, doc), portable)
    # установщик
    work = tempfile.mkdtemp(prefix="leer_build_")
    try:
        payload = os.path.join(work, "payload.zip")
        with zipfile.ZipFile(payload, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            for f in os.listdir(portable):
                z.write(os.path.join(portable, f), os.path.join("Leer", f))
        with open(os.path.join(work, "version.txt"), "w", encoding="utf-8") as f:
            f.write(version())
        icon = os.path.join(ROOT, "icon.ico")
        cmd = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--onefile", "--windowed", "--icon", icon,
               "--name", "Leer_Setup", "--distpath", os.path.join(work, "dist"), "--workpath", os.path.join(work, "b"),
               "--specpath", work, "--add-data", f"{payload}{SEP}.", "--add-data", f"{os.path.join(work, 'version.txt')}{SEP}.",
               "--add-data", f"{icon}{SEP}.", os.path.join(ROOT, "tools", "installer.py")]
        run(cmd)
        os.makedirs(OUT, exist_ok=True)
        dst = os.path.join(OUT, "Leer_Setup.exe")
        shutil.copy(os.path.join(work, "dist", "Leer_Setup.exe"), dst)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"Готово: {dst} ({os.path.getsize(dst) / 1048576:.0f} МБ), версия {version()}")


if __name__ == "__main__":
    main()
