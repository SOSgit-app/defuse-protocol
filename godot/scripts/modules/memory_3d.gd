class_name Memory3D
extends Node3D

signal press_requested(position: int)

var _display: Label3D
var _stage: Label3D
var _buttons: Array = []


func build(view: Dictionary) -> void:
	_clear()
	var housing := ModuleUI.make_housing(Vector3(0.22, 0.04, 0.08), Color(0.08, 0.1, 0.12))
	housing.position = Vector3(0, 0.02, -0.085)
	add_child(housing)
	_display = ModuleUI.make_readout(0.18, 0.05)
	_display.font_size = 72
	_display.position = Vector3(0, 0.041, -0.085)
	add_child(_display)
	_stage = ModuleUI.make_readout(0.18, 0.03, Color(0.7, 0.75, 0.8))
	_stage.font_size = 28
	_stage.position = Vector3(0, 0.041, -0.12)
	add_child(_stage)

	_buttons.clear()
	for i in 4:
		var btn := ModuleUI.make_button("?", Vector3(0.05, 0.034, 0.06), Color(0.78, 0.76, 0.70))
		btn.position = Vector3(-0.0875 + i * 0.0585, 0, 0.07)
		var pos := i + 1
		btn.clicked.connect(func(): press_requested.emit(pos))
		add_child(btn)
		_buttons.append(btn)
	update_view(view)


func update_view(view: Dictionary) -> void:
	if _display:
		_display.text = str(view.get("display", ""))
	if _stage:
		_stage.text = "STAGE %s/%s" % [str(view.get("stage", 1)), str(view.get("totalStages", 1))]
	var labels: Array = view.get("labels", [])
	for i in mini(_buttons.size(), labels.size()):
		ModuleUI.set_button_label(_buttons[i], str(labels[i]))


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_display = null
	_stage = null
