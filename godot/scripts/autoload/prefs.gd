extends Node
## Persistent prefs (difficulty, timers, strikes, fly).

const PATH := "user://defuse_prefs.cfg"
const TIME_OPTIONS := [
	60000, 90000, 120000, 150000, 180000, 240000, 300000, 360000, 420000,
	480000, 540000, 600000, 720000, 900000
]
const STRIKE_OPTIONS := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const DEFAULT_TIMES := {"easy": 480000, "normal": 600000, "hard": 720000}
const DEFAULT_STRIKES := {"easy": 3, "normal": 3, "hard": 2}

var difficulty: String = "normal"
var seed_text: String = ""
var times: Dictionary = DEFAULT_TIMES.duplicate()
var strikes: Dictionary = DEFAULT_STRIKES.duplicate()
var fly_enabled: bool = false
var last_seed: String = ""
var last_enter_vr: bool = false


func _ready() -> void:
	load_prefs()


func load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	difficulty = str(cfg.get_value("game", "difficulty", "normal"))
	seed_text = str(cfg.get_value("game", "seed", ""))
	fly_enabled = bool(cfg.get_value("game", "fly", false))
	for k in ["easy", "normal", "hard"]:
		times[k] = int(cfg.get_value("times", k, DEFAULT_TIMES[k]))
		strikes[k] = int(cfg.get_value("strikes", k, DEFAULT_STRIKES[k]))


func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "seed", seed_text)
	cfg.set_value("game", "fly", fly_enabled)
	for k in ["easy", "normal", "hard"]:
		cfg.set_value("times", k, int(times[k]))
		cfg.set_value("strikes", k, int(strikes[k]))
	cfg.save(PATH)


func fmt_time(ms: int) -> String:
	var total := maxi(0, int(ceil(float(ms) / 1000.0)))
	return "%d:%02d" % [total / 60, total % 60]


func nearest_time(ms: int) -> int:
	var best := TIME_OPTIONS[0]
	var best_d := absi(best - ms)
	for opt in TIME_OPTIONS:
		var d := absi(opt - ms)
		if d < best_d:
			best = opt
			best_d = d
	return best
