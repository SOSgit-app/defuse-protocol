class_name WiresModule
extends RefCounted
## Wire Cutting — port of server/modules/wires.js

const TYPE := "wires"
const NAME := "Wire Cutting"

static var _data: Dictionary = {}


static func ensure_data() -> void:
	if not _data.is_empty():
		return
	var path := "res://data/modules/wires.json"
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "Missing %s" % path)
	var parsed = JSON.parse_string(f.get_as_text())
	assert(typeof(parsed) == TYPE_DICTIONARY, "wires.json must be an object")
	_data = parsed


static func generate(ctx: Dictionary) -> Dictionary:
	ensure_data()
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var serial: String = ctx.serial
	var counts: Array = _data.wireCountsByDifficulty[difficulty]
	var wire_count: int = rng.int_range(int(counts[0]), int(counts[1]))
	var colors: Array = _data.colors
	var wires: Array = []
	for _i in wire_count:
		wires.append(rng.pick(colors))
	var rule_set: Array = _data.ruleSets[str(wire_count)]
	var solution: int = _solve(rule_set, wires, serial)
	var cut: Array = []
	for _i in wire_count:
		cut.append(false)
	var state := {"wires": wires, "cut": cut, "solution": solution}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var out: Array = []
	var wires: Array = state.wires
	var cut: Array = state.cut
	for i in wires.size():
		out.append({"color": wires[i], "cut": cut[i]})
	return {"wires": out}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	if str(act.get("type", "")) != "cut":
		return {"status": "ok", "view": view(state)}
	var idx := int(act.get("index", 0))
	var wires: Array = state.wires
	var cut: Array = state.cut
	if idx < 1 or idx > wires.size() or cut[idx - 1]:
		return {"status": "ok", "view": view(state)}
	cut[idx - 1] = true
	if idx == int(state.solution):
		return {"status": "solved", "view": view(state), "detail": "cut wire %d" % idx}
	return {
		"status": "strike",
		"view": view(state),
		"detail": "wrong wire %d, expected %d" % [idx, int(state.solution)]
	}


static func fixed_manual() -> Dictionary:
	ensure_data()
	var keys: Array = _data.ruleSets.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	var sections: Array = []
	for n in keys:
		var rules: Array = []
		for r in _data.ruleSets[n]:
			rules.append(r.text)
		sections.append({"title": "If the device has %s wires" % n, "rules": rules})
	return {"intro": _data.intro, "sections": sections}


static func _count_color(wires: Array, c: String) -> int:
	var n := 0
	for w in wires:
		if w == c:
			n += 1
	return n


static func _serial_odd(serial: String) -> bool:
	return int(serial[serial.length() - 1]) % 2 == 1


static func _condition_matches(cond, wires: Array, serial: String) -> bool:
	if cond == null:
		return true
	if typeof(cond) != TYPE_DICTIONARY:
		return true
	match str(cond.get("key", "")):
		"noneOfColor":
			return _count_color(wires, cond.color) == 0
		"exactlyOneOfColor":
			return _count_color(wires, cond.color) == 1
		"moreThanOneOfColor":
			return _count_color(wires, cond.color) > 1
		"lastWireIs":
			return wires[wires.size() - 1] == cond.color
		"serialOdd":
			return _serial_odd(serial)
		"moreThanOneRedAndSerialOdd":
			return _count_color(wires, "red") > 1 and _serial_odd(serial)
		"lastYellowAndNoRed":
			return wires[wires.size() - 1] == "yellow" and _count_color(wires, "red") == 0
		"lastBlackAndSerialOdd":
			return wires[wires.size() - 1] == "black" and _serial_odd(serial)
		"oneRedAndMoreYellow":
			return _count_color(wires, "red") == 1 and _count_color(wires, "yellow") > 1
		"noYellowAndSerialOdd":
			return _count_color(wires, "yellow") == 0 and _serial_odd(serial)
		"oneYellowAndMoreWhite":
			return _count_color(wires, "yellow") == 1 and _count_color(wires, "white") > 1
		_:
			return false


static func _resolve_action(act: Dictionary, wires: Array) -> int:
	match str(act.get("key", "")):
		"cutIndex":
			return int(act.index)
		"cutFirstOfColor":
			return wires.find(act.color) + 1
		"cutLastOfColor":
			return _last_index(wires, act.color) + 1
		_:
			return 1


static func _last_index(arr: Array, value: Variant) -> int:
	for i in range(arr.size() - 1, -1, -1):
		if arr[i] == value:
			return i
	return -1


static func _solve(rule_set: Array, wires: Array, serial: String) -> int:
	for rule in rule_set:
		if _condition_matches(rule.get("cond"), wires, serial):
			return _resolve_action(rule.act, wires)
	return 1
