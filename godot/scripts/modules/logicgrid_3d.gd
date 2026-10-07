class_name LogicGrid3D
extends Node3D

signal answer_requested(option: String)

var _question: Label3D
var _buttons: Array = []
var table_prop: Node3D = null
var _clip_label: Label3D = null


func build(view: Dictionary) -> void:
	_clear()
	var housing := ModuleUI.make_housing(Vector3(0.27, 0.05, 0.1), Color(0.1, 0.14, 0.19))
	housing.position = Vector3(0, 0.025, -0.09)
	housing.rotation_degrees = Vector3(12, 0, 0)
	add_child(housing)
	_question = ModuleUI.make_readout(0.24, 0.06, Color(1.0, 0.82, 0.25))
	_question.font_size = 28
	_question.position = Vector3(0, 0.05, -0.09)
	_question.rotation_degrees = Vector3(-78, 0, 0)
	add_child(_question)

	_buttons.clear()
	for i in 3:
		var btn := ModuleUI.make_button("—", Vector3(0.24, 0.025, 0.04), Color(0.78, 0.82, 0.88))
		btn.position = Vector3(0, 0, 0.006 + i * 0.046)
		var idx := i
		btn.clicked.connect(func():
			if idx < _buttons.size() and _buttons[idx].has_meta("option"):
				answer_requested.emit(str(_buttons[idx].get_meta("option")))
		)
		add_child(btn)
		_buttons.append(btn)

	table_prop = _make_clipboard(view.get("clues", []))
	update_view(view)


func update_view(view: Dictionary) -> void:
	if _question:
		var q = view.get("question")
		_question.text = "Q%s/%s\n%s" % [
			str(view.get("stage", 1)),
			str(view.get("totalStages", 1)),
			str(q) if q else "DONE"
		]
	var options: Array = view.get("options", [])
	for i in _buttons.size():
		var btn: Clickable = _buttons[i]
		if i < options.size():
			btn.visible = true
			btn.enabled = true
			ModuleUI.set_button_label(btn, str(options[i]))
			btn.set_meta("option", options[i])
		else:
			btn.visible = false
			btn.enabled = false
	_set_clues(view.get("clues", []))


func _make_clipboard(clues: Array) -> Node3D:
	var prop := Node3D.new()
	prop.position = Vector3(1.05, 0.005, 0.72)
	prop.rotation.y = -0.45
	var board := ModuleUI.make_housing(Vector3(0.28, 0.01, 0.36), Color(0.55, 0.42, 0.28))
	prop.add_child(board)
	var paper := ModuleUI.make_housing(Vector3(0.24, 0.004, 0.32), Color(0.92, 0.9, 0.82))
	paper.position.y = 0.008
	prop.add_child(paper)
	_clip_label = Label3D.new()
	_clip_label.font_size = 22
	_clip_label.pixel_size = 0.001
	_clip_label.modulate = Color(0.1, 0.1, 0.12)
	_clip_label.position = Vector3(0, 0.012, 0)
	_clip_label.rotation_degrees = Vector3(-90, 0, 0)
	_clip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_clip_label.width = 400
	_clip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prop.add_child(_clip_label)
	_set_clues(clues)
	return prop


func _set_clues(clues: Array) -> void:
	if _clip_label == null:
		return
	var lines: PackedStringArray = ["INTERCEPTED NOTES", ""]
	for i in clues.size():
		lines.append("%d. %s" % [i + 1, str(clues[i])])
	_clip_label.text = "\n".join(lines)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_question = null
	table_prop = null
	_clip_label = null
