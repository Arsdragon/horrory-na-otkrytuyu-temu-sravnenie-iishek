# ПОВЕРКА — заметки для продолжения
Godot 4.7.2 (`%USERPROFILE%\tools\godot\Godot_v4.7.2-stable_win64_console.exe`). План и дизайн: docs/PLAN.md.
* src/main.gd — меню, переключение, режимы проверки: `--bot` (логика), `--stairs` (Жилец идёт по лестнице 1→3),
  `--mode=game --view=entity|corridor|stairs|room|wardrobe|scare|bright`, `--mode=gallery`, `--shot=файл --wait=сек`.
* src/world.gd — дом кодом (этаж L на y=3L), предметы, граф AStar3D для Жильца, записки (NOTES).
* src/player.gd, src/entity.gd (ИИ: обход/на звук/погоня/поиск/у шкафа), src/zhilets_model.gd (модель+анимация,
  хук models/zhilets.glb), src/game.gd (шум, события, фазы, смерть/финал), src/hud.gd, src/admin.gd (F1), src/gallery.gd.
* Ассеты: `python tools/make_assets.py`. Отладка: `sh tools/dev.sh import|bot|shot`. Экспорт:
  `godot --headless --path . --export-release "Windows Desktop" build/Poverka.exe`.
Не проверено: звук на слух, баланс живым игроком.
