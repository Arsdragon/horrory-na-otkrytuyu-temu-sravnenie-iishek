#!/bin/sh
# Отладка: tools/dev.sh import | shot <файл.png[;файл2.png]> [сек] [аргументы игры…] | run [аргументы] | bot [аргументы]
# Окно снимков не берёт фокус и стоит в правом нижнем углу под панелью задач, чтобы в него нельзя было попасть мышью.
cd "$(dirname "$0")/.."
GD="$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
case "$1" in
  import) "$GD" --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT|Parse|error|WARNING" | head -60 ;;
  shot) shift; out="$1"; w="${2:-3}"; shift 2 2>/dev/null
        printf '[display]

window/size/no_focus=true
' > override.cfg
        timeout 240 "$GD" --path . --windowed --resolution 1280x720 --position 1850,1150 -- --shot="$out" --wait="$w" "$@" 2>&1 | grep -E "ERROR|SCRIPT|WARN|at:|Parse|SHOT|LOG" | head -60
        rm -f override.cfg ;;
  run) shift; "$GD" --path . "$@" ;;
  bot) shift; timeout 600 "$GD" --headless --path . -- --bot "$@" 2>&1 | grep -E "ERROR|SCRIPT|at:|Parse|BOT|LOG" | head -120 ;;
esac
