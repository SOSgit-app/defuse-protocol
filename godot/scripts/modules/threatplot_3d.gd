class_name ThreatPlot3D
extends Node3D

signal step_requested(dir: String)

var _scope: Label3D
var _status: Label3D


func build(view: Dictionary) -> void:
	_clear()
	var housing := ModuleUI.make_housing(Vector3(0.26, 0.04, 0.18), Color(0.08, 0.12, 0.1))
	housing.position = Vector3(0, 0.02, -0.04)
	add_child(housing)
	_scope = ModuleUI.make_readout(0.24, 0.14, Color(0.35, 0.95, 0.55))
	_scope.font_size = 20
	_scope.position = Vector3(0, 0.042, -0.04)
	add_child(_scope)
	_status = ModuleUI.make_readout(0.24, 0.03, Color(0.85, 0.9, 0.8))
	_status.font_size = 22
	_status.position = Vector3(0, 0.042, 0.06)
	add_child(_status)

	_add_pad("N", Vector3(0.0, 0, 0.11), "N")
	_add_pad("W", Vector3(-0.05, 0, 0.15), "W")
	_add_pad("S", Vector3(0.0, 0, 0.15), "S")
	_add_pad("E", Vector3(0.05, 0, 0.15), "E")
	update_view(view)


func update_view(view: Dictionary) -> void:
	var size := int(view.get("size", 5))
	var player := str(view.get("player", "A1"))
	var target := str(view.get("target", "?"))
	var start := str(view.get("start", "?"))
	var tanker = view.get("tanker")
	var sams: Array = view.get("sams", [])
	var grid := _ascii_grid(size, player, target, start, tanker, sams)
	if _scope:
		_scope.text = grid
	if _status:
		_status.text = "JET %s · TGT %s · FUEL %s" % [
			player, target, "OK" if view.get("refueled") else "NEED TANKER"
		]


func _ascii_grid(size: int, player: String, target: String, start: String, tanker, sams: Array) -> String:
	var sam_cells := {}
	for s in sams:
		sam_cells[str(s.cell)] = str(s.type)
	var lines: PackedStringArray = []
	for y in size:
		var row := ""
		for x in size:
			var cell := "%s%d" % ["ABCDEFGH"[x], y + 1]
			var ch := "·"
			if cell == player:
				ch = "J"
			elif cell == target:
				ch = "T"
			elif tanker != null and cell == str(tanker):
				ch = "R"
			elif cell == start:
				ch = "S"
			elif sam_cells.has(cell):
				ch = "▲"
			row += ch + " "
		lines.append(row.strip_edges())
	return "\n".join(lines)


func _add_pad(label: String, pos: Vector3, dir: String) -> void:
	var btn := ModuleUI.make_button(label, Vector3(0.04, 0.025, 0.035), Color(0.75, 0.8, 0.85))
	btn.position = pos
	btn.clicked.connect(func(): step_requested.emit(dir))
	add_child(btn)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_scope = null
	_status = null
