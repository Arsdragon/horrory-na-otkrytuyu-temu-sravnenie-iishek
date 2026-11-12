#!/usr/bin/env bash
# Запуск для разработки. Окно без фокуса и спрятано у панели задач, чтобы не мешать работе за ПК.
#   tools/dev.sh tour                — скриншоты точек обзора в shots/
#   tools/dev.sh run [args…]         — обычный запуск с окном (без фокуса)
#   tools/dev.sh bot [args…]         — бот проходит игру без окна (--headless)
#   tools/dev.sh shot <args…>        — произвольные аргументы игры, окно спрятано
#   tools/dev.sh import              — импорт ресурсов
cd "$(dirname "$0")/.."
GD="$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
mode="$1"; shift
park() {
	printf '[display]\nwindow/size/no_focus=true\n' > override.cfg
	trap 'rm -f override.cfg' EXIT
}
case "$mode" in
	import) "$GD" --headless --path . --import ;;
	tour) park; "$GD" --path . --position 1850,1150 --resolution 1280x720 -- --tour --windowed "$@" ;;
	shot) park; "$GD" --path . --position 1850,1150 --resolution 1280x720 -- --windowed "$@" ;;
	run) park; "$GD" --path . --position 1850,1150 --resolution 1280x720 -- --windowed "$@" ;;
	bot) "$GD" --headless --path . -- --bot "$@" ;;
	*) echo "режимы: import tour run bot shot" ;;
esac
