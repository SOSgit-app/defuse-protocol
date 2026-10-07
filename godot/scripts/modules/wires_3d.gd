class_name Wires3D
extends Node3D
## Wire Cutting bay — port of public/js/three/modules3d/wires3d.js

signal cut_requested(index: int)

const WIRE_COLORS := {
	"red": Color(0.85, 0.17, 0.23),
	"blue": Color(0.15, 0.39, 0.85),
	"yellow": Color(0.88, 0.74, 0.16),
	"white": Color(0.90, 0.89, 0.85),
	"black": Color(0.09, 0.09, 0.11),
	"green": Color(0.15, 0.64, 0.32)
}

var _entries: Array = []


func build(view: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_entries.clear()

	var wires: Array = view.get("wires", [])
	var n := wires.size()
	if n == 0:
		return
	var spacing := mini(0.052, 0.24 / float(n))
	var z0 := -((n - 1) / 2.0) * spacing

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.009
	post_mesh.bottom_radius = 0.011
	post_mesh.height = 0.03
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.72, 0.72, 0.74)
	post_mat.metallic = 0.9
	post_mat.roughness = 0.35

	for i in n:
		var w: Dictionary = wires[i]
		var z := z0 + i * spacing
		var sag := 0.004 + (i % 3) * 0.003
		var color: Color = WIRE_COLORS.get(str(w.color), Color(0.5, 0.5, 0.5))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5 if str(w.color) == "black" else 0.38
		mat.metallic = 0.05

		var intact := _make_wire_mesh(
			Vector3(-0.115, 0.024, z),
			Vector3(0.115, 0.024, z),
			0.0058,
			sag,
			mat
		)
		add_child(intact)

		var cut_group := Node3D.new()
		cut_group.visible = false
		add_child(cut_group)
		var left_half := _make_wire_mesh(
			Vector3(-0.115, 0.024, z),
			Vector3(-0.022, 0.006, z),
			0.0058,
			sag,
			mat
		)
		var right_half := _make_wire_mesh(
			Vector3(0.115, 0.024, z),
			Vector3(0.022, 0.006, z),
			0.0058,
			sag * 0.8,
			mat
		)
		cut_group.add_child(left_half)
		cut_group.add_child(right_half)

		for x in [-0.115, 0.115]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = post_mat
			post.position = Vector3(x, 0.012, z)
			add_child(post)

		var hit := Clickable.new()
		hit.position = Vector3(0, 0.02, z)
		var box := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.23, 0.028, mini(spacing * 0.9, 0.034))
		box.shape = shape
		hit.add_child(box)
		hit.highlight_meshes = [intact]
		var wire_index := i + 1
		hit.clicked.connect(func(): cut_requested.emit(wire_index))
		add_child(hit)

		_entries.append({"intact": intact, "cut_group": cut_group, "hit": hit})

	update_view(view)


func update_view(view: Dictionary) -> void:
	var wires: Array = view.get("wires", [])
	for i in mini(_entries.size(), wires.size()):
		var cut := bool(wires[i].cut)
		_entries[i].intact.visible = not cut
		_entries[i].cut_group.visible = cut
		_entries[i].hit.enabled = not cut


func _make_wire_mesh(a: Vector3, b: Vector3, radius: float, sag: float, mat: Material) -> MeshInstance3D:
	var mid := (a + b) * 0.5
	mid.y -= sag
	var dir := b - a
	var length := maxf(0.001, dir.length())
	var mesh := BoxMesh.new()
	mesh.size = Vector3(radius * 2.0, radius * 2.0, length)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	if dir.length_squared() > 1e-8:
		inst.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), mid)
	else:
		inst.position = mid
	return inst
