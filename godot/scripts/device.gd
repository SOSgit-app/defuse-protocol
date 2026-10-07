class_name BombDevice
extends Node3D
## Physical bomb case — port of public/js/three/device.js (wires-first slice)

signal module_action(module_id: String, action: Dictionary)

const CASE_W := 1.14
const CASE_H := 0.16
const CASE_D := 0.8
const SLOT := 0.3
const PLATE_H := 0.024
const COLS := [-0.36, 0.0, 0.36]
const ROWS := [-0.195, 0.195]
const TIMER_SLOT := 1

var over: bool = false
var won: bool = false
var max_strikes: int = 3
var _entries: Dictionary = {}
var _timer_label: Label3D
var _serial_label: Label3D
var _strike_leds: Array[MeshInstance3D] = []
var _last_timer_text: String = ""
var _timer_bay: Node3D
var _pest: MeshInstance3D


func build(payload: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_entries.clear()
	_strike_leds.clear()
	_timer_bay = null
	_pest = null
	over = false
	won = false
	max_strikes = int(payload.get("max_strikes", 3))

	_build_case(str(payload.get("serial", "??????")))
	_build_timer(int(payload.get("time_ms", 0)), max_strikes, int(payload.get("strikes", 0)))

	var mods: Array = payload.get("modules", [])
	var slots: Array = [0, 2, 4] if mods.size() <= 3 else [0, 2, 3, 4, 5]
	for i in mods.size():
		_build_module_bay(mods[i], int(slots[i]))

	var used := {TIMER_SLOT: true}
	for i in mods.size():
		used[int(slots[i])] = true
	for i in 6:
		if not used.has(i):
			_build_blank(i)


func update_module(module_id: String, view: Dictionary) -> void:
	if not _entries.has(module_id):
		return
	var e: Dictionary = _entries[module_id]
	if e.builder and e.builder.has_method("update_view"):
		e.builder.update_view(view)


func mark_solved(module_id: String) -> void:
	if not _entries.has(module_id):
		return
	var e: Dictionary = _entries[module_id]
	e.solved = true
	if e.led_mat:
		e.led_mat.emission_enabled = true
		e.led_mat.emission = Color(0.22, 0.85, 0.54)
		e.led_mat.emission_energy_multiplier = 1.8
	if e.builder and e.builder.has_method("mark_done"):
		e.builder.mark_done()


func set_timer(ms: int) -> void:
	var total := maxi(0, int(ceil(float(ms) / 1000.0)))
	var text := "%d:%02d" % [total / 60, total % 60]
	if over:
		text = "SAFE" if won else "BOOM"
	if text == _last_timer_text:
		return
	_last_timer_text = text
	if _timer_label:
		_timer_label.text = text
		if over:
			_timer_label.modulate = Color(0.22, 0.85, 0.54) if won else Color(1.0, 0.13, 0.2)
		elif ms < 60000:
			_timer_label.modulate = Color(1.0, 0.3, 0.37)
		else:
			_timer_label.modulate = Color(0.22, 0.85, 0.54)


func set_strikes(n: int) -> void:
	for i in _strike_leds.size():
		var mat := _strike_leds[i].material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 2.2 if i < n else 0.0


func game_over(p_won: bool) -> void:
	over = true
	won = p_won
	set_pest(false)
	set_timer(0)
	for e in _entries.values():
		if e.builder and e.builder.has_method("mark_done"):
			e.builder.mark_done()


func timer_world_pos() -> Vector3:
	if _timer_bay:
		return _timer_bay.global_position + Vector3(0, 0.07, -0.02)
	return global_position + Vector3(0, 0.22, -0.2)


func set_pest(on: bool) -> void:
	if _pest == null:
		return
	_pest.visible = on


func _slot_pos(i: int) -> Vector3:
	return Vector3(COLS[i % 3], 0.0, ROWS[i / 3])


func _build_case(serial: String) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CASE_W, CASE_H, CASE_D)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.29, 0.314, 0.361)
	mat.metallic = 0.85
	mat.roughness = 0.38
	body.material_override = mat
	body.position.y = CASE_H * 0.5
	add_child(body)

	_serial_label = Label3D.new()
	_serial_label.text = "SN %s" % serial
	_serial_label.font_size = 48
	_serial_label.pixel_size = 0.0012
	_serial_label.modulate = Color(0.05, 0.05, 0.05)
	_serial_label.outline_modulate = Color(0.72, 0.70, 0.63)
	_serial_label.outline_size = 6
	_serial_label.position = Vector3(0, CASE_H * 0.5, CASE_D * 0.5 + 0.01)
	add_child(_serial_label)


func _build_timer(time_ms: int, p_max_strikes: int, strikes: int) -> void:
	var bay := Node3D.new()
	var pos := _slot_pos(TIMER_SLOT)
	bay.position = Vector3(pos.x, CASE_H, pos.z)
	add_child(bay)
	_timer_bay = bay

	_pest = MeshInstance3D.new()
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.01
	pmesh.height = 0.02
	_pest.mesh = pmesh
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.05, 0.05, 0.07)
	_pest.material_override = pmat
	_pest.position = Vector3(0.04, 0.07, -0.02)
	_pest.visible = false
	bay.add_child(_pest)

	var housing := MeshInstance3D.new()
	var hmesh := BoxMesh.new()
	hmesh.size = Vector3(SLOT, 0.06, SLOT)
	housing.mesh = hmesh
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.08, 0.09, 0.11)
	hmat.metallic = 0.5
	hmat.roughness = 0.4
	housing.material_override = hmat
	housing.position.y = 0.03
	bay.add_child(housing)

	_timer_label = Label3D.new()
	_timer_label.font_size = 96
	_timer_label.pixel_size = 0.0014
	_timer_label.position = Vector3(0, 0.062, -0.04)
	_timer_label.rotation_degrees = Vector3(-90, 0, 0)
	bay.add_child(_timer_label)

	_strike_leds.clear()
	var x0 := -((p_max_strikes - 1) / 2.0) * 0.05
	for i in p_max_strikes:
		var led := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.011
		sphere.height = 0.022
		led.mesh = sphere
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.11, 0.05, 0.06)
		lmat.emission_enabled = true
		lmat.emission = Color(1.0, 0.13, 0.2)
		lmat.emission_energy_multiplier = 0.0
		led.material_override = lmat
		led.position = Vector3(x0 + i * 0.05, 0.065, 0.095)
		bay.add_child(led)
		_strike_leds.append(led)

	set_timer(time_ms)
	set_strikes(strikes)


func _build_module_bay(mod: Dictionary, slot: int) -> void:
	var bay := Node3D.new()
	var pos := _slot_pos(slot)
	bay.position = Vector3(pos.x, CASE_H, pos.z)
	add_child(bay)

	var plate := MeshInstance3D.new()
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(SLOT, PLATE_H, SLOT)
	plate.mesh = pmesh
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.17, 0.21)
	pmat.metallic = 0.4
	pmat.roughness = 0.5
	plate.material_override = pmat
	plate.position.y = PLATE_H * 0.5
	bay.add_child(plate)

	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color(0.06, 0.07, 0.09)
	led_mat.emission_enabled = true
	led_mat.emission = Color(0.22, 0.85, 0.54)
	led_mat.emission_energy_multiplier = 0.0
	var led := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.009
	cmesh.bottom_radius = 0.009
	cmesh.height = 0.012
	led.mesh = cmesh
	led.material_override = led_mat
	led.position = Vector3(0.128, PLATE_H + 0.004, -0.128)
	bay.add_child(led)

	var builder: Node3D = null
	var module_id: String = mod.id
	match str(mod.type):
		"wires":
			var wires := Wires3D.new()
			wires.position.y = PLATE_H
			wires.cut_requested.connect(func(index: int):
				module_action.emit(module_id, {"type": "cut", "index": index})
			)
			wires.build(mod.view)
			bay.add_child(wires)
			builder = wires
		"symbols":
			var symbols := Symbols3D.new()
			symbols.position.y = PLATE_H
			symbols.press_requested.connect(func(glyph: String):
				module_action.emit(module_id, {"type": "press", "glyph": glyph})
			)
			symbols.build(mod.view)
			bay.add_child(symbols)
			builder = symbols
		"memory":
			var memory := Memory3D.new()
			memory.position.y = PLATE_H
			memory.press_requested.connect(func(position: int):
				module_action.emit(module_id, {"type": "press", "position": position})
			)
			memory.build(mod.view)
			bay.add_child(memory)
			builder = memory
		"morse":
			var morse := Morse3D.new()
			morse.position.y = PLATE_H
			morse.tune_requested.connect(func(index: int):
				module_action.emit(module_id, {"type": "tune", "index": index})
			)
			morse.transmit_requested.connect(func():
				module_action.emit(module_id, {"type": "transmit"})
			)
			morse.build(mod.view)
			bay.add_child(morse)
			builder = morse
		"logicgrid":
			var grid := LogicGrid3D.new()
			grid.position.y = PLATE_H
			grid.answer_requested.connect(func(option: String):
				module_action.emit(module_id, {"type": "answer", "option": option})
			)
			grid.build(mod.view)
			bay.add_child(grid)
			if grid.table_prop:
				add_child(grid.table_prop)
			builder = grid
		"ordnance":
			var ord := Ordnance3D.new()
			ord.position.y = PLATE_H
			ord.action_requested.connect(func(action: Dictionary):
				module_action.emit(module_id, action)
			)
			ord.build(mod.view)
			bay.add_child(ord)
			builder = ord
		"comms":
			var comms := Comms3D.new()
			comms.position.y = PLATE_H
			comms.action_requested.connect(func(action: Dictionary):
				module_action.emit(module_id, action)
			)
			comms.build(mod.view)
			bay.add_child(comms)
			builder = comms
		"threatplot":
			var threat := ThreatPlot3D.new()
			threat.position.y = PLATE_H
			threat.step_requested.connect(func(dir: String):
				module_action.emit(module_id, {"type": "step", "dir": dir})
			)
			threat.build(mod.view)
			bay.add_child(threat)
			builder = threat
		"brevity":
			var brevity := Brevity3D.new()
			brevity.position.y = PLATE_H
			brevity.press_requested.connect(func(label: String):
				module_action.emit(module_id, {"type": "press", "label": label})
			)
			brevity.build(mod.view)
			bay.add_child(brevity)
			builder = brevity

	_entries[module_id] = {"builder": builder, "led_mat": led_mat, "bay": bay, "solved": bool(mod.solved)}
	if mod.solved:
		mark_solved(module_id)


func _build_blank(slot: int) -> void:
	var plate := MeshInstance3D.new()
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(SLOT, PLATE_H * 0.6, SLOT)
	plate.mesh = pmesh
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.23, 0.25, 0.30)
	pmat.metallic = 0.6
	pmat.roughness = 0.45
	plate.material_override = pmat
	var pos := _slot_pos(slot)
	plate.position = Vector3(pos.x, CASE_H + PLATE_H * 0.3, pos.z)
	add_child(plate)
