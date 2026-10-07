class_name HouseFly
extends Node3D
## Simplified fly — harasses head, lands on timer, dies in the fan.

signal changed(landed: bool, squashed: bool)

enum Mode { OFF, RESPAWN, FLY, LAND, DEAD }

var enabled: bool = false
var mode: Mode = Mode.OFF
var landed: bool = false
var _timer: float = 0.0
var _respawn: float = 40.0
var _vel: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.1)
	_mesh.material_override = mat
	add_child(_mesh)
	visible = false
	set_process(true)


func arm(delay: float = -1.0) -> void:
	enabled = true
	mode = Mode.RESPAWN
	_respawn = delay if delay > 0.0 else randf_range(35.0, 75.0)
	_timer = 0.0
	landed = false
	visible = false


func hide_fly() -> void:
	enabled = false
	mode = Mode.OFF
	landed = false
	visible = false
	changed.emit(false, false)


func tick(dt: float, game_over: bool, head: Vector3, fan_on: bool, fan_pos: Vector3, timer_pos: Vector3) -> Dictionary:
	if game_over or not enabled:
		if mode != Mode.OFF:
			hide_fly()
		return {"landed": false, "alive": false, "squashed": false}

	_timer += dt
	match mode:
		Mode.RESPAWN:
			_respawn -= dt
			if _respawn <= 0.0:
				_spawn(head)
		Mode.FLY:
			_chase(dt, head, timer_pos)
			if fan_on and global_position.distance_to(fan_pos) < 0.35:
				_kill()
				return {"landed": false, "alive": false, "squashed": true}
			if timer_pos != Vector3.ZERO and global_position.distance_to(timer_pos) < 0.08:
				mode = Mode.LAND
				landed = true
				global_position = timer_pos + Vector3(0, 0.01, 0)
				changed.emit(true, false)
		Mode.LAND:
			if fan_on:
				_kill()
				return {"landed": false, "alive": false, "squashed": true}
			# Stay until disturbed — buzz off after a while if player waits
			if _timer > 12.0:
				mode = Mode.FLY
				landed = false
				_timer = 0.0
				changed.emit(false, false)
		Mode.DEAD:
			if _timer > 1.2:
				mode = Mode.RESPAWN
				_respawn = randf_range(7.0, 12.0)
				visible = false
	return {"landed": landed, "alive": mode == Mode.FLY or mode == Mode.LAND, "squashed": false}


func _kill() -> void:
	mode = Mode.DEAD
	_timer = 0.0
	landed = false
	Sound.squish()
	changed.emit(false, true)
	scale = Vector3(1.4, 0.25, 1.4)


func _spawn(head: Vector3) -> void:
	mode = Mode.FLY
	_timer = 0.0
	landed = false
	visible = true
	scale = Vector3.ONE
	var side := -1.0 if randf() < 0.5 else 1.0
	global_position = head + Vector3(side * randf_range(1.2, 2.0), randf_range(0.2, 0.8), randf_range(-1.0, 1.0))
	_vel = Vector3(-side * 1.2, -0.1, randf_range(-0.3, 0.3))
	changed.emit(false, false)


func _chase(dt: float, head: Vector3, timer_pos: Vector3) -> void:
	var target := head + Vector3(0, 0.05, 0)
	if timer_pos != Vector3.ZERO and _timer > 4.0:
		target = timer_pos
	var desired := (target - global_position)
	var dist := desired.length()
	if dist > 0.001:
		desired = desired.normalized() * 1.6
	_vel = _vel.lerp(desired, clampf(dt * 2.5, 0.0, 1.0))
	global_position += _vel * dt
	if global_position.y < 0.05:
		global_position.y = 0.05
