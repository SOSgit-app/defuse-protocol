class_name Clickable
extends StaticBody3D
## Raycast / mouse target. Call on_click when selected.

signal clicked

var enabled: bool = true
var highlight_meshes: Array[MeshInstance3D] = []


func on_click() -> void:
	if enabled:
		clicked.emit()


func set_highlight(on: bool) -> void:
	for mesh in highlight_meshes:
		if mesh == null or mesh.material_override == null:
			continue
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null:
			continue
		if on:
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.35, 0.2)
			mat.emission_energy_multiplier = 0.6
		else:
			mat.emission_energy_multiplier = 0.0
