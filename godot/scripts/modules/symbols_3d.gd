class_name Symbols3D
extends Node3D

signal press_requested(glyph: String)

var _buttons: Array = []


func build(view: Dictionary) -> void:
	_clear()
	var symbols: Array = view.get("symbols", [])
	var positions := [
		Vector3(-0.062, 0, -0.062), Vector3(0.062, 0, -0.062),
		Vector3(-0.062, 0, 0.062), Vector3(0.062, 0, 0.062)
	]
	for i in symbols.size():
		var s: Dictionary = symbols[i]
		var btn := ModuleUI.make_button(str(s.glyph), Vector3(0.105, 0.038, 0.105), Color(0.78, 0.76, 0.70))
		btn.position = positions[i] if i < positions.size() else Vector3.ZERO
		var glyph := str(s.glyph)
		btn.clicked.connect(func(): press_requested.emit(glyph))
		add_child(btn)
		_buttons.append({"btn": btn, "glyph": glyph})
	update_view(view)


func update_view(view: Dictionary) -> void:
	var symbols: Array = view.get("symbols", [])
	for i in mini(_buttons.size(), symbols.size()):
		var pressed := bool(symbols[i].pressed)
		ModuleUI.set_button_colors(
			_buttons[i].btn,
			Color(0.62, 0.91, 0.74) if pressed else Color(0.78, 0.76, 0.70)
		)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
