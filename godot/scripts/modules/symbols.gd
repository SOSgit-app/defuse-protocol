class_name SymbolsModule
extends RefCounted

const TYPE := "symbols"
const NAME := "Symbol Matching"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("symbols")
	var rng: Rng = ctx.rng
	var columns: Array = data.fixedColumns
	var target_col: int = rng.int_range(0, columns.size() - 1)
	var chosen: Array = rng.sample(columns[target_col], int(data.buttonsOnDevice))
	var solution: Array = []
	for g in columns[target_col]:
		if chosen.has(g):
			solution.append(g)
	var displayed: Array = rng.shuffle(solution)
	var state := {"displayed": displayed, "solution": solution, "progress": 0}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var symbols: Array = []
	var pressed_set: Array = state.solution.slice(0, int(state.progress))
	for glyph in state.displayed:
		symbols.append({"glyph": glyph, "pressed": pressed_set.has(glyph)})
	return {
		"symbols": symbols,
		"progress": int(state.progress),
		"total": state.solution.size()
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	if str(act.get("type", "")) != "press":
		return {"status": "ok", "view": view(state)}
	var glyph = act.get("glyph")
	if not state.displayed.has(glyph):
		return {"status": "ok", "view": view(state)}
	var pressed_set: Array = state.solution.slice(0, int(state.progress))
	if pressed_set.has(glyph):
		return {"status": "ok", "view": view(state)}
	if glyph == state.solution[int(state.progress)]:
		state.progress = int(state.progress) + 1
		if int(state.progress) >= state.solution.size():
			return {"status": "solved", "view": view(state), "detail": "sequence complete"}
		return {"status": "ok", "view": view(state)}
	state.progress = 0
	return {"status": "strike", "view": view(state), "detail": "wrong glyph %s" % str(glyph)}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("symbols")
	return {"intro": data.intro, "columns": data.fixedColumns}
