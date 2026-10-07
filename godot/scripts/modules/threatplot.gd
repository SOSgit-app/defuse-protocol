class_name ThreatPlotModule
extends RefCounted

const TYPE := "threatplot"
const NAME := "Threat Plot"
const COL_LETTERS := "ABCDEFGH"
const DIRS := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("threatplot")
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var size: int = int(data.sizesByDifficulty[difficulty])
	var sam_count: int = int(data.samsByDifficulty[difficulty])
	var min_path: int = int(data.minPathByDifficulty[difficulty])
	var need_tanker := difficulty == "hard"
	var sam_weights := ["SA-3", "SA-3", "SA-6", "SA-6", "SA-2"]

	var layout = null
	for _attempt in 400:
		if layout != null:
			break
		var start := Vector2i(rng.int_range(0, size - 1), rng.int_range(0, size - 1))
		var target := Vector2i(rng.int_range(0, size - 1), rng.int_range(0, size - 1))
		if target == start:
			continue
		if absi(target.x - start.x) + absi(target.y - start.y) < 3:
			continue
		var tanker = null
		if need_tanker:
			tanker = Vector2i(rng.int_range(0, size - 1), rng.int_range(0, size - 1))
			if tanker == start or tanker == target:
				continue
		var reserved := {}
		reserved[_key(start)] = true
		reserved[_key(target)] = true
		if tanker != null:
			reserved[_key(tanker)] = true
		var open: Array = []
		for x in size:
			for y in size:
				var c := Vector2i(x, y)
				if not reserved.has(_key(c)):
					open.append(c)
		if open.size() < sam_count:
			continue
		var sam_cells: Array = rng.shuffle(open).slice(0, sam_count)
		var sams: Array = []
		for c in sam_cells:
			sams.append({"x": c.x, "y": c.y, "type": rng.pick(sam_weights)})
		var covered := _coverage_set(sams, data)
		var check: Array = [start, target]
		if tanker != null:
			check.append(tanker)
		var blocked := false
		for c in check:
			if covered.has(_key(c)):
				blocked = true
				break
		if blocked:
			continue
		var path: Variant = _find_path(size, covered, start, target, tanker)
		if path == null or (path as Array).size() < min_path:
			continue
		layout = {"size": size, "start": start, "target": target, "tanker": tanker, "sams": sams}

	if layout == null:
		layout = {
			"size": size,
			"start": Vector2i(0, 0),
			"target": Vector2i(size - 1, size - 1),
			"tanker": Vector2i(size - 1, 0) if need_tanker else null,
			"sams": [{"x": size / 2, "y": size / 2, "type": "SA-3"}]
		}

	var state := {
		"size": layout.size,
		"start": {"x": layout.start.x, "y": layout.start.y},
		"target": {"x": layout.target.x, "y": layout.target.y},
		"tanker": null if layout.tanker == null else {"x": layout.tanker.x, "y": layout.tanker.y},
		"sams": layout.sams,
		"pos": {"x": layout.start.x, "y": layout.start.y},
		"refueled": layout.tanker == null
	}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var sams: Array = []
	for s in state.sams:
		sams.append({"type": s.type, "cell": _cell_name(s)})
	return {
		"size": int(state.size),
		"start": _cell_name(state.start),
		"target": _cell_name(state.target),
		"tanker": _cell_name(state.tanker) if state.tanker else null,
		"sams": sams,
		"player": _cell_name(state.pos),
		"refueled": bool(state.refueled)
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	if str(act.get("type", "")) != "step" or not DIRS.has(act.get("dir")):
		return {"status": "ok", "view": view(state)}
	var data := ModuleData.load_json("threatplot")
	var d: Vector2i = DIRS[act.dir]
	var nx := int(state.pos.x) + d.x
	var ny := int(state.pos.y) + d.y
	var covered := _coverage_set(state.sams, data)
	var oob := nx < 0 or ny < 0 or nx >= int(state.size) or ny >= int(state.size)
	if oob or covered.has("%d,%d" % [nx, ny]):
		_reset(state)
		return {
			"status": "strike",
			"view": view(state),
			"detail": "left the grid" if oob else "entered threat coverage"
		}
	state.pos = {"x": nx, "y": ny}
	if state.tanker and nx == int(state.tanker.x) and ny == int(state.tanker.y):
		state.refueled = true
	if nx == int(state.target.x) and ny == int(state.target.y):
		if state.tanker and not state.refueled:
			_reset(state)
			return {"status": "strike", "view": view(state), "detail": "reached target without refueling"}
		return {"status": "solved", "view": view(state), "detail": "target reached"}
	return {"status": "ok", "view": view(state)}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("threatplot")
	var sam_types: Array = []
	for s in data.samTypes:
		sam_types.append({"type": s.type, "coverage": s.coverage})
	return {"intro": data.intro, "samTypes": sam_types, "rules": data.rules}


static func _cell_name(c: Dictionary) -> String:
	return "%s%d" % [COL_LETTERS[int(c.x)], int(c.y) + 1]


static func _key(c) -> String:
	if typeof(c) == TYPE_VECTOR2I:
		return "%d,%d" % [c.x, c.y]
	return "%d,%d" % [int(c.x), int(c.y)]


static func _radius_of(type: String, data: Dictionary) -> int:
	for s in data.samTypes:
		if s.type == type:
			return int(s.radius)
	return 0


static func _coverage_set(sams: Array, data: Dictionary) -> Dictionary:
	var covered := {}
	for sam in sams:
		var r := _radius_of(str(sam.type), data)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				covered["%d,%d" % [int(sam.x) + dx, int(sam.y) + dy]] = true
	return covered


static func _reset(state: Dictionary) -> void:
	state.pos = {"x": state.start.x, "y": state.start.y}
	state.refueled = state.tanker == null


static func _find_path(size: int, covered: Dictionary, start: Vector2i, target: Vector2i, tanker) -> Variant:
	var start_ref := tanker == null
	var queue: Array = [{"x": start.x, "y": start.y, "ref": start_ref, "steps": []}]
	var seen := {"%d,%d,%d" % [start.x, start.y, 1 if start_ref else 0]: true}
	while queue.size():
		var cur: Dictionary = queue.pop_front()
		if cur.x == target.x and cur.y == target.y and cur.ref:
			return cur.steps
		for dir in DIRS.keys():
			var d: Vector2i = DIRS[dir]
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			if covered.has("%d,%d" % [nx, ny]):
				continue
			var ref: bool = cur.ref or (tanker != null and nx == tanker.x and ny == tanker.y)
			var k := "%d,%d,%d" % [nx, ny, 1 if ref else 0]
			if seen.has(k):
				continue
			seen[k] = true
			var steps: Array = cur.steps.duplicate()
			steps.append(dir)
			queue.append({"x": nx, "y": ny, "ref": ref, "steps": steps})
	return null
