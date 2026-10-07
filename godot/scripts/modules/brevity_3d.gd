class_name Brevity3D
extends Node3D

signal press_requested(label: String)

var _display: Label3D
var _stage: Label3D
var _buttons: Array = []


func build(view: Dictionary) -> void:
	_clear()
	var housing := ModuleUI.make_housing(Vector3(0.26, 0.045, 0.08), Color(0.12, 0.14, 0.12))
	housing.position = Vector3(0, 0.022, -0.09)
	add_child(housing)
	_display = ModuleUI.make_readout(0.22, 0.05, Color(0.45, 1.0, 0.55))
	_display.font_size = 40
	_display.position = Vector3(0, 0.045, -0.09)
	add_child(_display)
	_stage = ModuleUI.make_readout(0.22, 0.03, Color(0.75, 0.8, 0.7))
	_stage.font_size = 22
	_stage.position = Vector3(0, 0.045, -0.12)
	add_child(_stage)

	_buttons.clear()
	for i in 6:
		var row := i / 3
		var col := i % 3
		var btn := ModuleUI.make_button("—", Vector3(0.075, 0.028, 0.04), Color(0.78, 0.82, 0.78))
		btn.position = Vector3(-0.08 + col * 0.08, 0, 0.02 + row * 0.055)
		var idx := i
		btn.clicked.connect(func():
			if idx < _buttons.size() and _buttons[idx].has_meta("label"):
				press_requested.emit(str(_buttons[idx].get_meta("label")))
		)
		add_child(btn)
		_buttons.append(btn)
	update_view(view)


func update_view(view: Dictionary) -> void:
	if _display:
		_display.text = str(view.get("display", "—"))
	if _stage:
		_stage.text = "STAGE %s/%s" % [str(view.get("stage", 1)), str(view.get("total", 1))]
	var labels: Array = view.get("buttons", [])
	for i in _buttons.size():
		var btn: Clickable = _buttons[i]
		if i < labels.size():
			btn.visible = true
			btn.enabled = true
			ModuleUI.set_button_label(btn, str(labels[i]))
			btn.set_meta("label", labels[i])
		else:
			btn.visible = false
			btn.enabled = false


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_display = null
	_stage = null
