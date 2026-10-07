class_name ModuleUI
extends RefCounted
## Shared clickable plates / readouts for module bays.


static func make_button(label: String, size: Vector3, bg: Color, fg: Color = Color(0.07, 0.08, 0.1)) -> Clickable:
	var hit := Clickable.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = bg
	mat.roughness = 0.55
	mesh.material_override = mat
	mesh.position.y = size.y * 0.5
	hit.add_child(mesh)

	var text := Label3D.new()
	text.text = label
	text.font_size = 42
	text.pixel_size = 0.0011
	text.modulate = fg
	text.position = Vector3(0, size.y + 0.001, 0)
	text.rotation_degrees = Vector3(-90, 0, 0)
	hit.add_child(text)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y * 0.5
	hit.add_child(col)

	hit.highlight_meshes = [mesh]
	hit.set_meta("label3d", text)
	hit.set_meta("face_mat", mat)
	return hit


static func set_button_label(btn: Clickable, label: String) -> void:
	var text: Label3D = btn.get_meta("label3d")
	if text:
		text.text = label


static func set_button_colors(btn: Clickable, bg: Color, fg: Color = Color(0.07, 0.08, 0.1)) -> void:
	var mat: StandardMaterial3D = btn.get_meta("face_mat")
	if mat:
		mat.albedo_color = bg
	var text: Label3D = btn.get_meta("label3d")
	if text:
		text.modulate = fg


static func make_readout(w: float, h: float, color: Color = Color(0.22, 0.85, 0.54)) -> Label3D:
	var label := Label3D.new()
	label.font_size = 36
	label.pixel_size = 0.0012
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0, 0.001, 0)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.set_meta("plane_w", w)
	label.set_meta("plane_h", h)
	return label


static func make_housing(size: Vector3, color: Color = Color(0.1, 0.12, 0.15)) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.5
	mesh.material_override = mat
	return mesh
