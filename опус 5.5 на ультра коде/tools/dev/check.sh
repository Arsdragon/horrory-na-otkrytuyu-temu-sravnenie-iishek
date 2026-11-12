#!/usr/bin/env bash
# Проверка скриптов: импорт и вывод ошибок разбора с файлом и строкой.
cd "$(dirname "$0")/../.."
GD="$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GD" --headless --path . --import > "$TEMP/check.log" 2>&1
grep -E "SCRIPT ERROR|GDScript::reload" "$TEMP/check.log" | paste - - | sed -E 's/\s+at: GDScript::reload \(/ @ /' | grep -v "Failed to compile depended" | head -30
