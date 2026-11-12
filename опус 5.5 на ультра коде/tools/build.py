r"""Сборка для Windows: импорт → правка импорта → экспорт Godot → папка release\TretiyPar и архив.

    python tools/build.py            — собрать
    python tools/build.py --assets   — сначала заново сделать свои текстуры, звук и голос
    python tools/build.py --fetch    — сначала скачать сторонние ассеты (ambientCG, Poly Haven, Rocketbox, шрифты)
Нужно: Godot 4.7.2 и шаблоны экспорта (%USERPROFILE%\tools\godot), Python + Pillow + numpy + scipy, ffmpeg.
"""
import os
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.expandvars(r"%USERPROFILE%\tools\godot\Godot_v4.7.2-stable_win64_console.exe")
OUT = os.path.join(ROOT, "release")
NAME = "TretiyPar"


def run(cmd, **kw):
    print(">", " ".join(os.path.basename(c) if i == 0 else c for i, c in enumerate(cmd[:5])), flush=True)
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)
    if r.returncode:
        print(r.stdout[-3000:], r.stderr[-3000:])
        sys.exit("Ошибка: " + os.path.basename(cmd[0]))
    return r.stdout + r.stderr


def main():
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    if "--fetch" in sys.argv:
        run([sys.executable, "tools/fetch_assets.py"], env=env)
    if "--assets" in sys.argv:
        run([sys.executable, "tools/make_tex.py"], env=env)
        run([sys.executable, "tools/audio/make_audio.py"], env=env)
        run([sys.executable, "tools/voice/make_voice.py"], env=env)
    if os.path.exists(os.path.join(ROOT, "override.cfg")):
        os.remove(os.path.join(ROOT, "override.cfg"))
    run([GODOT, "--headless", "--path", ROOT, "--import"])
    run([sys.executable, "tools/fix_imports.py"], env=env)
    run([GODOT, "--headless", "--path", ROOT, "--import"])
    build = os.path.join(ROOT, "build")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    exe = os.path.join(build, NAME + ".exe")
    out = run([GODOT, "--headless", "--path", ROOT, "--export-release", "Windows Desktop", exe])
    if not os.path.exists(exe):
        print(out[-3000:])
        sys.exit("Экспорт не удался")
    print(f"Игра: {os.path.getsize(exe) / 1048576:.0f} МБ")
    portable = os.path.join(OUT, NAME)
    shutil.rmtree(portable, ignore_errors=True)
    os.makedirs(portable)
    shutil.copy2(exe, os.path.join(portable, NAME + ".exe"))
    for f in ("README.txt", "CREDITS.txt"):
        if os.path.exists(os.path.join(ROOT, f)):
            shutil.copy2(os.path.join(ROOT, f), os.path.join(portable, f))
    z = os.path.join(OUT, NAME + ".zip")
    if os.path.exists(z):
        os.remove(z)
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in os.listdir(portable):
            zf.write(os.path.join(portable, f), os.path.join(NAME, f))
    print("Готово:", portable)
    print("Архив:", z, f"{os.path.getsize(z) / 1048576:.0f} МБ")


if __name__ == "__main__":
    main()
