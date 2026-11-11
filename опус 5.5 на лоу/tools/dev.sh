#!/bin/sh
# tools/dev.sh import | shot <файл.png> [сек] [аргументы] | bot | run [аргументы]
cd "$(dirname "$0")/.."
GD="$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
case "$1" in
  import) "$GD" --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT|Parse|error|WARNING" | head -60 ;;
  shot) shift; out="$1"; w="${2:-3}"; shift 2 2>/dev/null
        printf '[display]\n\nwindow/size/no_focus=true\n' > override.cfg
        timeout 240 "$GD" --path . --windowed --resolution 1280x720 --position 1850,1150 -- --shot="$out" --wait="$w" "$@" 2>&1 | grep -E "ERROR|SCRIPT|WARN|at:|Parse|SHOT" | head -60
        rm -f override.cfg ;;
  run) shift; "$GD" --path . "$@" ;;
  bot) shift; timeout 300 "$GD" --headless --path . -- --bot "$@" 2>&1 | grep -E "ERROR|SCRIPT|at:|Parse|BOT|LOG" | head -120 ;;
esac
