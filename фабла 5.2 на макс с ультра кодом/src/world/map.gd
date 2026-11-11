class_name Map
extends RefCounted
## Карта станции «Тихая»: координаты в метрах. Север = −Z, восток = +X. Дом стоит в нуле.

const HUB := Vector3(7.6, 0, 1.6)                 # развязка лееров у крыльца
const J1 := Vector3(7.6, 0, 5.4)                  # развилка: на мачту и на площадку
const HOUSE_MIN := Vector3(-5.0, 0, -3.2)
const HOUSE_MAX := Vector3(5.0, 2.5, 3.2)
const HOUSE_DOOR := Vector3(5.0, 0, 1.6)
const SHED_MIN := Vector3(30.0, 0, -1.0)
const SHED_MAX := Vector3(34.4, 2.4, 4.2)
const SHED_DOOR := Vector3(30.0, 0, 1.6)
const METEO := Vector3(26.0, 0, -56.0)            # центр метеоплощадки 12×12
const METEO_GATE := Vector3(26.0, 0, -50.0)
const METEO_WGATE := Vector3(20.0, 0, -56.0)
const DEPOT := Vector3(80.0, 0, 22.0)
const MAST := Vector3(-83.0, 0, 13.5)
const HUT_MIN := Vector3(-80.6, 0, 12.3)          # фидерная будка
const HUT_MAX := Vector3(-78.2, 2.2, 14.7)
const PAD := Vector3(12.0, 0, 86.0)
const BALOK := Vector3(-48.0, 0, -89.5)           # старая станция 1961
const WOODPILE := Vector3(5.7, 0, -2.2)

## Ломаные лееров. Буквы — как на табличках.
const LINES := {
	"A": [Vector3(7.6, 0, 1.6), Vector3(7.6, 0, -4.6), Vector3(26.0, 0, -49.3)],
	"B": [Vector3(7.6, 0, 1.6), Vector3(29.3, 0, 1.6)],
	"C": [Vector3(29.3, 0, 1.6), Vector3(29.3, 0, 5.2), Vector3(35.3, 0, 5.2), Vector3(77.6, 0, 21.4)],
	"D": [Vector3(7.6, 0, 5.4), Vector3(-6.5, 0, 5.4), Vector3(-77.5, 0, 13.5)],
	"E": [Vector3(7.6, 0, 1.6), Vector3(7.6, 0, 5.4), Vector3(11.6, 0, 78.4)],
	"F": [Vector3(19.4, 0, -56.0), Vector3(-44.4, 0, -87.2)],
	"X": [Vector3(9.47, 0, 39.55), Vector3(-20.0, 0, 66.0)],
}
const TITLES := {"A": "МЕТЕОПЛОЩАДКА", "B": "ДИЗЕЛЬНАЯ", "C": "СКЛАД ГСМ", "D": "МАЧТА", "E": "ПЛОЩАДКА", "F": "СТ. СТАНЦИЯ", "X": ""}
