class_name OrdnanceModule
extends RefCounted

const TYPE := "ordnance"
const NAME := "Weapons Release"


static func generate(ctx: Dictionary) -> Dictionary:
	var data := ModuleData.load_json("ordnance")
	var rng: Rng = ctx.rng
	var difficulty: String = ctx.difficulty
	var serial: String = ctx.serial
	var count: int = int(data.targetsByDifficulty[difficulty])
	var targets: Array = []
	for _i in count:
		targets.append(_make_target(rng, serial, data))
	var weapons: Array = []
	for w in data.weapons:
		weapons.append(w.id)
	var state := {
		"targets": targets,
		"index": 0,
		"masterArm": false,
		"station": 0,
		"fuze": "NOSE",
		"code": [0, 0, 0],
		"weapons": weapons
	}
	return {"state": state, "manual": fixed_manual(), "view": view(state)}


static func view(state: Dictionary) -> Dictionary:
	var all_serviced: bool = int(state.index) >= (state.targets as Array).size()
	var t = null if all_serviced else state.targets[int(state.index)]
	return {
		"index": mini(int(state.index) + 1, state.targets.size()),
		"total": state.targets.size(),
		"card": _describe(t) if t else null,
		"allServiced": all_serviced,
		"masterArm": bool(state.masterArm),
		"weapon": state.weapons[int(state.station)],
		"fuze": state.fuze,
		"code": state.code.duplicate()
	}


static func action(state: Dictionary, act: Dictionary, _ctx: Dictionary = {}) -> Dictionary:
	var all_serviced: bool = int(state.index) >= (state.targets as Array).size()
	match str(act.get("type", "")):
		"arm":
			state.masterArm = not bool(state.masterArm)
			if not state.masterArm and all_serviced:
				return {"status": "solved", "view": view(state), "detail": "weapons safe, all targets serviced"}
			return {"status": "ok", "view": view(state)}
		"station":
			state.station = (int(state.station) + 1) % state.weapons.size()
			return {"status": "ok", "view": view(state)}
		"fuze":
			state.fuze = "TAIL" if state.fuze == "NOSE" else "NOSE"
			return {"status": "ok", "view": view(state)}
		"wheel":
			var i := int(act.get("index", -1))
			if i >= 0 and i <= 2:
				state.code[i] = (int(state.code[i]) + 1) % 10
			return {"status": "ok", "view": view(state)}
		"pickle":
			if all_serviced:
				return {"status": "ok", "view": view(state)}
			if not state.masterArm:
				return {"status": "ok", "view": view(state), "detail": "pickle with MASTER ARM safe"}
			var t: Dictionary = state.targets[int(state.index)]
			var selected = state.weapons[int(state.station)]
			var code_ok := (
				int(state.code[0]) == int(t.code[0])
				and int(state.code[1]) == int(t.code[1])
				and int(state.code[2]) == int(t.code[2])
			)
			if selected == t.weapon and state.fuze == t.fuze and code_ok:
				state.index = int(state.index) + 1
				if int(state.index) >= state.targets.size():
					return {"status": "ok", "view": view(state), "detail": "final target destroyed — safe the panel"}
				return {"status": "ok", "view": view(state), "detail": "target destroyed"}
			var expect := "%s/%s/%d%d%d" % [t.weapon, t.fuze, t.code[0], t.code[1], t.code[2]]
			var got := "%s/%s/%d%d%d" % [selected, state.fuze, state.code[0], state.code[1], state.code[2]]
			return {"status": "strike", "view": view(state), "detail": "bad release %s, expected %s" % [got, expect]}
		_:
			return {"status": "ok", "view": view(state)}


static func fixed_manual() -> Dictionary:
	var data := ModuleData.load_json("ordnance")
	return {
		"intro": data.intro,
		"weapons": data.weapons,
		"rules": data.rules,
		"fuzeRules": data.fuzeRules,
		"codeRules": data.codeRules,
		"checklist": data.checklist
	}


static func _laser_set(data: Dictionary) -> Dictionary:
	var out := {}
	for w in data.weapons:
		if str(w.guidance) == "LASER":
			out[w.id] = true
	return out


static func _weapon_for(attrs: Dictionary) -> String:
	if attrs.moving:
		return "AGM-65"
	if attrs.urban:
		return "GBU-38"
	if attrs.hardened:
		return "GBU-31"
	if attrs.wx == "CLEAR":
		return "GBU-12"
	return "GBU-31"


static func _make_target(rng: Rng, serial: String, data: Dictionary) -> Dictionary:
	var intended: String = rng.pick(["GBU-12", "GBU-31", "GBU-38", "AGM-65", "GBU-31"])
	var attrs := {"moving": false, "urban": false, "hardened": false, "wx": rng.pick(["CLEAR", "IMC"])}
	match intended:
		"AGM-65":
			attrs.moving = true
			attrs.urban = rng.float_value() < 0.35
			attrs.hardened = rng.float_value() < 0.3
		"GBU-38":
			attrs.urban = true
			attrs.hardened = rng.float_value() < 0.4
		"GBU-12":
			attrs.wx = "CLEAR"
		_:
			if rng.float_value() < 0.5:
				attrs.hardened = true
			else:
				attrs.wx = "IMC"
	var weapon := _weapon_for(attrs)
	var fuze := "TAIL" if attrs.hardened else "NOSE"
	var laser := _laser_set(data)
	var code: Array
	if laser.has(weapon):
		code = [1, int(serial[2]), int(serial[3])]
	else:
		code = [0, 0, 0]
	var name: String = rng.pick(data.movingTargets if attrs.moving else data.staticTargets)
	return {"name": name, "attrs": attrs, "weapon": weapon, "fuze": fuze, "code": code}


static func _describe(t: Dictionary) -> String:
	var a: Dictionary = t.attrs
	return "%s · %s · %s · %s · WX %s" % [
		t.name,
		"MOVING" if a.moving else "STATIC",
		"URBAN" if a.urban else "OPEN TERRAIN",
		"HARDENED" if a.hardened else "SOFT",
		a.wx
	]
