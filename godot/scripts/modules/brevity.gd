class_name BrevityModule
extends RefCounted

const TYPE := "brevity"
const NAME := "Brevity Code"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("brevity")
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var count: int = int(data.stagesByDifficulty[difficulty])
	var stages: Array = []
	for _i in count:
		stages.append(_make_stage(rng, data))
	var state := {"stages": stages, "stage": 0}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var s = null
	if int(state.stage) < state.stages.size():
		s = state.stages[int(state.stage)]
	return {
		"stage": int(state.stage) + 1,
		"total": state.stages.size(),
		"display": s.display if s else null,
		"buttons": s.buttons if s else []
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	if str(act.get("type", "")) != "press":
		return {"status": "ok", "view": view(state)}
	if int(state.stage) >= state.stages.size():
		return {"status": "ok", "view": view(state)}
	var s: Dictionary = state.stages[int(state.stage)]
	var label = act.get("label")
	if not s.buttons.has(label):
		return {"status": "ok", "view": view(state)}
	if label == s.answer:
		state.stage = int(state.stage) + 1
		if int(state.stage) >= state.stages.size():
			return {"status": "solved", "view": view(state), "detail": "all brevity stages cleared"}
		return {"status": "ok", "view": view(state), "detail": "stage cleared"}
	return {"status": "strike", "view": view(state), "detail": "pressed %s, expected %s" % [str(label), str(s.answer)]}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("brevity")
	var table1: Array = []
	var table2: Array = []
	for w in data.words:
		table1.append({"word": w, "position": data.displayRead[w]})
		table2.append({"read": w, "press": data.readPress[w]})
	return {"intro": data.intro, "table1": table1, "table2": table2}


static func _make_stage(rng: Rng, data: Dictionary) -> Dictionary:
	var display: String = rng.pick(data.words)
	var read_pos: int = int(data.displayRead[display])
	for _attempt in 300:
		var buttons: Array = rng.shuffle(data.words.duplicate()).slice(0, 6)
		var read_word = buttons[read_pos - 1]
		var answer = data.readPress[read_word]
		if buttons.has(answer):
			return {"display": display, "buttons": buttons, "answer": answer}
	var buttons2: Array = rng.shuffle(data.words.duplicate()).slice(0, 6)
	var read_word2 = buttons2[read_pos - 1]
	var answer2 = data.readPress[read_word2]
	buttons2[read_pos % 6] = answer2
	return {"display": display, "buttons": buttons2, "answer": answer2}
