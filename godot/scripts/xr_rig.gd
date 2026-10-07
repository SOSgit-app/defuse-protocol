extends XROrigin3D
## Quest locomotion + controller lasers. Mirrors public/js/three/xr.js

signal menu_button

const SNAP_DEG := 30.0
const MOVE_SPEED := 1.4
const DEADZONE := 0.25
const SNAP_COOLDOWN := 0.35

var _snap_wait := 0.0
var _xr: XRInterface
var _hovered: Clickable = null
var _pause: PauseMenu = null
var locomotion_blocked: bool = false

@onready var _left: XRController3D = $LeftController
@onready var _right: XRController3D = $RightController


func _ready() -> void:
	_xr = XRServer.find_interface("OpenXR")
	if _xr and _xr.initialize():
		get_viewport().use_xr = true
		var cam := get_parent().get_node_or_null("FallbackCamera") as Camera3D
		if cam:
			cam.current = false
	_left.button_pressed.connect(_on_controller_button.bind(_left))
	_right.button_pressed.connect(_on_controller_button.bind(_right))


func set_pause_menu(menu: PauseMenu) -> void:
	_pause = menu


func get_left_controller() -> XRController3D:
	return _left


func _process(delta: float) -> void:
	if _xr == null or not get_viewport().use_xr:
		return
	_snap_wait = maxf(0.0, _snap_wait - delta)
	if not locomotion_blocked and (_pause == null or not _pause.open):
		_move(delta)
		_snap_turn()
	_update_hover()


func _move(delta: float) -> void:
	var pad := _left.get_vector2("primary")
	var mx := pad.x if absf(pad.x) > DEADZONE else 0.0
	var my := pad.y if absf(pad.y) > DEADZONE else 0.0
	if mx == 0.0 and my == 0.0:
		return
	var cam := $XRCamera3D as XRCamera3D
	var forward := -cam.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 1e-6:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var wish := forward * my + right * mx
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	global_position += wish * MOVE_SPEED * delta
	global_position.x = clampf(global_position.x, -3.5, 3.5)
	global_position.z = clampf(global_position.z, -3.5, 3.5)


func _snap_turn() -> void:
	if _snap_wait > 0.0:
		return
	var x := _right.get_vector2("primary").x
	if absf(x) < 0.6:
		return
	rotate_y(deg_to_rad(SNAP_DEG) * (-1.0 if x > 0.0 else 1.0))
	_snap_wait = SNAP_COOLDOWN


func _on_controller_button(button: String, hand: XRController3D) -> void:
	if button == "by_button" and hand == _left:
		menu_button.emit()
		return
	if button == "trigger_click":
		_try_select(hand)


func _try_select(hand: XRController3D) -> void:
	var hit := _ray_clickable(hand)
	if hit:
		hit.on_click()


func _update_hover() -> void:
	var hit: Clickable = null
	for hand in [_right, _left]:
		hit = _ray_clickable(hand)
		if hit:
			break
	if _hovered and _hovered != hit:
		_hovered.set_highlight(false)
	_hovered = hit
	if _hovered:
		_hovered.set_highlight(true)


func _ray_clickable(hand: XRController3D) -> Clickable:
	var origin := hand.global_position
	var dir := -hand.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.collider as Clickable
