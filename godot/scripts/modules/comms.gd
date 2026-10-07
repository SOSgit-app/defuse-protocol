class_name CommsModule
extends RefCounted

const TYPE := "comms"
const NAME := "Radio Net"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("comms")
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var rounds_wanted: int = int(data.roundsByDifficulty[difficulty])
	var calls: Array = rng.shuffle(data.callsigns.duplicate()).slice(0, rounds_wanted)
	var rounds: Array = []
	for c in calls:
		var row := rng.int_range(0, data.matrixLabels.size() - 1)
		var col := rng.int_range(0, data.matrixLabels.size() - 1)
		rounds.append({
			"call": c.call,
			"answerIdx": _idx_of(float(c.freq), data),
			"challenge": "%s · %s" % [data.matrixLabels[row], data.matrixLabels[col]],
			"answer": data.matrix[row][col]
		})
	var state := {
		"rounds": rounds,
		"round": 0,
		"phase": "net",
		"freqIdx": 0,
		"letterIdx": 0
	}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("comms")
	var r = null
	if int(state.round) < state.rounds.size():
		r = state.rounds[int(state.round)]
	return {
		"round": mini(int(state.round) + 1, state.rounds.size()),
		"total": state.rounds.size(),
		"phase": state.phase if r else "done",
		"prompt": (r.call if state.phase == "net" else r.challenge) if r else null,
		"freq": _freq_at(int(state.freqIdx), data),
		"letter": char(65 + int(state.letterIdx))
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	var data := ModuleData.load_json("comms")
	var steps: int = int(data.band.steps)
	var r = null
	if int(state.round) < state.rounds.size():
		r = state.rounds[int(state.round)]
	match str(act.get("type", "")):
		"tune":
			var delta := int(act.get("steps", 0))
			state.freqIdx = clampi(int(state.freqIdx) + delta, 0, steps - 1)
			return {"status": "ok", "view": view(state)}
		"letter":
			var d := int(act.get("delta", 0))
			state.letterIdx = ((int(state.letterIdx) + d) % 26 + 26) % 26
			return {"status": "ok", "view": view(state)}
		"xmit":
			if r == null or state.phase != "net":
				return {"status": "ok", "view": view(state)}
			if int(state.freqIdx) == int(r.answerIdx):
				state.phase = "auth"
				return {"status": "ok", "view": view(state), "detail": "net established on %s" % _freq_at(int(state.freqIdx), data)}
			return {
				"status": "strike",
				"view": view(state),
				"detail": "keyed %s, expected %s" % [_freq_at(int(state.freqIdx), data), _freq_at(int(r.answerIdx), data)]
			}
		"auth":
			if r == null or state.phase != "auth":
				return {"status": "ok", "view": view(state)}
			var letter := char(65 + int(state.letterIdx))
			if letter == r.answer:
				state.round = int(state.round) + 1
				state.phase = "net"
				if int(state.round) >= state.rounds.size():
					return {"status": "solved", "view": view(state), "detail": "all nets authenticated"}
				return {"status": "ok", "view": view(state), "detail": "authentication valid"}
			return {"status": "strike", "view": view(state), "detail": "bad auth %s, expected %s" % [letter, r.answer]}
		_:
			return {"status": "ok", "view": view(state)}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("comms")
	var callsigns: Array = []
	for c in data.callsigns:
		callsigns.append({"call": c.call, "net": c.net, "freq": "%.2f" % float(c.freq)})
	return {
		"intro": data.intro,
		"callsigns": callsigns,
		"matrixLabels": data.matrixLabels,
		"matrix": data.matrix
	}


static func _freq_at(idx: int, data: Dictionary) -> String:
	return "%.2f" % (float(data.band.start) + float(idx) * float(data.band.step))


static func _idx_of(freq: float, data: Dictionary) -> int:
	return int(round((freq - float(data.band.start)) / float(data.band.step)))
