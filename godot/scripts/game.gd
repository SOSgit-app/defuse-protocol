class_name DefuseGame
extends RefCounted
## Authoritative round — port of server/game.js

signal tick(remaining_ms: int, time_scale: float)
signal strike(strikes: int, max_strikes: int, module_id: String)
signal module_updated(module_id: String, view: Dictionary)
signal module_solved(module_id: String, solved_count: int)
signal game_over(summary: Dictionary)

const DIFFICULTY := {
	"easy": {"module_count": 3, "time_ms": 8 * 60 * 1000, "max_strikes": 3, "strike_accel": 0.15},
	"normal": {"module_count": 4, "time_ms": 10 * 60 * 1000, "max_strikes": 3, "strike_accel": 0.25},
	"hard": {"module_count": 5, "time_ms": 12 * 60 * 1000, "max_strikes": 2, "strike_accel": 0.4}
}

const CLASSIC_MODULES := ["wires", "symbols", "memory", "morse", "logicgrid"]
const HARD_MODULES := ["ordnance", "comms", "threatplot", "brevity"]

var difficulty: String = "normal"
var config: Dictionary = {}
var seed: String = ""
var serial: String = ""
var strikes: int = 0
var remaining_ms: float = 0.0
var status: String = "idle"
var modules: Array = []
var fly_landed: bool = false

var _paused: bool = false
var _started_at_ms: int = 0
var _last_tick_ms: int = 0


func start(opts: Dictionary = {}) -> void:
	var diff := str(opts.get("difficulty", "normal"))
	if not DIFFICULTY.has(diff):
		diff = "normal"
	difficulty = diff
	config = DIFFICULTY[diff].duplicate()

	var custom_time := float(opts.get("time_ms", 0))
	if custom_time >= 15000.0 and custom_time <= 30.0 * 60.0 * 1000.0:
		config.time_ms = int(round(custom_time))
	var custom_strikes := int(opts.get("max_strikes", 0))
	if custom_strikes >= 1 and custom_strikes <= 9:
		config.max_strikes = custom_strikes

	var raw_seed := str(opts.get("seed", "")).strip_edges()
	seed = raw_seed.to_upper() if raw_seed != "" else Rng.random_seed()

	var rng := Rng.new(seed)
	serial = _make_serial(rng)
	strikes = 0
	remaining_ms = float(config.time_ms)
	status = "running"
	_paused = false
	fly_landed = false
	_started_at_ms = Time.get_ticks_msec()
	_last_tick_ms = _started_at_ms

	var types: Array
	if opts.has("force_types"):
		types = opts.force_types
	else:
		types = _pick_types(rng, difficulty)
		# Until more modules are ported, keep only registered types and pad with wires.
		types = _filter_ported(types)

	modules.clear()
	for i in types.size():
		var type: String = types[i]
		var mod := ModuleRegistry.get_module(type)
		assert(not mod.is_empty(), "Module not ported: %s" % type)
		var ctx := {
			"rng": rng.child("%s#%d" % [type, i]),
			"difficulty": difficulty,
			"serial": serial
		}
		var generated: Dictionary = mod.generate.call(ctx)
		modules.append({
			"id": "m%d" % (i + 1),
			"type": type,
			"name": mod.name,
			"state": generated.state,
			"manual": generated.manual,
			"view": generated.view,
			"solved": false
		})

	print("game:start seed=%s serial=%s modules=%s" % [seed, serial, types])


func process_tick() -> void:
	if status != "running":
		return
	var now := Time.get_ticks_msec()
	if _paused:
		_last_tick_ms = now
		return
	var dt_ms := float(now - _last_tick_ms)
	_last_tick_ms = now
	remaining_ms -= dt_ms * time_scale()
	if remaining_ms <= 0.0:
		remaining_ms = 0.0
		_end("lost", "timer")
		return
	tick.emit(int(round(remaining_ms)), time_scale())


func time_scale() -> float:
	var scale := 1.0 + float(strikes) * float(config.strike_accel)
	if fly_landed:
		scale += 0.5
	return scale


func pause() -> void:
	if status != "running" or _paused:
		return
	_paused = true
	_last_tick_ms = Time.get_ticks_msec()


func resume() -> void:
	if not _paused:
		return
	_paused = false
	_last_tick_ms = Time.get_ticks_msec()


func is_paused() -> bool:
	return _paused


func handle_action(module_id: String, action: Dictionary) -> void:
	if status != "running" or _paused:
		return
	var inst = _find_module(module_id)
	if inst == null or inst.solved:
		return
	var mod := ModuleRegistry.get_module(inst.type)
	var result: Dictionary = mod.action.call(inst.state, action, {"serial": serial})
	inst.view = result.view
	module_updated.emit(module_id, result.view)

	var st := str(result.get("status", "ok"))
	if st == "strike":
		strikes += 1
		strike.emit(strikes, int(config.max_strikes), module_id)
		if strikes >= int(config.max_strikes):
			_end("lost", "strikes")
	elif st == "solved":
		inst.solved = true
		module_solved.emit(module_id, solved_count())
		if solved_count() == modules.size():
			_end("won", "all modules defused")


func solved_count() -> int:
	var n := 0
	for m in modules:
		if m.solved:
			n += 1
	return n


func defuser_payload() -> Dictionary:
	var mods: Array = []
	for m in modules:
		mods.append({
			"id": m.id,
			"type": m.type,
			"name": m.name,
			"view": m.view,
			"solved": m.solved
		})
	return {
		"role": "defuser",
		"seed": seed,
		"difficulty": difficulty,
		"serial": serial,
		"time_ms": int(round(remaining_ms)),
		"max_strikes": int(config.max_strikes),
		"strikes": strikes,
		"modules": mods
	}


func destroy() -> void:
	status = "idle"


func _find_module(module_id: String):
	for m in modules:
		if m.id == module_id:
			return m
	return null


func _end(result: String, reason: String) -> void:
	if status != "running":
		return
	status = result
	var summary := {
		"result": result,
		"reason": reason,
		"seed": seed,
		"difficulty": difficulty,
		"strikes": strikes,
		"modules_solved": solved_count(),
		"modules_total": modules.size(),
		"time_remaining_ms": maxi(0, int(round(remaining_ms))),
		"duration_ms": Time.get_ticks_msec() - _started_at_ms
	}
	print("game:over %s" % summary)
	game_over.emit(summary)


static func _make_serial(rng: Rng) -> String:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	var digits := "0123456789"
	return (
		letters[rng.int_range(0, letters.length() - 1)] +
		letters[rng.int_range(0, letters.length() - 1)] +
		digits[rng.int_range(0, digits.length() - 1)] +
		digits[rng.int_range(0, digits.length() - 1)] +
		letters[rng.int_range(0, letters.length() - 1)] +
		digits[rng.int_range(0, digits.length() - 1)]
	)


static func _pick_types(rng: Rng, diff: String) -> Array:
	var classic: Array = rng.shuffle(CLASSIC_MODULES.duplicate())
	var hard_pool: Array = rng.shuffle(
		HARD_MODULES.filter(func(t): return t != "ordnance")
	)
	if diff == "easy":
		return rng.shuffle(classic.slice(0, 3))
	if diff == "hard":
		return rng.shuffle([classic[0], classic[1], classic[2], "ordnance", hard_pool[0]])
	var hard: Array = rng.shuffle(HARD_MODULES.duplicate())
	return rng.shuffle([classic[0], classic[1], classic[2], hard[0]])


static func _filter_ported(types: Array) -> Array:
	var out: Array = []
	for t in types:
		if ModuleRegistry.is_ported(t):
			out.append(t)
	if out.is_empty():
		out.append("wires")
	return out
