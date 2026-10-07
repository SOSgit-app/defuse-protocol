class_name Ordnance3D
extends Node3D

signal action_requested(action: Dictionary)

var _card: Label3D
var _status: Label3D
var _arm_btn: Clickable
var _station_btn: Clickable
var _fuze_btn: Clickable
var _wheel_btns: Array = []
var _release_btn: Clickable


func build(view: Dictionary) -> void:
	_clear()
	var housing := ModuleUI.make_housing(Vector3(0.28, 0.04, 0.1), Color(0.12, 0.14, 0.16))
	housing.position = Vector3(0, 0.02, -0.08)
	add_child(housing)
	_card = ModuleUI.make_readout(0.26, 0.06, Color(0.95, 0.85, 0.35))
	_card.font_size = 22
	_card.position = Vector3(0, 0.042, -0.08)
	add_child(_card)
	_status = ModuleUI.make_readout(0.26, 0.03, Color(0.7, 0.85, 0.75))
	_status.font_size = 24
	_status.position = Vector3(0, 0.042, -0.03)
	add_child(_status)

	_arm_btn = ModuleUI.make_button("ARM", Vector3(0.07, 0.028, 0.04), Color(0.75, 0.2, 0.22), Color.WHITE)
	_arm_btn.position = Vector3(-0.1, 0, 0.05)
	_arm_btn.clicked.connect(func(): action_requested.emit({"type": "arm"}))
	add_child(_arm_btn)

	_station_btn = ModuleUI.make_button("STA", Vector3(0.07, 0.028, 0.04), Color(0.8, 0.82, 0.86))
	_station_btn.position = Vector3(-0.02, 0, 0.05)
	_station_btn.clicked.connect(func(): action_requested.emit({"type": "station"}))
	add_child(_station_btn)

	_fuze_btn = ModuleUI.make_button("FUZE", Vector3(0.07, 0.028, 0.04), Color(0.8, 0.82, 0.86))
	_fuze_btn.position = Vector3(0.06, 0, 0.05)
	_fuze_btn.clicked.connect(func(): action_requested.emit({"type": "fuze"}))
	add_child(_fuze_btn)

	_wheel_btns.clear()
	for i in 3:
		var w := ModuleUI.make_button("0", Vector3(0.035, 0.028, 0.035), Color(0.2, 0.22, 0.26), Color(0.9, 0.9, 0.85))
		w.position = Vector3(-0.07 + i * 0.045, 0, 0.11)
		var idx := i
		w.clicked.connect(func(): action_requested.emit({"type": "wheel", "index": idx}))
		add_child(w)
		_wheel_btns.append(w)

	_release_btn = ModuleUI.make_button("RELEASE", Vector3(0.1, 0.03, 0.045), Color(0.75, 0.15, 0.18), Color.WHITE)
	_release_btn.position = Vector3(0.09, 0, 0.11)
	_release_btn.clicked.connect(func(): action_requested.emit({"type": "pickle"}))
	add_child(_release_btn)

	update_view(view)


func update_view(view: Dictionary) -> void:
	if _card:
		_card.text = str(view.get("card", "ALL TARGETS SERVICED"))
	if _status:
		_status.text = "TGT %s/%s · %s · %s · %s" % [
			str(view.get("index", 0)),
			str(view.get("total", 0)),
			"ARMED" if view.get("masterArm") else "SAFE",
			str(view.get("weapon", "")),
			str(view.get("fuze", ""))
		]
	if _arm_btn:
		ModuleUI.set_button_label(_arm_btn, "ARMED" if view.get("masterArm") else "SAFE")
		ModuleUI.set_button_colors(
			_arm_btn,
			Color(0.2, 0.65, 0.35) if view.get("masterArm") else Color(0.75, 0.2, 0.22),
			Color.WHITE
		)
	if _station_btn:
		ModuleUI.set_button_label(_station_btn, str(view.get("weapon", "STA")))
	if _fuze_btn:
		ModuleUI.set_button_label(_fuze_btn, str(view.get("fuze", "FUZE")))
	var code: Array = view.get("code", [0, 0, 0])
	for i in mini(_wheel_btns.size(), code.size()):
		ModuleUI.set_button_label(_wheel_btns[i], str(code[i]))


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_wheel_btns.clear()
	_card = null
	_status = null
