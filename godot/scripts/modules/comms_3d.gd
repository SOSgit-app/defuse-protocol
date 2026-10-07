class_name Comms3D
extends Node3D

signal action_requested(action: Dictionary)

var _prompt: Label3D
var _freq: Label3D
var _letter: Label3D


func build(view: Dictionary) -> void:
	_clear()
	var housing := ModuleUI.make_housing(Vector3(0.27, 0.05, 0.09), Color(0.1, 0.14, 0.19))
	housing.position = Vector3(0, 0.025, -0.09)
	add_child(housing)
	_prompt = ModuleUI.make_readout(0.24, 0.05, Color(0.95, 0.85, 0.35))
	_prompt.font_size = 28
	_prompt.position = Vector3(0, 0.05, -0.09)
	add_child(_prompt)
	_freq = ModuleUI.make_readout(0.12, 0.035)
	_freq.position = Vector3(-0.06, 0.04, 0.0)
	add_child(_freq)
	_letter = ModuleUI.make_readout(0.06, 0.035)
	_letter.position = Vector3(0.08, 0.04, 0.0)
	add_child(_letter)

	_add_btn("−1", Vector3(-0.115, 0, 0.055), {"type": "tune", "steps": -4})
	_add_btn("−¼", Vector3(-0.068, 0, 0.055), {"type": "tune", "steps": -1})
	_add_btn("+¼", Vector3(-0.021, 0, 0.055), {"type": "tune", "steps": 1})
	_add_btn("+1", Vector3(0.026, 0, 0.055), {"type": "tune", "steps": 4})
	_add_btn("XMIT", Vector3(0.095, 0, 0.055), {"type": "xmit"}, Color(0.77, 0.2, 0.25), Color.WHITE, true)
	_add_btn("A−", Vector3(-0.09, 0, 0.105), {"type": "letter", "delta": -1})
	_add_btn("A+", Vector3(-0.043, 0, 0.105), {"type": "letter", "delta": 1})
	_add_btn("AUTH", Vector3(0.095, 0, 0.105), {"type": "auth"}, Color(0.18, 0.55, 0.3), Color.WHITE, true)
	update_view(view)


func update_view(view: Dictionary) -> void:
	if _prompt:
		_prompt.text = "%s %s/%s\n%s" % [
			str(view.get("phase", "")).to_upper(),
			str(view.get("round", 1)),
			str(view.get("total", 1)),
			str(view.get("prompt", "DONE"))
		]
	if _freq:
		_freq.text = str(view.get("freq", "0.00"))
	if _letter:
		_letter.text = str(view.get("letter", "A"))


func _add_btn(label: String, pos: Vector3, action: Dictionary, bg: Color = Color(0.8, 0.84, 0.89), fg: Color = Color(0.07, 0.08, 0.1), wide: bool = false) -> void:
	var size := Vector3(0.06 if wide else 0.042, 0.02, 0.034 if wide else 0.03)
	var btn := ModuleUI.make_button(label, size, bg, fg)
	btn.position = pos
	btn.clicked.connect(func(): action_requested.emit(action))
	add_child(btn)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_prompt = null
	_freq = null
	_letter = null
