class_name Build
extends RefCounted
## Сборка станции: вызывает строителей построек и расставляет точки для телепорта.


static func all(w: World) -> void:
	BuildHouse.build(w)
	BuildSites.build(w)
	# указатели у начала и у конца каждого леера
	var letter := {"A": "А", "B": "Б", "C": "В", "D": "Г", "E": "Д"}
	for id in ["A", "B", "C", "D", "E"]:
		var pts: Array = Map.LINES[id]
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[1]
		var d := (b - a).normalized()
		w.ropes.add_sign(a + d * 1.4 + d.cross(Vector3.UP) * 0.35, rad_to_deg(atan2(-d.x, -d.z)), "«%s» %s" % [letter[id], Map.TITLES[id]])
		var z: Vector3 = pts[pts.size() - 1]
		var y: Vector3 = pts[pts.size() - 2]
		var d2 := (y - z).normalized()
		w.ropes.add_sign(z + d2 * 1.4 + d2.cross(Vector3.UP) * 0.35, rad_to_deg(atan2(-d2.x, -d2.z)), "ДОМ")
	# точки (yaw: 0 — на север, −90 — на восток, 180 — на юг, 90 — на запад)
	w.places["hub"] = [Map.HUB + Vector3(0.6, 0, 0.5), 0.0]
	w.places["rope_a"] = [Vector3(13.0, 0, -18.0), -22.0]
	w.places["house_out"] = [Vector3(20.0, 0, 6.0), 100.0]
	w.places["meteo"] = [Map.METEO_GATE + Vector3(0, 0, 1.5), 0.0]
	w.places["shed"] = [Map.SHED_DOOR + Vector3(-1.5, 0, 0), -90.0]
	w.places["depot"] = [Map.DEPOT + Vector3(-3.5, 0, -0.5), -90.0]
	w.places["mast"] = [Vector3(-75.5, 0, 13.3), 90.0]
	w.places["pad"] = [Map.PAD + Vector3(0, 0, -7.0), 180.0]
	w.places["balok"] = [Vector3(-42.5, 0, -86.5), 60.0]
