class_name LogicGridModule
extends RefCounted

const TYPE := "logicgrid"
const NAME := "Joint Functions"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("logicgrid")
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var n: int = int(data.entitiesByDifficulty[difficulty])
	var names: Array = data.engineers.slice(0, n)
	var functions: Array = data.panels.slice(0, n)
	var phases: Array = data.shifts.slice(0, n)
	var idx: Array = []
	for i in n:
		idx.append(i)
	var truth := {"panels": rng.shuffle(idx.duplicate()), "shifts": rng.shuffle(idx.duplicate())}

	var all_candidates: Array = []
	for pp in _permutations(idx):
		for sp in _permutations(idx):
			all_candidates.append({"panels": pp, "shifts": sp})

	var clues: Array = []
	var candidates := all_candidates
	var guard := 0
	while candidates.size() > 1 and guard < 60:
		guard += 1
		var clue := _random_true_clue(rng, truth, n)
		var filtered: Array = []
		for c in candidates:
			if _clue_holds(clue, c):
				filtered.append(c)
		if filtered.size() < candidates.size():
			clues.append(clue)
			candidates = filtered

	var clue_lines: Array = []
	for c in rng.shuffle(clues):
		clue_lines.append(_clue_text(c, names, functions, phases))

	var question_count: int = int(data.questionsByDifficulty[difficulty])
	var questions: Array = []
	var q_types: Array = rng.shuffle(["panelOf", "engineerOfShift"])
	for q in range(question_count):
		var t: String = q_types[q % q_types.size()]
		if t == "panelOf":
			var e := rng.int_range(0, n - 1)
			questions.append({
				"text": "Which joint function does %s own?" % names[e],
				"options": functions.duplicate(),
				"answer": functions[truth.panels[e]]
			})
		else:
			var s := rng.int_range(0, n - 1)
			var e: int = int(truth.shifts.find(s))
			questions.append({
				"text": "Which captain leads the %s phase?" % phases[s],
				"options": names.duplicate(),
				"answer": names[e]
			})

	var state := {"questions": questions, "stage": 0, "clues": clue_lines, "clueIndex": 0}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var q = null
	if int(state.stage) < state.questions.size():
		q = state.questions[int(state.stage)]
	return {
		"stage": int(state.stage) + 1,
		"totalStages": state.questions.size(),
		"question": q.text if q else null,
		"options": q.options if q else [],
		"clues": state.clues,
		"clueIndex": int(state.clueIndex)
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	match str(act.get("type", "")):
		"nextClue":
			if state.clues.size():
				state.clueIndex = (int(state.clueIndex) + 1) % state.clues.size()
			return {"status": "ok", "view": view(state)}
		"answer":
			if int(state.stage) >= state.questions.size():
				return {"status": "ok", "view": view(state)}
			var q: Dictionary = state.questions[int(state.stage)]
			var option = act.get("option")
			if not q.options.has(option):
				return {"status": "ok", "view": view(state)}
			if option == q.answer:
				state.stage = int(state.stage) + 1
				if int(state.stage) >= state.questions.size():
					return {"status": "solved", "view": view(state), "detail": "all questions answered"}
				return {"status": "ok", "view": view(state), "detail": "question passed"}
			return {
				"status": "strike",
				"view": view(state),
				"detail": "wrong answer %s, expected %s" % [str(option), str(q.answer)]
			}
		_:
			return {"status": "ok", "view": view(state)}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("logicgrid")
	var labels = data.get("labels", {
		"engineers": "Captains",
		"panels": "Joint Functions",
		"shifts": "Phases"
	})
	return {
		"intro": data.intro,
		"rosterNote": data.get("rosterNote", ""),
		"labels": labels,
		"entities": {
			"engineers": data.engineers,
			"panels": data.panels,
			"shifts": data.shifts
		},
		"clues": [
			"Copy the example roster onto scrap paper, leaving Joint Functions and Phases blank.",
			"Ask the Defuser to read all INTERCEPTED NOTES from the clipboard on the table.",
			"Assign each captain exactly one joint function and one phase.",
			"Then answer the question shown on the device."
		]
	}


static func _permutations(arr: Array) -> Array:
	if arr.size() <= 1:
		return [arr.duplicate()]
	var out: Array = []
	for i in arr.size():
		var rest := arr.duplicate()
		rest.remove_at(i)
		for p in _permutations(rest):
			var row: Array = [arr[i]]
			row.append_array(p)
			out.append(row)
	return out


static func _clue_holds(clue: Dictionary, asg: Dictionary) -> bool:
	match str(clue.kind):
		"panel":
			return asg.panels[clue.e] == clue.p
		"panelNot":
			return asg.panels[clue.e] != clue.p
		"shift":
			return asg.shifts[clue.e] == clue.s
		"shiftNot":
			return asg.shifts[clue.e] != clue.s
		"cross":
			return asg.shifts[asg.panels.find(clue.p)] == clue.s
		"crossNot":
			return asg.shifts[asg.panels.find(clue.p)] != clue.s
		_:
			return true


static func _clue_text(clue: Dictionary, names: Array, functions: Array, phases: Array) -> String:
	match str(clue.kind):
		"panel":
			return "%s owns the %s function." % [names[clue.e], functions[clue.p]]
		"panelNot":
			return "%s does not own the %s function." % [names[clue.e], functions[clue.p]]
		"shift":
			return "%s leads the %s phase." % [names[clue.e], phases[clue.s]]
		"shiftNot":
			return "%s does not lead the %s phase." % [names[clue.e], phases[clue.s]]
		"cross":
			return "The captain owning %s leads the %s phase." % [functions[clue.p], phases[clue.s]]
		"crossNot":
			return "The captain owning %s does not lead the %s phase." % [functions[clue.p], phases[clue.s]]
		_:
			return ""


static func _random_true_clue(rng: Rng, truth: Dictionary, n: int) -> Dictionary:
	var e := rng.int_range(0, n - 1)
	var kind: String = rng.pick([
		"panelNot", "shiftNot", "cross", "crossNot", "panel", "shift", "panelNot", "shiftNot", "crossNot"
	])
	match kind:
		"panel":
			return {"kind": kind, "e": e, "p": truth.panels[e]}
		"shift":
			return {"kind": kind, "e": e, "s": truth.shifts[e]}
		"panelNot":
			var p := e
			while p == truth.panels[e]:
				p = rng.int_range(0, n - 1)
			return {"kind": kind, "e": e, "p": p}
		"shiftNot":
			var s := e
			while s == truth.shifts[e]:
				s = rng.int_range(0, n - 1)
			return {"kind": kind, "e": e, "s": s}
		"cross":
			var p2 := rng.int_range(0, n - 1)
			return {"kind": kind, "p": p2, "s": truth.shifts[truth.panels.find(p2)]}
		_:
			var p3 := rng.int_range(0, n - 1)
			var s3: int = int(truth.shifts[truth.panels.find(p3)])
			var s_bad: int = s3
			while s_bad == s3:
				s_bad = rng.int_range(0, n - 1)
			return {"kind": "crossNot", "p": p3, "s": s_bad}
