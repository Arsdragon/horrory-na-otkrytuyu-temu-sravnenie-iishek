# «Третий пар» — заметки для продолжения работы

Хоррор на Godot 4.7.2 (Forward+), всё строится кодом. План, сюжет, механики — `docs/PLAN.md`;
модели для Blender — `docs/BLENDER.md`; для игрока — `README.txt`.

## Устройство
- `src/core/` — автозагрузки: `Settings` (user://settings.cfg), `Game` (флаги, предметы, записки, сообщения,
  контрольные точки, сохранение user://save.json), `Snd` (банк snd/*.ogg, варианты name_N, петли loop_*, реверб по комнате).
- `src/world/` — `layout.gd` (план: комнаты, проёмы, окна), `builder.gd` (стены/полы/окна/двери/бассейн/улица),
  `props*.gd` (обстановка), `door.gd`, `tap.gd` (краны/души: зовут Хозяйку), `hide_spot.gd`, `items.gd`
  (шайка, подбираемое, вентили, огонь), `mirror.gd` (зеркало-камера, слой 20 видит только зеркало), `world.gd`
  (окружение, вода, пар, навмеш, шум `noise()`, запросы room_at/surface_at/water_depth/is_safe).
- `src/monster/` — `hoz_body.gd` (модель Rocketbox или mdl/custom/hozyayka.glb, анимации, волосы-шейдер),
  `hoz_rig.gd` (SkeletonModifier3D: длинные руки, сутулость, челюсть), `hozyayka.gd` (ИИ: слух, вода, бросок,
  поиск, мытьё, «за спиной», убийство), `director.gd` (когда выходит, стук труб, мелкие пугалки, музыка), `hoz_hand.gd`.
- `src/story/` — `notes.json` (записки, их же рисует tools/make_tex.py), `texts.gd` (сообщения, задачи, точки,
  концовки), `scenario.gd` (всё сюжетное: двери, предметы, триггеры, сцены, концовки).
- `src/ui/` — HUD с пост-эффектом, телефон, экраны, главное меню, админ-меню, панель F1, музей. `src/main.gd` — поток игры.

## Команды
- `python tools/fetch_assets.py` — скачать сторонние ассеты; `python tools/make_tex.py`, `tools/audio/make_audio.py`,
  `tools/voice/make_voice.py` — свои текстуры/звук/шёпот; `python tools/fix_imports.py` после импорта.
- `tools/dev.sh import` — импорт (нужен после новых файлов и новых class_name); `tools/dev/check.sh` — ошибки скриптов.
- `tools/dev.sh bot [--ending=open_tap|valve|steam|last_steam] [--from=c10_collector]` — бот проходит сюжет (без окна).
- `godot --headless --path . -- --aitest` — проверка ИИ и уровня (7 тестов: слух, кран, шкафчики, «за спиной»,
  все помещения достижимы по навмешу, капсула игрока физически проходит маршрут через всю баню и подвал).
- `tools/dev/shot.sh <имя> --cp=<точка> --pos=x,y,z --look=yaw,pitch --light --wait=сек [--kill=сек] [--hoz=x,y,z] [--ui=phone|note|pause|code|panel] [--event=метод_сценария] [--fps]`
  — скриншот в shots/ (окно без фокуса, спрятано у панели задач; повторяет, если окно сжалось).
- `python tools/build.py` — release/TretiyPar/TretiyPar.exe (+ README, CREDITS) и release/TretiyPar.zip.
  Бот работает и в exe: `release/TretiyPar/TretiyPar.exe --headless -- --bot`.

## Подводные камни
- GDScript 4.7: `:=` от Variant (элемент массива/словаря) — ошибка разбора; писать тип явно.
- Новые .jpg/.png: после импорта `fix_imports.py` (VRAM-сжатие, мип-карты), иначе мир грузится в 4 раза дольше.
- Игрока ставить в позицию ДО add_child, иначе триггер у (0,0,0) срабатывает при спавне.
- Прогрев шейдеров (`main._prewarm`) телепортирует игрока; триггеры и смена комнаты на это время отключены.
- Контрольные точки только вперёд (`scenario.cp`), порядок — ключи Texts.CHECKPOINTS.
- Волосы дорогие при близком взгляде: 230 прядей без теней. Больше — FPS на Intel UHD падает.
- Окно скриншотов иногда сжимается до ~180×60 — shot.sh переснимает.
- Навмеш: ячейка 0.1, радиус агента 0.2 (иначе проёмы 0.8–1.0 м схлопываются). Лестница — одна выпуклая форма.
- Модель Poly Haven steel_frame_shelves_01 размером 11×21 м — не использовать (стеллажи — Props.shelves).

## Не проверено
Звук на слух, баланс живой игры, ощущение страха — только бот и скриншоты. Модель из Blender не подключали.
