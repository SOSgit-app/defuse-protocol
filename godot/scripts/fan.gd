class_name DeskFan
extends Node3D
## Desk fan — brief burst kills the fly.

signal toggled(on: bool)

var on: bool = false
var _until: float = 0.0
var _blades: Node3D
var _led_mat: StandardMaterial3D
var hit: Clickable


func _ready() -> void:
	_build()
	set_process(true)


func _process(delta: float) -> void:
	if _until > 0.0:
		_until -= delta
		if _blades:
			_blades.rotation.z += delta * 22.0
		if _until <= 0.0:
			on = false
			if _led_mat:
				_led_mat.emission_energy_multiplier = 0.0
			toggled.emit(false)


func set_visible_fan(v: bool) -> void:
	visible = v
	if hit:
		hit.enabled = v


func _build() -> void:
	position = Vector3(-0.95, 0, 0.62)
	rotation.y = 0.55
	var base := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = 0.075
	bmesh.bottom_radius = 0.09
	bmesh.height = 0.028
	base.mesh = bmesh
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.23, 0.24, 0.28)
	base.material_override = bmat
	base.position.y = 0.014
	add_child(base)

	var stem := MeshInstance3D.new()
	var smesh := CylinderMesh.new()
	smesh.top_radius = 0.012
	smesh.bottom_radius = 0.016
	smesh.height = 0.15
	stem.mesh = smesh
	stem.material_override = bmat
	stem.position.y = 0.1
	add_child(stem)

	var head := Node3D.new()
	head.position = Vector3(0.02, 0.19, 0)
	add_child(head)
	var motor := MeshInstance3D.new()
	var mmesh := CylinderMesh.new()
	mmesh.top_radius = 0.042
	mmesh.bottom_radius = 0.048
	mmesh.height = 0.055
	motor.mesh = mmesh
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.85, 0.83, 0.8)
	motor.material_override = pmat
	motor.rotation_degrees.x = 90
	head.add_child(motor)

	_blades = Node3D.new()
	_blades.position.z = 0.026
	head.add_child(_blades)
	for i in 3:
		var blade := MeshInstance3D.new()
		var bl := BoxMesh.new()
		bl.size = Vector3(0.08, 0.022, 0.002)
		blade.mesh = bl
		blade.position.x = 0.04
		var pivot := Node3D.new()
		pivot.rotation.z = (float(i) / 3.0) * TAU
		pivot.add_child(blade)
		_blades.add_child(pivot)

	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(0.1, 0.05, 0.05)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(0.22, 0.85, 0.54)
	_led_mat.emission_energy_multiplier = 0.0
	var led := MeshInstance3D.new()
	var lmesh := SphereMesh.new()
	lmesh.radius = 0.006
	led.mesh = lmesh
	led.material_override = _led_mat
	led.position = Vector3(0.04, 0.03, 0.04)
	add_child(led)

	hit = Clickable.new()
	hit.position = Vector3(0, 0.12, 0.03)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.16, 0.28, 0.16)
	col.shape = shape
	hit.add_child(col)
	hit.clicked.connect(_on_click)
	add_child(hit)
	visible = false
	hit.enabled = false


func _on_click() -> void:
	if on or not visible:
		return
	on = true
	_until = 3.0
	_led_mat.emission_energy_multiplier = 1.4
	Sound.fan_hum(true)
	toggled.emit(true)
