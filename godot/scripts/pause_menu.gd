class_name PauseMenu
extends Node3D
## In-VR / desktop pause panel. Y toggles. Settings page mirrors Prefs.

signal resume_pressed
signal settings_pressed
signal main_menu_pressed

var open: bool = false
var targets: Array = []
var _page: String = "pause"
var _pause_root: Node3D
var _settings_root: Node3D
var _time_labels: Dictionary = {}
var _strike_labels: Dictionary = {}
var _fly_label: Label3D


func _ready() -> void:
	visible = false
	_build()


func show_menu() -> void:
	_show_page("pause")
	visible = true
	open = true


func hide_menu() -> void:
	visible = false
	open = false
	_show_page("pause")


func toggle() -> void:
	if open:
		hide_menu()
		resume_pressed.emit()
	else:
		show_menu()


func place_on_controller(host: Node3D) -> void:
	if host == null:
		return
	if get_parent() != host:
		reparent(host)
	position = Vector3(0, 0.12, 0.05)
	rotation_degrees = Vector3(-90 + 25, 0, 0)
	scale = Vector3(1.35, 1.35, 1.35)


func _show_page(page: String) -> void:
	_page = page
	if _pause_root:
		_pause_root.visible = page == "pause"
	if _settings_root:
		_settings_root.visible = page == "settings"
		if page == "settings":
			_refresh_settings_labels()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	targets.clear()
	_pause_root = Node3D.new()
	add_child(_pause_root)
	_settings_root = Node3D.new()
	_settings_root.visible = false
	add_child(_settings_root)

	var bezel := ModuleUI.make_housing(Vector3(0.24, 0.02, 0.2), Color(0.08, 0.1, 0.13))
	_pause_root.add_child(bezel)
	var title := ModuleUI.make_readout(0.2, 0.04)
	title.text = "PAUSED"
	title.position = Vector3(0, 0.012, -0.07)
	_pause_root.add_child(title)
	_add_btn(_pause_root, "RESUME", Vector3(0, 0.012, -0.02), Color(0.18, 0.55, 0.3), Color.WHITE, func():
		hide_menu()
		resume_pressed.emit()
	)
	_add_btn(_pause_root, "SETTINGS", Vector3(0, 0.012, 0.03), Color(0.8, 0.84, 0.88), Color(0.07, 0.08, 0.1), func():
		_show_page("settings")
	)
	_add_btn(_pause_root, "MAIN MENU", Vector3(0, 0.012, 0.08), Color(0.75, 0.2, 0.22), Color.WHITE, func():
		hide_menu()
		main_menu_pressed.emit()
	)

	var sbezel := ModuleUI.make_housing(Vector3(0.28, 0.02, 0.28), Color(0.08, 0.1, 0.13))
	_settings_root.add_child(sbezel)
	var st := ModuleUI.make_readout(0.24, 0.035)
	st.text = "SETTINGS"
	st.position = Vector3(0, 0.012, -0.11)
	_settings_root.add_child(st)

	var y := -0.06
	for key in ["easy", "normal", "hard"]:
		_add_btn(_settings_root, key.substr(0, 1).to_upper() + " TIME", Vector3(-0.07, 0.012, y), Color(0.75, 0.78, 0.85), Color(0.07, 0.08, 0.1), _cycle_time.bind(key))
		var tl := ModuleUI.make_readout(0.08, 0.03)
		tl.position = Vector3(0.08, 0.012, y)
		_settings_root.add_child(tl)
		_time_labels[key] = tl
		y += 0.045
		_add_btn(_settings_root, key.substr(0, 1).to_upper() + " STRK", Vector3(-0.07, 0.012, y), Color(0.75, 0.78, 0.85), Color(0.07, 0.08, 0.1), _cycle_strike.bind(key))
		var sl := ModuleUI.make_readout(0.06, 0.03)
		sl.position = Vector3(0.08, 0.012, y)
		_settings_root.add_child(sl)
		_strike_labels[key] = sl
		y += 0.048

	_add_btn(_settings_root, "FLY", Vector3(-0.07, 0.012, y), Color(0.75, 0.78, 0.85), Color(0.07, 0.08, 0.1), _cycle_fly)
	_fly_label = ModuleUI.make_readout(0.06, 0.03)
	_fly_label.position = Vector3(0.08, 0.012, y)
	_settings_root.add_child(_fly_label)
	y += 0.05
	_add_btn(_settings_root, "BACK", Vector3(0, 0.012, y), Color(0.18, 0.55, 0.3), Color.WHITE, func():
		Prefs.save_prefs()
		_show_page("pause")
	)


func _refresh_settings_labels() -> void:
	for key in ["easy", "normal", "hard"]:
		if _time_labels.has(key):
			_time_labels[key].text = Prefs.fmt_time(int(Prefs.times[key]))
		if _strike_labels.has(key):
			_strike_labels[key].text = "%d" % int(Prefs.strikes[key])
	if _fly_label:
		_fly_label.text = "YES" if Prefs.fly_enabled else "NO"


func _cycle_time(key: String) -> void:
	var cur: int = Prefs.nearest_time(int(Prefs.times[key]))
	var idx := Prefs.TIME_OPTIONS.find(cur)
	idx = (idx + 1) % Prefs.TIME_OPTIONS.size()
	Prefs.times[key] = Prefs.TIME_OPTIONS[idx]
	_refresh_settings_labels()


func _cycle_strike(key: String) -> void:
	var cur := int(Prefs.strikes[key])
	var idx := Prefs.STRIKE_OPTIONS.find(cur)
	if idx < 0:
		idx = 2
	idx = (idx + 1) % Prefs.STRIKE_OPTIONS.size()
	Prefs.strikes[key] = Prefs.STRIKE_OPTIONS[idx]
	_refresh_settings_labels()


func _cycle_fly() -> void:
	Prefs.fly_enabled = not Prefs.fly_enabled
	_refresh_settings_labels()


func _add_btn(parent: Node3D, label: String, pos: Vector3, bg: Color, fg: Color, cb: Callable) -> void:
	var btn := ModuleUI.make_button(label, Vector3(0.12 if label.length() > 6 else 0.1, 0.018, 0.035), bg, fg)
	btn.position = pos
	btn.clicked.connect(cb)
	parent.add_child(btn)
	targets.append(btn)
