class_name Bot
extends RefCounted
## Автотест: сам проходит этапы подряд (телепортируется, жмёт, прячется) и пишет журнал.
##   --bot --stage=n1_wake [--until=n3_wake] [--speed=5]
## Смерть отключена не полностью: бот выполняет правила, чтобы проверить и их.

var d: Director
var p: Player:
	get:
		return d.p
var W: World:
	get:
		return d.world


func _init(dir: Director) -> void:
	d = dir


func run(first: String) -> void:
	Engine.time_scale = Cfg.argf("speed", 5.0)
	var cur := first
	while true:
		print("BOT stage ", cur)
		if Cfg.arg("until") == cur:
			print("BOT DONE until ", cur)
			d.get_tree().quit()
			return
		if has_method("b_" + cur):
			await call("b_" + cur)
		var t0 := d.clock
		while d.stage == cur:
			if d.clock - t0 > 240.0:
				print("BOT STUCK at ", cur, " zone=", d.zone_id(), " pos=", p.global_position)
				d.get_tree().quit()
				return
			await d.tick
		cur = d.stage


func w(t: float) -> void:
	await d.sleep(t)


func tp(place: String) -> void:
	W.goto(place)
	await d.sleep(0.4)


func at(pos: Vector3, yaw_deg := 0.0) -> void:
	p.teleport(pos, yaw_deg)
	await d.sleep(0.4)


func a(id: String) -> void:
	G.act(id)
	await d.sleep(0.2)


func read3() -> void:
	p.set_lamp(true, true)
	await a("read_t")
	await a("read_w")
	await a("read_s")


func radio() -> void:
	await tp("radio")
	await a("radio")
	G.radio_ui.freq = RadioUi.DIKSON
	await w(1.0)
	d.acted["tx"] = true
	await d.until(func() -> bool: return not G.radio_ui.is_open)


func sleep_now() -> void:
	await d.until(func() -> bool: return d.allow.get("bed", false))
	await a("bed")


func getup() -> void:
	await w(1.0)
	d.acted["getup"] = true
	await w(1.0)
	d.acted.erase("getup")


func b_n1_wake() -> void:
	await getup()
	await tp("hub")
	await w(1.0)
	await at(Vector3(13.0, 0, -18.0))
	await w(1.0)
	await tp("booth")
	await read3()


func b_n1_back() -> void:
	await at(Vector3(18.0, 0, -30.0), 180.0)
	await w(1.5)
	await at(Vector3(9.0, 0, -10.0), 180.0)
	await w(1.5)
	await tp("main")


func b_n1_radio() -> void:
	await radio()
	p.carrying = "wood"
	await a("stove")
	await sleep_now()


func b_n2_wake() -> void:
	await getup()
	await tp("shed_in")
	await a("gen_start")
	await a("jerry")


func b_n2_depot() -> void:
	await tp("depot_in")
	await a("pump")
	p.set_lamp(true, true)
	p.yaw += PI
	await w(2.0)


func b_n2_gen() -> void:
	await at(W.ropes.point_at("C", 28.0) + Vector3(0, 0, 0.6))
	await w(1.5)
	await tp("shed_in")
	await a("gen_fuel")
	for i in 3:
		await a("gen_start")
		await w(1.0)


func b_n2_site() -> void:
	await tp("booth")
	await read3()


func b_n2_pass() -> void:
	await at(W.ropes.point_at("A", 36.0) + Vector3(0.5, 0, 0), 180.0)
	p.set_lamp(false, true)
	p.try_grip()
	await d.until(func() -> bool: return d.e.state != Entity.S.HIDDEN)
	print("BOT entity appeared, hiding")
	await d.until(func() -> bool: return d.e.state == Entity.S.HIDDEN)
	print("BOT entity passed")
	await w(3.0)
	await tp("main")


func b_n2_radio() -> void:
	await radio()
	await sleep_now()


func b_n3_wake() -> void:
	await getup()
	await tp("radio")
	await d.until(func() -> bool: return d.allow.get("cable", false))
	await tp("store")
	await a("cable")


func b_n3_mast() -> void:
	await at(W.ropes.point_at("D", 50.0) + Vector3(0, 0, 0.5), 90.0)
	await w(2.0)
	await tp("hut_in")
	var it: Interactable = W.things["feeder"]
	for i in 10:
		it.progress = float(i + 1) * 0.1
		await w(1.2)
	await a("feeder")


func b_n3_repaired() -> void:
	await at(W.ropes.point_at("D", 61.0) + Vector3(0, 0, 0.5), -90.0)
	await w(4.0)
	await at(W.ropes.point_at("D", 48.0), -90.0)
	await w(3.0)
	await at(W.ropes.point_at("D", 30.0) + Vector3(0, 0, 0.5), -90.0)
	await w(1.5)
	await tp("main")


func b_n3_radio() -> void:
	await radio()
	await sleep_now()


func b_n3_night() -> void:
	await w(20.0)
	await getup()
	await tp("vest")


func b_n4_wake() -> void:
	await getup()
	await tp("vest")
	await w(1.0)
	await tp("bed")
	await a("nstand")
	await w(1.0)
	G.note_view.close()
	await w(1.0)
	await tp("balok_in")


func b_n4_balok() -> void:
	await a("nz")
	await a("balok_stove")
	await a("hatch")


func b_n4_cellar() -> void:
	await w(3.0)
	await tp("cellar_end")
	await w(1.0)
	await a("flaregun")
	await w(7.0)
	await tp("cellar")
	await a("ladder_up")


func b_n4_flee() -> void:
	await w(2.0)
	await at(Vector3(-40.0, 0, -86.0))
	await w(6.0)
	await tp("main")


func b_n4_home() -> void:
	await tp("vest")
	(W.doors["house"] as Door).set_open(false, true)
	await a("bar")
	await radio()


func b_n4_siege() -> void:
	await tp("bed")
	d.acted["bot_breath"] = true
	d.acted["walkie_off"] = true
	await d.until(func() -> bool: return d.allow.get("hide", false))
	await w(1.0)
	await a("bed")


func b_n5_wake() -> void:
	await w(2.0)
	await at(W.ropes.point_at("E", 38.0) + Vector3(0.6, 0, 0), 180.0)
	await w(1.5)
	await tp("pad")


func b_n5_pad() -> void:
	await w(1.0)
	for i in 3:
		await a("barrel_%d" % i)
		await w(1.0)


func b_n5_final() -> void:
	await tp("pad_in")
	await w(16.0)
	d.acted["bot_fire"] = true
	await d.until(func() -> bool: return d.allow.get("heli", false))
	await w(1.0)
	await a("heli_door")
