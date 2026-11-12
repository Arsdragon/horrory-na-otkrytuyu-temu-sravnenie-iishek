#!/usr/bin/env bash
# Скриншот с повтором: если окно сжалось (картинка меньше 1000 px), снимаем ещё раз.
# tools/dev/shot.sh <имя> <аргументы игры…>
cd "$(dirname "$0")/../.."
name="$1"; shift
for i in 1 2 3; do
	timeout 150 tools/dev.sh shot --shot="$name" "$@" > "$TEMP/shot_$name.log" 2>&1
	w=$(python -c "from PIL import Image; print(Image.open('shots/$name.png').size[0])" 2>/dev/null)
	if [ "${w:-0}" -ge 1000 ]; then grep -E "SCRIPT ERROR" "$TEMP/shot_$name.log" | head -3; echo "ok $name"; exit 0; fi
done
echo "не вышло: $name"
