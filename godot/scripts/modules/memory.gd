class_name MemoryModule
extends RefCounted

const TYPE := "memory"
const NAME := "Memory Sequence"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("memory")
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var stages: int = int(data.stagesByDifficulty.get(difficulty, data.stages))
	var buttons: int = int(data.buttons)
	var table: Array = data.table.slice(0, stages)
	var stage_rng := rng.child("stages")
	var state := {
		"stages": stages,
		"buttons": buttons,
		"table": table,
		"stage": 1,
		"history": [],
		"current": _new_stage(stage_rng, buttons),
		"_stage_rng": stage_rng
	}
	return {"state": state, "manual": fixed_manual(stages), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	return {
		"stage": int(state.stage),
		"totalStages": int(state.stages),
		"display": int(state.current.display),
		"labels": state.current.labels
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	if str(act.get("type", "")) != "press":
		return {"status": "ok", "view": view(state)}
	var pos := int(act.get("position", 0))
	if pos < 1 or pos > int(state.buttons):
		return {"status": "ok", "view": view(state)}
	var row: Dictionary = state.table[int(state.stage) - 1]
	var ins: Dictionary = row[str(int(state.current.display))]
	var correct := _correct_position(ins, state.current, state.history)
	var stage_rng: Rng = state._stage_rng
	if pos == correct:
		state.history.append({
			"position": pos,
			"label": state.current.labels[pos - 1]
		})
		if int(state.stage) >= int(state.stages):
			return {"status": "solved", "view": view(state), "detail": "all stages complete"}
		state.stage = int(state.stage) + 1
		state.current = _new_stage(stage_rng, int(state.buttons))
		return {"status": "ok", "view": view(state), "detail": "stage %d passed" % (int(state.stage) - 1)}
	state.stage = 1
	state.history = []
	state.current = _new_stage(stage_rng, int(state.buttons))
	return {
		"status": "strike",
		"view": view(state),
		"detail": "wrong position %d, expected %d; reset to stage 1" % [pos, correct]
	}


static func fixed_manual(stages: int = 5) -> Dictionary:
	var data := ModuleData.load_json("memory")
	var n := stages if stages > 0 else int(data.stages)
	var ordinals := ["first", "second", "third", "fourth"]
	var stage_rows: Array = []
	for i in n:
		var row: Dictionary = data.table[i]
		var rules: Array = []
		for d in row.keys():
			var ins: Dictionary = row[d]
			rules.append("If the display shows %s, %s." % [d, _instruction_text(ins, ordinals)])
		stage_rows.append({"title": "Stage %d" % (i + 1), "rules": rules})
	return {"intro": data.intro, "stages": stage_rows}


static func _new_stage(rng: Rng, buttons: int) -> Dictionary:
	var labels: Array = []
	for i in buttons:
		labels.append(i + 1)
	return {"display": rng.int_range(1, buttons), "labels": rng.shuffle(labels)}


static func _correct_position(ins: Dictionary, stage_data: Dictionary, history: Array) -> int:
	match str(ins.kind):
		"position":
			return int(ins.n)
		"label":
			return stage_data.labels.find(ins.n) + 1
		"samePosition":
			return int(history[int(ins.stage) - 1].position)
		"sameLabel":
			return stage_data.labels.find(history[int(ins.stage) - 1].label) + 1
		_:
			return 1


static func _instruction_text(ins: Dictionary, ordinals: Array) -> String:
	match str(ins.kind):
		"position":
			return "press the button in the %s position" % ordinals[int(ins.n) - 1]
		"label":
			return "press the button labeled \"%s\"" % str(ins.n)
		"samePosition":
			return "press the button in the same position as you pressed in stage %s" % str(ins.stage)
		"sameLabel":
			return "press the button with the same label as you pressed in stage %s" % str(ins.stage)
		_:
			return "?"
