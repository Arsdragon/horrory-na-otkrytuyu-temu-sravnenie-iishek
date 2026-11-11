# ЛЕЕР — Godot 4.7.2 (Forward+), Windows

Хоррор от первого лица: полярная станция «Тихая», январь 1987, пурга. Существо «Отзыв» отвечает на любой сигнал
(свет, стук, голос) и учится. Пять ночей, 23 точки входа, 4 концовки. Полный замысел и сценарий — `docs/PLAN.md`.

## Запуск и сборка
- Godot: `%USERPROFILE%\tools\godot\Godot_v4.7.2-stable_win64_console.exe`, шаблоны экспорта установлены.
- `python tools/build.py` → `release/Leer_Setup.exe` + `release/Leer/` (папка без установки). `--assets` — заново свои текстуры, звук, голоса.
- Генераторы (результаты лежат в проекте): `tools/fetch_assets.py` (Poly Haven CC0 → `tex/*_d|_n|_r.jpg`, `mdl/<имя>/m.gltf`,
  короткие имена из-за длинных путей), `tools/make_tex.py [имена]` (свои текстуры, схема, календарь, значки),
  `tools/audio/make_audio.py [группы]` (весь звук, numpy → ogg), `tools/voice/make_voice.py [ключи]` (Windows TTS Павел/Ирина
  через WinRT, тексты берёт из `src/texts.gd` VOICE).
- После добавления текстур: `python tools/fix_imports.py`, затем импорт (VRAM-сжатие и мип-карты).

## Проверка (аргументы игры после `--`)
- `tools/dev.sh import` — импорт и ошибки. `tools/dev.sh shot <png[;png2]> <сек> [args]` — снимок (окно без фокуса, за краем экрана).
- `tools/dev.sh bot --stage=n1_wake [--until=n3_wake] [--speed=8]` — бот без окна проходит этапы подряд до концовки
  (`BOT DONE ending bort`). Гонять после любых правок сценария. `--sandbox --griptest` — проход по лееру «А» с поворотом.
- Запуск мест: `--place=<ключ world.places> --lamp=1 --nogust|--gust=0.9 --clear=1 --bright=1 --nocold --god --yaw --pitch --pos=x,y,z`.
- `--stage=<id> [--fast|--nofast]` — этап; `--ent=дист,неправильность[,руки]`, `--eyes=1`, `--hunt=уровень`, `--ev=событие[,…]` (ключи Director.EVENTS),
  `--hideview`, `--note=id`, `--notebook=N`, `--radio`, `--panel`, `--menu=main|admin|stages|settings`, `--museum=figure|models|notes|sounds|endings`,
  `--tour=<папка> [--only=a,b]` — кадр каждого места, `--fps` — журнал кадров и треугольников.

## Архитектура (src/)
- `main.gd` — 3D в SubViewport (540 строк по умолчанию) → TextureRect с `shaders/post.gdshader` (зерно, изморозь от холода, помехи, страх).
  SubViewport без контейнера ввод не получает: `main._unhandled_input` → `vp.push_input`. Слои: hud_layer, ui_layer, top_layer.
- Автозагрузки: `Cfg` (настройки, ввод, аргументы; `testing()` — не трогать сохранения), `Snd` (шины Sfx/Amb/Voice/World/Wind/Music,
  варианты `_N`, `loop`/`emitter` играют копию потока), `G` (`autoload/game.gd`: меню, `start_stage`, контрольные точки, смерть, концовки, окна).
- `texts.gd` (класс `T`) — все тексты: VOICE, NOTES, OBJ, HINT, THINK, карточки, концовки.
- `world/`: `map.gd` (координаты, ломаные лееров), `world.gd` (зоны тепла, электричество, печи, маяк), `weather.gd` (туман, частицы,
  порывы, глобальные `g_wind/g_gust/g_clear`), `ropes.gd` (столбы, трос, флажки, разрывы, `nearest/near_all/point_at/s_ok`),
  `batch.gd` (слияние коробок и цилиндров по материалам, UV в метрах), `kit.gd` (материалы, модели `put` с центровкой, ореолы),
  `walls.gd` (стены с проёмами, окна), `build_house.gd`, `build_sites.gd` (дизельная, метеоплощадка, ГСМ, мачта, площадка, балок, ледник),
  `interact.gd`, `door.gd`, `props.gd`, `prints.gd` (следы).
- `player.gd` — ходьба, фонарь (`lit_by_lamp`), хват (`grip_line`, `grip_s` — метры вдоль леера), тепло, выносливость, режимы walk/bed/hide/locked/dead/free.
- `figure.gd` — фигура в парке из примитивов (`wrong` 0..1, позы stand/sit, маска, глаза `shaders/eyes.gdshader`); `entity.gd` — ИИ:
  WATCH / ACTIVE / PASS / LEAVE / SCRIPT, `level` 2..5 = номер ночи.
- `director.gd` — действия игрока (`act`), события (`ev`, список EVENTS), фон (рация, страх, охота), ожидания через сигнал `tick`.
  `nights.gd` — сопрограммы этапов `s_<id>` и `setup(id)`; `bot.gd` — автопрохождение `b_<id>`.
- `ui/`: `hud.gd`, `cards.gd` (вступление, ночь, смерть, концовка), `note_view.gd`, `notebook.gd`, `radio_ui.gd`, `menus.gd`, `admin.gd` (F1), `museum.gd`.

## Подводные камни
- GDScript 4.7: `:=` от Variant — ошибка; многострочная лямбда только последним аргументом вызова.
- Команда Bash длиннее ~8000 знаков обрезается (ошибка «unexpected EOF») — длинные скрипты писать файлом.
- Корневые Control под CanvasLayer: размер задавать явно в `_process` (якоря не срабатывают).
- Тела вращения `Kit.lathe` — обход по часовой снаружи; маска лица рисуется с обеих сторон.
- Существо в состоянии SCRIPT не обходит постройки (иначе не войдёт в дом); в остальных состояниях обходит AABB из `_obstacles`.
- Ледник стоит в стороне (`BuildSites.CELLAR`), попадают в него телепортом через люк.
- Сохранение `%APPDATA%\Leer\save.json`; админ-режим и тестовые запуски его не пишут.
- Замена существа своей моделью (`mdl/custom/otzyv.glb`, см. план, раздел 12) написана, но на настоящем файле не проверялась.
