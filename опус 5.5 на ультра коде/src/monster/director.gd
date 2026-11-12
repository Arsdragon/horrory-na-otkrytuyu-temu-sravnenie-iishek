class_name Director
extends Node
## Режиссёр: решает, когда Хозяйка выходит (сначала стучат трубы), когда уходит,
## отвечает на плеск воды, подкидывает мелкие пугалки и меняет музыку.

var w: World
var hoz: Hozyayka
var rest := 60.0
var knock_t := -1.0
var pending := Vector3.ZERO
var amb_t := 25.0
var glimpse_t := 150.0
var water_cool := 0.0
var far_t := 0.0
var ghost: HozBody = null
var ghost_t := 0.0
var spawns := 0


func setup(world: Node3D) -> void:
	w = world
	hoz = w.monster
	rest = _rest_time() * 0.5


func danger() -> int:
	return int(Game.getf("danger", 0))


func _rest_time() -> float:
	var d := danger()
	return lerpf(140.0, 40.0, clampf(d / 3.0, 0.0, 1.0)) * randf_range(0.75, 1.25)


func _process(delta: float) -> void:
	if w == null or not w.ready_done or Game.player == null:
		return
	water_cool = maxf(0.0, water_cool - delta)
	if Game.cheats.get("no_monster", false):
		if hoz.state != Hozyayka.S.GONE:
			hoz.vanish()
		knock_t = -1.0
		_music()
		return
	var d := danger()
	if hoz.state == Hozyayka.S.GONE:
		if knock_t >= 0.0:
			knock_t -= delta
			if knock_t < 0.0:
				hoz.aggression = 0.8 + d * 0.2
				hoz.emerge(pending)
				spawns += 1
		elif d > 0 and not Game.flag("dir_hold"):
			rest -= delta
			if rest <= 0.0:
				if not spawn_near_player():
					rest = 8.0
		_ambient(delta)
	else:
		_active(delta)
	_ghost(delta)
	_music()


func _active(delta: float) -> void:
	var limit := lerpf(70.0, 150.0, clampf(danger() / 3.0, 0.0, 1.0))
	var pl: Player = Game.player
	var dist := hoz.global_position.distance_to(pl.global_position)
	if dist > 32.0 and hoz.state == Hozyayka.S.ROAM:
		far_t += delta
	else:
		far_t = 0.0
	if (hoz.active_t > limit and hoz.state == Hozyayka.S.ROAM) or far_t > 25.0:
		hoz.submerge()
		rest = _rest_time()
		far_t = 0.0


## Выпустить её из трапа в 9–26 м от игрока, вне его взгляда. Сначала трубы стучат.
func spawn_near_player(min_d := 9.0, max_d := 26.0, knock := 3.5) -> bool:
	var pl: Player = Game.player
	var best := []
	for dr in w.drains:
		var p: Vector3 = dr["pos"]
		var d := p.distance_to(pl.global_position)
		if d < min_d or d > max_d:
			continue
		if absf(p.y - pl.global_position.y) > 3.0:
			continue
		if _visible(p + Vector3.UP * 1.0):
			continue
		if w.is_safe(p):
			continue
		best.append(p)
	if best.is_empty():
		return false
	schedule(best[randi() % best.size()], knock)
	return true


func schedule(p: Vector3, knock := 3.5) -> void:
	pending = p
	knock_t = knock
	Snd.play("pipe_knock", 0.0, randf_range(0.95, 1.05), "Amb")
	if Game.player:
		Game.player.flick(1.2)


func _visible(p: Vector3) -> bool:
	var pl: Player = Game.player
	var eye := pl.eye_pos()
	var to := p - eye
	if pl.look_dir().dot(to.normalized()) < 0.35:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, p, 1)
	return w.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func on_noise(pos: Vector3, r: float, kind: String) -> void:
	if hoz == null or Game.cheats.get("no_monster", false):
		return
	if danger() <= 0 or Game.flag("dir_hold"):
		return
	# плеск: она «слышит воду» даже из труб
	if hoz.state == Hozyayka.S.GONE and knock_t < 0.0 and water_cool <= 0.0:
		var wet := w.water_depth(pos) > 0.08
		if kind == "water" or (wet and r >= 8.0) or kind in ["throw", "slam", "scream"] or (kind == "work" and danger() >= 2):
			water_cool = 30.0
			var bestd := 99.0
			var bp := Vector3.ZERO
			for dr in w.drains:
				var p: Vector3 = dr["pos"]
				var d := p.distance_to(pos)
				if d > 5.0 and d < bestd and absf(p.y - pos.y) < 3.0 and not _visible(p + Vector3.UP):
					bestd = d
					bp = p
			if bestd < 24.0:
				schedule(bp, 2.5)


# ---------------------------------------------------------------- мелкие пугалки

func _ambient(delta: float) -> void:
	amb_t -= delta
	if amb_t > 0.0:
		return
	amb_t = randf_range(22.0, 55.0)
	var pl: Player = Game.player
	if pl == null or pl.current_room == "outside":
		return
	var away := pl.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(6.0, 12.0)
	away.y = pl.global_position.y + 1.0
	var r := randi() % 7
	match r:
		0:
			Snd.at("drip_burst", away, -2.0, randf_range(0.9, 1.1), 20.0)
		1:
			Snd.play("pipe_creak", -6.0, randf_range(0.8, 1.1), "Amb")
		2:
			Snd.at("basin_drop", away, 0.0, randf_range(0.9, 1.1), 25.0)
		3:
			if danger() > 0:
				Snd.at("hoz_whisper", away, -14.0, randf_range(0.9, 1.0), 18.0, "Voice")
		4:
			_door_creak()
		5:
			_tap_blip()
		6:
			Snd.at("hair_wet", away, -8.0, 1.0, 12.0)


func _door_creak() -> void:
	var pl: Player = Game.player
	for d: Door in w.doors.values():
		var dist := d.global_position.distance_to(pl.global_position)
		if dist > 5.0 and dist < 16.0 and not d.locked and d.target < 0.5 and not _visible(d.center()):
			d.set_open(0.35, false, true)
			return


func _tap_blip() -> void:
	var pl: Player = Game.player
	for t in w.taps:
		var dist: float = (t as Node3D).global_position.distance_to(pl.global_position)
		if dist > 4.0 and dist < 14.0 and not t.is_running():
			t.blip(1.5)
			return


## Силуэт в дальнем проёме — на секунду.
func _ghost(delta: float) -> void:
	if ghost and ghost.visible:
		ghost_t -= delta
		var pl: Player = Game.player
		var to := ghost.global_position + Vector3.UP * 1.6 - pl.eye_pos()
		if ghost_t <= 0.0 or (pl.look_dir().dot(to.normalized()) > 0.97 and ghost_t < 0.9):
			ghost.visible = false
		return
	if danger() < 1 or hoz.state != Hozyayka.S.GONE or knock_t >= 0.0:
		return
	glimpse_t -= delta
	if glimpse_t > 0.0:
		return
	glimpse_t = randf_range(140.0, 260.0)
	var pl: Player = Game.player
	for d: Door in w.doors.values():
		var c := d.global_position
		var dist := c.distance_to(pl.global_position)
		if dist < 9.0 or dist > 20.0 or absf(c.y - pl.global_position.y) > 1.5:
			continue
		if not d.is_open() and d.kind != "":
			continue
		if not _visible(c + Vector3.UP * 1.4):
			continue
		if ghost == null:
			ghost = HozBody.new()
			w.add_child(ghost)
		ghost.visible = true
		ghost.global_position = c
		var dir := pl.global_position - c
		ghost.rotation.y = atan2(-dir.x, -dir.z)
		ghost.floor_y = c.y
		ghost.play("idle", 0.0, 0.3)
		ghost.rig.stoop = 0.8
		ghost.rig.head_tilt = 0.7
		ghost_t = 1.6
		Snd.play("sting_soft", -8.0)
		return


# ---------------------------------------------------------------- музыка

func _music() -> void:
	var pl: Player = Game.player
	if pl == null or Game.flag("music_lock"):
		return
	var m := ""
	if hoz.state != Hozyayka.S.GONE and hoz.state != Hozyayka.S.SCRIPT:
		var dist := hoz.global_position.distance_to(pl.global_position)
		if hoz.state == Hozyayka.S.RUSH or (dist < 6.0 and hoz.state == Hozyayka.S.SEARCH):
			m = "mus_chase"
		elif dist < 22.0:
			m = "mus_tension"
	Snd.music(m, -4.0 if m == "mus_chase" else -8.0, 1.2 if m == "mus_chase" else 4.0)
