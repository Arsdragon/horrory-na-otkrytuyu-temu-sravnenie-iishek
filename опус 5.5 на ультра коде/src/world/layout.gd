class_name Layout
## План бани. Координаты в метрах: x — на восток, z — на юг (север = z меньше), y — вверх.
## Комната: прямоугольник по осям стен [x0, z0, x1, z1], пол на высоте y, высота h.
## Материалы: floor / wall / wall_low (панель до low метров) / ceil. wet — мокрый пол (шум сильнее).
## reverb — размер эха и «мокрость» [size, wet]. safe — на пороге соль (Хозяйка не входит).

const BASE_Y := -4.5

const ROOMS := {
	# ---------- первый этаж ----------
	"lobby": {"name": "Вестибюль", "r": [14, 23, 38, 30], "y": 0.0, "h": 3.6,
		"floor": "terracotta", "wall": "plaster", "wall_low": "paint_blue", "low": 1.5, "ceil": "plaster",
		"reverb": [0.6, 0.25], "safe": true},
	"admin": {"name": "Коридор персонала", "r": [16, 20, 36, 23], "y": 0.0, "h": 3.0,
		"floor": "linoleum", "wall": "peeling", "wall_low": "paint_green", "low": 1.4, "ceil": "plaster", "reverb": [0.35, 0.15]},
	"office": {"name": "Кабинет заведующей", "r": [16, 17, 22, 20], "y": 0.0, "h": 3.0,
		"floor": "linoleum", "wall": "wallpaper", "ceil": "plaster", "reverb": [0.2, 0.05]},
	"linen": {"name": "Бельевая", "r": [22, 17, 27, 20], "y": 0.0, "h": 3.0,
		"floor": "linoleum", "wall": "plaster", "wall_low": "paint_green", "low": 1.4, "ceil": "plaster", "reverb": [0.15, 0.05]},
	"barber": {"name": "Парикмахерская", "r": [27, 17, 32, 20], "y": 0.0, "h": 3.0,
		"floor": "tile_floor2", "wall": "tile_wall", "ceil": "plaster", "reverb": [0.3, 0.2]},
	"buffet": {"name": "Буфет", "r": [32, 17, 36, 20], "y": 0.0, "h": 3.0,
		"floor": "linoleum", "wall": "peeling", "wall_low": "paint_blue", "low": 1.4, "ceil": "plaster", "reverb": [0.2, 0.1]},

	"m_wait": {"name": "Ожидальня (муж.)", "r": [0, 20, 4, 26], "y": 0.0, "h": 3.4,
		"floor": "tile_floor2", "wall": "plaster", "wall_low": "paint_green", "low": 1.6, "ceil": "plaster", "reverb": [0.3, 0.15]},
	"m_util": {"name": "Подсобка (муж.)", "r": [0, 26, 4, 30], "y": 0.0, "h": 3.0,
		"floor": "concrete", "wall": "plaster_dmg", "wall_low": "paint_green", "low": 1.4, "ceil": "plaster", "reverb": [0.15, 0.05]},
	"m_lock": {"name": "Раздевальня (муж.)", "r": [4, 20, 14, 30], "y": 0.0, "h": 3.4,
		"floor": "tile_floor2", "wall": "plaster", "wall_low": "paint_green", "low": 1.6, "ceil": "plaster", "reverb": [0.45, 0.2]},
	"m_wash": {"name": "Мыльная (муж.)", "r": [0, 9, 14, 20], "y": 0.0, "h": 4.4,
		"floor": "tile_floor", "wall": "plaster_dmg", "wall_low": "tile_wall", "low": 2.4, "ceil": "plaster_dmg",
		"wet": true, "reverb": [0.85, 0.45]},
	"m_steam": {"name": "Парильня (муж.)", "r": [0, 3, 8, 9], "y": 0.0, "h": 3.0,
		"floor": "planks_dark", "wall": "planks_dark", "ceil": "planks_dark", "wet": true, "reverb": [0.25, 0.1]},
	"m_shower": {"name": "Душевая (муж.)", "r": [8, 3, 14, 9], "y": 0.0, "h": 3.4,
		"floor": "tile_floor", "wall": "tile_wall", "ceil": "plaster_dmg", "wet": true, "reverb": [0.6, 0.45]},

	"pool": {"name": "Бассейн", "r": [14, 6, 38, 17], "y": 0.0, "h": 5.0,
		"floor": "tile_wall", "wall": "plaster_dmg", "wall_low": "tile_green", "low": 2.2, "ceil": "plaster_dmg",
		"wet": true, "reverb": [1.0, 0.55]},
	"pump": {"name": "Насосная", "r": [30, 3, 38, 6], "y": 0.0, "h": 3.0,
		"floor": "concrete", "wall": "brick_dark", "ceil": "concrete", "reverb": [0.3, 0.15]},
	"stairwell": {"name": "Лестница в котельную", "r": [23, 3, 28, 6], "y": 0.0, "h": 3.0,
		"floor": "concrete", "wall": "brick_dark", "ceil": "concrete", "reverb": [0.3, 0.15]},
	"service": {"name": "Технический коридор", "r": [0, 0, 52, 3], "y": 0.0, "h": 3.0,
		"floor": "concrete", "wall": "brick_dark", "wall_low": "peeling", "low": 1.2, "ceil": "concrete", "reverb": [0.55, 0.2]},

	"f_lock": {"name": "Раздевальня (жен.)", "r": [38, 20, 48, 30], "y": 0.0, "h": 3.4,
		"floor": "tile_floor2", "wall": "plaster", "wall_low": "paint_blue", "low": 1.6, "ceil": "plaster", "reverb": [0.45, 0.2]},
	"f_dry": {"name": "Сушуарная", "r": [48, 20, 52, 24], "y": 0.0, "h": 3.4,
		"floor": "tile_floor2", "wall": "plaster", "wall_low": "paint_blue", "low": 1.6, "ceil": "plaster", "reverb": [0.3, 0.15]},
	"f_attend": {"name": "Комната банщицы", "r": [48, 24, 52, 30], "y": 0.0, "h": 3.0,
		"floor": "linoleum", "wall": "wallpaper", "ceil": "plaster", "reverb": [0.15, 0.05], "safe": true},
	"f_wash": {"name": "Мыльная (жен.)", "r": [38, 9, 52, 20], "y": 0.0, "h": 4.4,
		"floor": "tile_floor", "wall": "plaster_dmg", "wall_low": "tile_wall", "low": 2.4, "ceil": "plaster_dmg",
		"wet": true, "reverb": [0.85, 0.45]},
	"f_steam": {"name": "Парильня (жен.)", "r": [44, 3, 52, 9], "y": 0.0, "h": 3.0,
		"floor": "planks_dark", "wall": "planks_dark", "ceil": "planks_dark", "wet": true, "reverb": [0.25, 0.1]},
	"f_shower": {"name": "Душевая (жен.)", "r": [38, 3, 44, 9], "y": 0.0, "h": 3.4,
		"floor": "tile_floor", "wall": "tile_wall", "ceil": "plaster_dmg", "wet": true, "reverb": [0.6, 0.45]},

	# ---------- подвал ----------
	"b_stairs": {"name": "Лестница в котельную", "r": [24, -7, 26.5, 0], "y": BASE_Y, "h": 7.5,
		"floor": "concrete", "wall": "brick_dark", "ceil": "concrete", "reverb": [0.4, 0.2], "stairs": true},
	"collector": {"name": "Коллектор", "r": [30, -7, 32, 12], "y": BASE_Y, "h": 2.0,
		"floor": "concrete_dirty", "wall": "brick_dark", "ceil": "concrete", "water": 0.16, "reverb": [0.7, 0.5]},
	"boiler": {"name": "Котельная", "r": [16, -18, 32, -7], "y": BASE_Y, "h": 4.2,
		"floor": "concrete_dirty", "wall": "brick_dark", "ceil": "concrete", "water": 0.12, "reverb": [0.8, 0.35]},
	"stoker": {"name": "Комната истопника", "r": [10, -14, 16, -8], "y": BASE_Y, "h": 3.0,
		"floor": "planks", "wall": "plaster", "wall_low": "paint_green", "low": 1.4, "ceil": "plaster",
		"reverb": [0.2, 0.05], "safe": true},
	"meter": {"name": "Водомерный узел", "r": [10, -18, 16, -14], "y": BASE_Y, "h": 3.0,
		"floor": "concrete_dirty", "wall": "brick_dark", "ceil": "concrete", "water": 0.14, "reverb": [0.4, 0.3]},
	"coal": {"name": "Угольный бункер", "r": [32, -18, 38, -11], "y": BASE_Y, "h": 4.2,
		"floor": "coal", "wall": "brick_dark", "ceil": "concrete", "reverb": [0.35, 0.1]},
	"banya": {"name": "Сруб", "r": [32, -11, 38, -5], "y": BASE_Y, "h": 2.4,
		"floor": "planks_dark", "wall": "logs", "ceil": "planks_dark", "reverb": [0.15, 0.05]},
}

## Проёмы: [комната A, комната B, точка центра (x, z), ширина, высота, тип двери, id]
## тип: "" — просто проём, "wood", "wood2" (двустворчатая), "steel", "grate"
const DOORS := [
	["lobby", "outside", Vector2(26, 30), 1.8, 2.4, "entrance", "d_entrance"],
	["lobby", "m_lock", Vector2(14, 26.5), 1.3, 2.2, "wood", "d_lobby_m"],
	["lobby", "f_lock", Vector2(38, 26.5), 1.3, 2.2, "wood", "d_lobby_f"],
	["lobby", "admin", Vector2(20, 23), 1.1, 2.2, "wood", "d_lobby_admin"],
	["admin", "office", Vector2(19, 20), 1.0, 2.1, "wood", "d_office"],
	["admin", "linen", Vector2(24.5, 20), 1.0, 2.1, "wood", "d_linen"],
	["admin", "barber", Vector2(29.5, 20), 1.0, 2.1, "wood", "d_barber"],
	["admin", "buffet", Vector2(34, 20), 1.0, 2.1, "wood", "d_buffet"],
	["m_lock", "m_wait", Vector2(4, 23), 1.6, 2.4, "", ""],
	["m_wait", "m_util", Vector2(2, 26), 1.0, 2.1, "wood", "d_m_util"],
	["m_lock", "m_wash", Vector2(6.5, 20), 1.3, 2.3, "wood", "d_m_wash_a"],
	["m_lock", "m_wash", Vector2(12, 20), 1.1, 2.3, "wood", "d_m_wash_b"],
	["m_wash", "m_steam", Vector2(4, 9), 0.9, 2.0, "wood", "d_m_steam"],
	["m_wash", "m_shower", Vector2(11, 9), 2.0, 2.6, "", ""],
	["m_shower", "service", Vector2(11, 3), 1.0, 2.1, "steel", "d_code_m"],
	["m_wash", "pool", Vector2(14, 13), 1.6, 2.4, "wood2", "d_pool_m"],
	["pool", "f_wash", Vector2(38, 13), 1.6, 2.4, "wood2", "d_pool_f"],
	["pool", "pump", Vector2(34, 6), 1.0, 2.1, "steel", "d_pump_pool"],
	["pump", "service", Vector2(34, 3), 1.0, 2.1, "steel", "d_pump_service"],
	["stairwell", "service", Vector2(25.5, 3), 3.0, 2.6, "", ""],
	["f_wash", "f_steam", Vector2(48, 9), 0.9, 2.0, "wood", "d_f_steam"],
	["f_wash", "f_shower", Vector2(41, 9), 2.0, 2.6, "", ""],
	["f_shower", "service", Vector2(41, 3), 1.0, 2.1, "steel", "d_f_service"],
	["f_lock", "f_wash", Vector2(40, 20), 1.1, 2.3, "wood", "d_f_wash_a"],
	["f_lock", "f_wash", Vector2(45.5, 20), 1.3, 2.3, "wood", "d_f_wash_b"],
	["f_lock", "f_dry", Vector2(48, 22), 1.6, 2.4, "", ""],
	["f_lock", "f_attend", Vector2(48, 27), 1.0, 2.1, "wood", "d_attend"],
	["service", "b_stairs", Vector2(25.25, 0), 1.6, 2.2, "grate", "d_grate"],
	# подвал
	["b_stairs", "boiler", Vector2(25.25, -7), 1.8, 2.4, "", ""],
	["collector", "boiler", Vector2(31, -7), 1.6, 1.9, "", ""],
	["boiler", "stoker", Vector2(16, -11), 1.0, 2.1, "wood", "d_stoker"],
	["boiler", "meter", Vector2(16, -16), 1.0, 2.1, "steel", "d_meter"],
	["boiler", "coal", Vector2(32, -14.5), 2.0, 2.6, "", ""],
	["boiler", "banya", Vector2(32, -8), 0.8, 1.7, "wood", "d_banya"],
]

## Окна (матовое стекло): [комната, сторона "n/s/e/w", центр по стене, низ, ширина, высота]
const WINDOWS := [
	["lobby", "s", 19.0, 1.0, 2.2, 2.0], ["lobby", "s", 33.0, 1.0, 2.2, 2.0],
	["m_lock", "s", 9.0, 1.6, 2.0, 1.4], ["f_lock", "s", 43.0, 1.6, 2.0, 1.4],
	["m_wait", "w", 23.0, 1.6, 1.6, 1.4], ["m_util", "w", 28.0, 1.8, 1.0, 0.8],
	["f_dry", "e", 22.0, 1.6, 1.6, 1.4], ["f_attend", "e", 27.0, 1.6, 1.4, 1.2],
	["m_wash", "w", 12.0, 2.4, 1.6, 1.6], ["m_wash", "w", 17.0, 2.4, 1.6, 1.6],
	["f_wash", "e", 12.0, 2.4, 1.6, 1.6], ["f_wash", "e", 17.0, 2.4, 1.6, 1.6],
	["m_steam", "w", 6.0, 1.8, 0.6, 0.5], ["f_steam", "e", 6.0, 1.8, 0.6, 0.5],
]

## Дыры в полу: бассейн и затопленная лестница в вестибюле
const POOL_BASIN := Rect2(19, 8.5, 14, 6)      # x 19..33, z 8.5..14.5
const POOL_SHALLOW := -1.2
const POOL_DEEP := -2.2
const POOL_SLOPE := Vector2(25, 27)             # по x: от мелкой части к глубокой
const LOBBY_STAIRS := Rect2(33, 23.2, 3, 3.2)  # затопленная лестница вниз

const OUTSIDE_SIZE := Rect2(-12, -24, 76, 80)
