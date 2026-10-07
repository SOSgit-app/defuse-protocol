extends Node3D
## Full playable Defuse Protocol host: home, settings, bomb, pause, end.

@onready var _camera: Camera3D = $FallbackCamera
@onready var _xr_origin: XROrigin3D = $XROrigin3D
@onready var _hud: Label = $HUD/Status

var _ui: CanvasLayer
var _game: DefuseGame
var _device: BombDevice
var _hovered: Clickable = null
var _pause: PauseMenu
var _fan: DeskFan
var _fly: HouseFly
var _phase: String = "home" # home | game | end
var _orbiting: bool = false
var _orbit_last: Vector2 = Vector2.ZERO
var _cam_yaw: float = 0.6
var _cam_pitch: float = 0.35
var _cam_dist: float = 1.7
var _last_tick_sec: int = -1

var _diff_opt: OptionButton
var _seed_edit: LineEdit
var _home_panel: Control
var _settings_panel: Control
var _end_panel: Control
var _end_title: Label
var _end_body: Label
var _set_time: Dictionary = {}
var _set_strike: Dictionary = {}
var _set_fly: OptionButton


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_build_ui()

	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.resume_pressed.connect(_on_pause_resume)
	_pause.main_menu_pressed.connect(_return_home)

	_fan = DeskFan.new()
	add_child(_fan)
	_fly = HouseFly.new()
	add_child(_fly)
	_fly.changed.connect(_on_fly_changed)

	if _xr_origin.has_signal("menu_button"):
		_xr_origin.menu_button.connect(_on_y_menu)
	if _xr_origin.has_method("set_pause_menu"):
		_xr_origin.set_pause_menu(_pause)

	_show_home()
	_update_camera()


func _process(delta: float) -> void:
	if _phase == "game" and _game:
		_game.process_tick()
		_tick_fly(delta)
	if _phase == "game" and not get_viewport().use_xr and not _ui_blocking():
		_update_desktop_hover()
	if _pause.open and get_viewport().use_xr and _xr_origin.has_method("get_left_controller"):
		var left = _xr_origin.get_left_controller()
		if left:
			_pause.place_on_controller(left)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _phase == "game":
			_on_y_menu()
		return
	if _phase != "game" or get_viewport().use_xr or _ui_blocking():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit := _desktop_ray()
				if hit and hit.has_method("on_click"):
					hit.on_click()
					if not _pause.open:
						Sound.click()
				else:
					_orbiting = true
					_orbit_last = event.position
			else:
				_orbiting = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist = maxf(0.7, _cam_dist - 0.12)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist = minf(4.0, _cam_dist + 0.12)
			_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		var d: Vector2 = event.position - _orbit_last
		_orbit_last = event.position
		_cam_yaw -= d.x * 0.005
		_cam_pitch = clampf(_cam_pitch + d.y * 0.005, 0.05, 1.2)
		_update_camera()


func _ui_blocking() -> bool:
	return (_home_panel and _home_panel.visible) or (_settings_panel and _settings_panel.visible) or (_end_panel and _end_panel.visible)


func _update_camera() -> void:
	if get_viewport().use_xr:
		return
	var target := Vector3(0, 0.15, 0)
	var offset := Vector3(
		sin(_cam_yaw) * cos(_cam_pitch),
		sin(_cam_pitch),
		cos(_cam_yaw) * cos(_cam_pitch)
	) * _cam_dist
	_camera.global_position = target + offset
	_camera.look_at(target, Vector3.UP)


func _show_home() -> void:
	_phase = "home"
	_cleanup_bomb()
	_home_panel.visible = true
	_settings_panel.visible = false
	_end_panel.visible = false
	_hud.visible = false
	_pause.hide_menu()
	_diff_opt.select(_diff_index(Prefs.difficulty))
	_seed_edit.text = Prefs.seed_text


func _start_bomb(_enter_vr_hint: bool = false) -> void:
	Prefs.difficulty = _diff_key(_diff_opt.selected)
	Prefs.seed_text = _seed_edit.text.strip_edges()
	Prefs.save_prefs()
	Prefs.last_enter_vr = get_viewport().use_xr

	_home_panel.visible = false
	_settings_panel.visible = false
	_end_panel.visible = false
	_hud.visible = true
	_phase = "game"
	_last_tick_sec = -1

	if _game:
		_game.destroy()
	_game = DefuseGame.new()
	_game.tick.connect(_on_tick)
	_game.strike.connect(_on_strike)
	_game.module_updated.connect(_on_module_updated)
	_game.module_solved.connect(_on_module_solved)
	_game.game_over.connect(_on_game_over)

	var opts := {
		"difficulty": Prefs.difficulty,
		"seed": Prefs.seed_text,
		"time_ms": int(Prefs.times[Prefs.difficulty]),
		"max_strikes": int(Prefs.strikes[Prefs.difficulty])
	}
	_game.start(opts)
	Prefs.last_seed = _game.seed

	if _device:
		_device.queue_free()
	_device = BombDevice.new()
	_device.name = "Bomb"
	add_child(_device)
	_device.module_action.connect(_on_module_action)
	_device.build(_game.defuser_payload())

	_fan.set_visible_fan(Prefs.fly_enabled)
	if Prefs.fly_enabled:
		_fly.arm()
	else:
		_fly.hide_fly()

	_refresh_hud()
	Sound.click()


func _cleanup_bomb() -> void:
	Sound.morse_tone(false)
	if _game:
		_game.destroy()
		_game = null
	if _device:
		_device.queue_free()
		_device = null
	_fly.hide_fly()
	_fan.set_visible_fan(false)


func _return_home() -> void:
	if _game:
		_game.resume()
	_cleanup_bomb()
	_show_home()


func _on_module_action(module_id: String, action: Dictionary) -> void:
	if _pause.open or _game == null:
		return
	Sound.click()
	_game.handle_action(module_id, action)


func _on_tick(remaining_ms: int, _time_scale: float) -> void:
	if _device:
		_device.set_timer(remaining_ms)
	var sec := int(ceil(float(remaining_ms) / 1000.0))
	if remaining_ms < 60000 and sec != _last_tick_sec and sec > 0:
		_last_tick_sec = sec
		Sound.tick_low()
	_refresh_hud()


func _on_strike(strikes: int, max_strikes: int, _module_id: String) -> void:
	Sound.strike()
	if _device:
		_device.set_strikes(strikes)
	_refresh_hud("STRIKE %d/%d" % [strikes, max_strikes])


func _on_module_updated(module_id: String, view: Dictionary) -> void:
	if _device:
		_device.update_module(module_id, view)


func _on_module_solved(module_id: String, solved_count: int) -> void:
	Sound.solve()
	if _device:
		_device.mark_solved(module_id)
	_refresh_hud("MODULE SAFE · %d/%d" % [solved_count, _game.modules.size()])


func _on_game_over(summary: Dictionary) -> void:
	var won := str(summary.result) == "won"
	if won:
		Sound.win()
	else:
		Sound.lose()
	Sound.morse_tone(false)
	if _device:
		_device.game_over(won)
	_fly.hide_fly()
	_fan.set_visible_fan(false)
	_pause.hide_menu()
	_phase = "end"
	_hud.visible = false
	_end_panel.visible = true
	_end_title.text = "DEVICE DEFUSED" if won else "DETONATION"
	_end_title.modulate = Color(0.22, 0.85, 0.54) if won else Color(1.0, 0.25, 0.3)
	if won:
		_end_body.text = "All modules neutralized with %s to spare.\nSEED %s · %s · STRIKES %d" % [
			Prefs.fmt_time(int(summary.time_remaining_ms)),
			summary.seed,
			str(summary.difficulty).to_upper(),
			int(summary.strikes)
		]
	else:
		var why := "Strike limit reached." if summary.reason == "strikes" else "Timer expired."
		_end_body.text = "%s\nSEED %s · %s · STRIKES %d" % [
			why, summary.seed, str(summary.difficulty).to_upper(), int(summary.strikes)
		]


func _refresh_hud(flash: String = "") -> void:
	if _hud == null or _game == null:
		return
	var total := maxi(0, int(ceil(_game.remaining_ms / 1000.0)))
	var time_txt := "%d:%02d" % [total / 60, total % 60]
	var line := "SEED %s · SN %s · %s · ✖%d/%d · ESC/Y = MENU" % [
		_game.seed, _game.serial, time_txt, _game.strikes, int(_game.config.max_strikes)
	]
	if flash != "":
		line = flash + "\n" + line
	_hud.text = line


func _on_y_menu() -> void:
	if _phase != "game" or _game == null or _game.status != "running":
		return
	if _settings_panel.visible:
		_close_settings()
		return
	if _pause.open:
		_on_pause_resume()
	else:
		_game.pause()
		_pause.show_menu()
		if get_viewport().use_xr and _xr_origin.has_method("get_left_controller"):
			_pause.place_on_controller(_xr_origin.get_left_controller())
		else:
			if _pause.get_parent() != self:
				_pause.reparent(self)
			_pause.global_position = _camera.global_position + (-_camera.global_transform.basis.z) * 0.55
			_pause.look_at(_camera.global_position, Vector3.UP)
			_pause.rotate_object_local(Vector3.UP, PI)


func _on_pause_resume() -> void:
	_settings_panel.visible = false
	# Persist any VR pause-settings edits
	Prefs.save_prefs()
	if _phase == "game" and _game:
		_game.config.max_strikes = int(Prefs.strikes[Prefs.difficulty])
		_fan.set_visible_fan(Prefs.fly_enabled)
		if Prefs.fly_enabled and not _fly.enabled:
			_fly.arm()
		elif not Prefs.fly_enabled:
			_fly.hide_fly()
			if _device:
				_device.set_pest(false)
			_game.fly_landed = false
	_pause.hide_menu()
	if _game:
		_game.resume()


func _tick_fly(delta: float) -> void:
	if not Prefs.fly_enabled or _fly == null or _game == null:
		return
	if _game.is_paused() or _game.status != "running":
		return
	var head := _camera.global_position
	if get_viewport().use_xr:
		var xr_cam := _xr_origin.get_node_or_null("XRCamera3D") as Camera3D
		if xr_cam:
			head = xr_cam.global_position
	var timer_pos := Vector3.ZERO
	if _device:
		timer_pos = _device.timer_world_pos()
	_fly.tick(delta, false, head, _fan.on, _fan.global_position, timer_pos)


func _on_fly_changed(landed: bool, squashed: bool) -> void:
	if _game:
		_game.fly_landed = landed and not squashed
	if _device:
		_device.set_pest(landed and not squashed)


func _desktop_ray() -> Clickable:
	var mouse := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var to := from + _camera.project_ray_normal(mouse) * 8.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.collider as Clickable


func _update_desktop_hover() -> void:
	var hit := _desktop_ray()
	if _hovered and _hovered != hit:
		_hovered.set_highlight(false)
	_hovered = hit
	if _hovered:
		_hovered.set_highlight(true)


func _build_ui() -> void:
	_home_panel = _make_panel()
	_ui.add_child(_home_panel)
	var title := _label("DEFUSE PROTOCOL", 42)
	title.position = Vector2(80, 60)
	_home_panel.add_child(title)
	var tag := _label("You defuse. Your team holds the Field Manual.", 18)
	tag.position = Vector2(80, 120)
	_home_panel.add_child(tag)

	_home_panel.add_child(_label("DIFFICULTY", 14, Vector2(80, 180)))
	_diff_opt = OptionButton.new()
	_diff_opt.position = Vector2(80, 205)
	_diff_opt.size = Vector2(420, 36)
	_diff_opt.add_item("EASY — 3 modules")
	_diff_opt.add_item("MEDIUM — 4 modules")
	_diff_opt.add_item("HARD — 5 modules · Weapons Release")
	_home_panel.add_child(_diff_opt)

	_home_panel.add_child(_label("SEED (optional)", 14, Vector2(80, 260)))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random each run"
	_seed_edit.position = Vector2(80, 285)
	_seed_edit.size = Vector2(320, 36)
	_home_panel.add_child(_seed_edit)

	_home_panel.add_child(_button("START MISSION", Vector2(80, 360), Vector2(260, 48), func(): _start_bomb()))
	_home_panel.add_child(_button("SETTINGS", Vector2(360, 360), Vector2(160, 48), _open_settings))
	_home_panel.add_child(_label(
		"Desktop: drag orbit · click modules · Esc = pause\nQuest: OpenXR · trigger · Y = pause",
		14, Vector2(80, 430)
	))

	_settings_panel = _make_panel()
	_ui.add_child(_settings_panel)
	_settings_panel.visible = false
	_settings_panel.add_child(_label("SETTINGS", 32, Vector2(80, 50)))
	var y := 110.0
	for key in ["easy", "normal", "hard"]:
		_settings_panel.add_child(_label(key.to_upper() + " TIMER", 14, Vector2(80, y)))
		var topt := OptionButton.new()
		topt.position = Vector2(80, y + 22)
		topt.size = Vector2(180, 32)
		for ms in Prefs.TIME_OPTIONS:
			topt.add_item(Prefs.fmt_time(ms))
		_set_time[key] = topt
		_settings_panel.add_child(topt)
		_settings_panel.add_child(_label(key.to_upper() + " STRIKES", 14, Vector2(300, y)))
		var sopt := OptionButton.new()
		sopt.position = Vector2(300, y + 22)
		sopt.size = Vector2(120, 32)
		for n in Prefs.STRIKE_OPTIONS:
			sopt.add_item("%d" % n)
		_set_strike[key] = sopt
		_settings_panel.add_child(sopt)
		y += 70
	_settings_panel.add_child(_label("UNINVITED FLY", 14, Vector2(80, y)))
	_set_fly = OptionButton.new()
	_set_fly.position = Vector2(80, y + 22)
	_set_fly.size = Vector2(120, 32)
	_set_fly.add_item("NO")
	_set_fly.add_item("YES")
	_settings_panel.add_child(_set_fly)
	_settings_panel.add_child(_button("DONE", Vector2(80, y + 80), Vector2(160, 44), _close_settings))
	_settings_panel.add_child(_button("RESTORE DEFAULTS", Vector2(260, y + 80), Vector2(220, 44), _restore_defaults))

	_end_panel = _make_panel()
	_ui.add_child(_end_panel)
	_end_panel.visible = false
	_end_title = _label("—", 40, Vector2(80, 80))
	_end_panel.add_child(_end_title)
	_end_body = _label("", 18, Vector2(80, 150))
	_end_body.size = Vector2(700, 120)
	_end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_panel.add_child(_end_body)
	_end_panel.add_child(_button("RESTART THIS BOMB", Vector2(80, 300), Vector2(260, 48), func():
		Prefs.seed_text = Prefs.last_seed
		_seed_edit.text = Prefs.last_seed
		_start_bomb()
	))
	_end_panel.add_child(_button("CONTINUE · NEW BOMB", Vector2(360, 300), Vector2(260, 48), func():
		Prefs.seed_text = ""
		_seed_edit.text = ""
		_start_bomb()
	))
	_end_panel.add_child(_button("MAIN MENU", Vector2(80, 370), Vector2(200, 48), _return_home))


func _open_settings() -> void:
	_fill_settings()
	_settings_panel.visible = true


func _fill_settings() -> void:
	for key in ["easy", "normal", "hard"]:
		var tms: int = Prefs.nearest_time(int(Prefs.times[key]))
		_set_time[key].select(Prefs.TIME_OPTIONS.find(tms))
		_set_strike[key].select(clampi(int(Prefs.strikes[key]) - 1, 0, 8))
	_set_fly.select(1 if Prefs.fly_enabled else 0)


func _close_settings() -> void:
	for key in ["easy", "normal", "hard"]:
		Prefs.times[key] = Prefs.TIME_OPTIONS[_set_time[key].selected]
		Prefs.strikes[key] = Prefs.STRIKE_OPTIONS[_set_strike[key].selected]
	Prefs.fly_enabled = _set_fly.selected == 1
	Prefs.save_prefs()
	_settings_panel.visible = false
	if _phase == "game" and _game:
		_game.config.max_strikes = int(Prefs.strikes[Prefs.difficulty])
		_fan.set_visible_fan(Prefs.fly_enabled)
		if Prefs.fly_enabled and not _fly.enabled:
			_fly.arm()
		elif not Prefs.fly_enabled:
			_fly.hide_fly()
			if _device:
				_device.set_pest(false)
			_game.fly_landed = false
		if _pause.open:
			_on_pause_resume()


func _restore_defaults() -> void:
	Prefs.times = Prefs.DEFAULT_TIMES.duplicate()
	Prefs.strikes = Prefs.DEFAULT_STRIKES.duplicate()
	Prefs.fly_enabled = false
	_fill_settings()


func _make_panel() -> Control:
	var p := ColorRect.new()
	p.color = Color(0.04, 0.05, 0.07, 0.94)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _label(text: String, size: int, pos: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82))
	return l


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.pressed.connect(cb)
	return b


func _diff_index(key: String) -> int:
	match key:
		"easy": return 0
		"hard": return 2
		_: return 1


func _diff_key(idx: int) -> String:
	match idx:
		0: return "easy"
		2: return "hard"
		_: return "normal"
