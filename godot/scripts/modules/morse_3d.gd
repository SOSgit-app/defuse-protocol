class_name Morse3D
extends Node3D

signal tune_requested(index: int)
signal transmit_requested

const START_DELAY := 5.0
const RST_DELAY := 3.0
const RST_FLASH := 0.45

var _freq: Label3D
var _pattern: Label3D
var _freqs: Array = []
var _selected: int = 0
var _clock: float = -START_DELAY
var _pattern_data: Array = []
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _audio: bool = false
var _snd_btn: Clickable
var _rst_btn: Clickable
var _confirm_t: float = 0.0
var _confirming: bool = false
var _lamp_on: bool = false
var _tone_on: bool = false
var _done: bool = false
var _timeline: Array = []
var _loop_len: float = 1.0


func build(view: Dictionary) -> void:
	_clear()
	_audio = false
	_done = false
	_confirm_t = 0.0
	_confirming = false
	_clock = -START_DELAY

	var housing := ModuleUI.make_housing(Vector3(0.26, 0.045, 0.1), Color(0.08, 0.1, 0.12))
	housing.position = Vector3(0, 0.022, -0.08)
	add_child(housing)

	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.15, 0.15, 0.15)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.78, 0.24)
	_lamp_mat.emission_energy_multiplier = 0.0
	_lamp = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	_lamp.mesh = sphere
	_lamp.material_override = _lamp_mat
	_lamp.position = Vector3(0.1, 0.04, -0.08)
	add_child(_lamp)

	_freq = ModuleUI.make_readout(0.16, 0.04, Color(1.0, 0.82, 0.25))
	_freq.position = Vector3(-0.02, 0.041, -0.02)
	add_child(_freq)
	_pattern = ModuleUI.make_readout(0.22, 0.03, Color(0.85, 0.82, 0.4))
	_pattern.font_size = 22
	_pattern.position = Vector3(0, 0.041, -0.08)
	add_child(_pattern)

	var knob := ModuleUI.make_button("TUNE", Vector3(0.055, 0.03, 0.05), Color(0.75, 0.78, 0.85))
	knob.position = Vector3(-0.1, 0, 0.09)
	knob.clicked.connect(func():
		if _freqs.is_empty():
			return
		_selected = (_selected + 1) % _freqs.size()
		tune_requested.emit(_selected)
	)
	add_child(knob)

	_snd_btn = ModuleUI.make_button("SND", Vector3(0.05, 0.03, 0.04), Color(0.81, 0.84, 0.89))
	_snd_btn.position = Vector3(-0.038, 0, 0.09)
	_snd_btn.clicked.connect(_toggle_audio)
	add_child(_snd_btn)

	_rst_btn = ModuleUI.make_button("RST", Vector3(0.05, 0.03, 0.04), Color(0.29, 0.53, 0.85), Color.WHITE)
	_rst_btn.position = Vector3(0.028, 0, 0.09)
	_rst_btn.clicked.connect(_reset_word)
	add_child(_rst_btn)

	var tx := ModuleUI.make_button("TX", Vector3(0.055, 0.03, 0.05), Color(0.77, 0.2, 0.25), Color(0.95, 0.92, 0.9))
	tx.position = Vector3(0.1, 0, 0.09)
	tx.clicked.connect(func(): transmit_requested.emit())
	add_child(tx)

	update_view(view)
	set_process(true)


func _process(delta: float) -> void:
	if _done:
		_set_lamp(false)
		return
	if _confirm_t > 0.0:
		_confirm_t -= delta
		if _confirm_t <= 0.0:
			_confirm_t = 0.0
			ModuleUI.set_button_colors(_rst_btn, Color(0.29, 0.53, 0.85), Color.WHITE)
			_set_confirm_lamp(false)
	_clock += delta
	if _clock < 0.0:
		if not _confirming:
			_set_lamp(false)
		return
	if _timeline.is_empty():
		return
	var t := fmod(_clock, _loop_len)
	var on := false
	for ev in _timeline:
		if t >= float(ev.start) and t < float(ev.end):
			on = bool(ev.on)
			break
	_set_lamp(on)


func update_view(view: Dictionary) -> void:
	_freqs = view.get("frequencies", [])
	_selected = int(view.get("selected", 0))
	_pattern_data = view.get("pattern", [])
	_timeline = _build_timeline(_pattern_data)
	_loop_len = 1.0
	if not _timeline.is_empty():
		_loop_len = float(_timeline[_timeline.size() - 1].end)
	if _freq and _freqs.size():
		_freq.text = "%.3f" % float(_freqs[_selected])
	if _pattern:
		_pattern.text = _pattern_preview()
	if bool(view.get("solved", false)):
		_done = true
		Sound.morse_tone(false)


func mark_done() -> void:
	_done = true
	_set_lamp(false)


func _toggle_audio() -> void:
	_audio = not _audio
	ModuleUI.set_button_colors(
		_snd_btn,
		Color(0.49, 1.0, 0.6) if _audio else Color(0.81, 0.84, 0.89),
		Color(0.07, 0.08, 0.1)
	)
	_set_lamp(_lamp_on)


func _reset_word() -> void:
	_clock = -RST_DELAY
	_confirm_t = RST_FLASH
	ModuleUI.set_button_colors(_rst_btn, Color(0.22, 0.85, 0.54), Color.WHITE)
	_set_lamp(false)
	_set_confirm_lamp(true)


func _set_confirm_lamp(on: bool) -> void:
	_confirming = on
	if _lamp_mat == null:
		return
	if on:
		_lamp_mat.emission = Color(0.22, 0.85, 0.54)
		_lamp_mat.emission_energy_multiplier = 2.4
		_tone_on = false
		Sound.morse_tone(false)
	else:
		_lamp_mat.emission = Color(1.0, 0.78, 0.24)
		_lamp_mat.emission_energy_multiplier = 0.0
		_lamp_on = false


func _set_lamp(on: bool) -> void:
	if _confirming:
		return
	if on != _lamp_on and _lamp_mat:
		_lamp_on = on
		_lamp_mat.emission = Color(1.0, 0.78, 0.24)
		_lamp_mat.emission_energy_multiplier = 2.2 if on else 0.0
	var want := on and _audio and not _done
	if want != _tone_on:
		_tone_on = want
		Sound.morse_tone(want)


func _pattern_preview() -> String:
	var parts: PackedStringArray = []
	for letter in _pattern_data:
		var s := ""
		for mark in letter:
			s += str(mark)
		parts.append(s)
	return " ".join(parts)


func _build_timeline(pattern: Array) -> Array:
	var unit := 0.22
	var t := 0.0
	var events: Array = []
	for letter in pattern:
		for mark in letter:
			var dur := unit if str(mark) == "." else unit * 3.0
			events.append({"start": t, "end": t + dur, "on": true})
			t += dur
			events.append({"start": t, "end": t + unit, "on": false})
			t += unit
		t += unit * 2.0
	t += unit * 7.0
	events.append({"start": t - unit * 7.0, "end": t, "on": false})
	return events


func _clear() -> void:
	Sound.morse_tone(false)
	for c in get_children():
		c.queue_free()
	_freq = null
	_pattern = null
	_lamp = null
	_lamp_mat = null
	_snd_btn = null
	_rst_btn = null
	set_process(true)


func _exit_tree() -> void:
	Sound.morse_tone(false)
