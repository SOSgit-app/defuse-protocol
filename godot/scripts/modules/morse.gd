class_name MorseModule
extends RefCounted

const TYPE := "morse"
const NAME := "Morse Code"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("morse")
	var rng: Rng = ctx.rng
	var entries: Array = []
	for e in data.table:
		entries.append({"word": e.word, "freq": snapped(float(e.freq), 0.001)})
	entries.sort_custom(func(a, b): return a.freq < b.freq)
	var word: String = rng.pick(entries).word
	var solution_freq := 0.0
	for e in entries:
		if e.word == word:
			solution_freq = e.freq
			break
	var pattern: Array = []
	for i in word.length():
		var ch := word[i]
		pattern.append(data.alphabet[ch])
	var state := {
		"word": word,
		"solutionFreq": solution_freq,
		"frequencies": entries.map(func(e): return e.freq),
		"selected": 0,
		"pattern": pattern
	}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	return {
		"pattern": state.pattern,
		"frequencies": state.frequencies,
		"selected": int(state.selected)
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	match str(act.get("type", "")):
		"tune":
			var idx := int(act.get("index", -1))
			if idx >= 0 and idx < state.frequencies.size():
				state.selected = idx
			return {"status": "ok", "view": view(state)}
		"transmit":
			var freq = state.frequencies[int(state.selected)]
			if is_equal_approx(float(freq), float(state.solutionFreq)):
				return {"status": "solved", "view": view(state), "detail": "transmitted %s" % str(freq)}
			return {
				"status": "strike",
				"view": view(state),
				"detail": "transmitted %s, expected %s" % [str(freq), str(state.solutionFreq)]
			}
		_:
			return {"status": "ok", "view": view(state)}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("morse")
	var table: Array = []
	for e in data.table:
		table.append({"word": e.word, "freq": "%.3f MHz" % float(e.freq)})
	return {"intro": data.intro, "alphabet": data.alphabet, "table": table}
