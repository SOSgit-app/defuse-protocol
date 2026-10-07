class_name Rng
extends RefCounted
## Deterministic mulberry32 RNG — must match server/rng.js for seed parity.

var seed: String = ""
var _state: int = 0


func _init(p_seed: Variant = "") -> void:
	seed = str(p_seed)
	_state = hash_seed(seed)


static func hash_seed(s: String) -> int:
	var h: int = _to_i32(1779033703 ^ s.length())
	for i in s.length():
		h = _imul(h ^ s.unicode_at(i), 3432918353)
		h = _to_i32((h << 13) | _usr(h, 19))
	return _to_u32(h)


static func random_seed() -> String:
	var adj := ["CRIMSON", "SILENT", "RAPID", "HOLLOW", "AMBER", "FROZEN", "NEON", "RUSTY", "PRIME", "VIVID"]
	var noun := ["FOX", "RELAY", "CIRCUIT", "ANVIL", "COMET", "SPARK", "VAULT", "PYLON", "ROTOR", "SIGNAL"]
	return "%s-%s-%d" % [
		adj[randi() % adj.size()],
		noun[randi() % noun.size()],
		10 + randi() % 90
	]


func float_value() -> float:
	_state = _to_i32(_state + 0x6d2b79f5)
	var t: int = _imul(_state ^ _usr(_state, 15), 1 | _state)
	t = _to_i32((t + _imul(t ^ _usr(t, 7), 61 | t)) ^ t)
	return float(_to_u32(t ^ _usr(t, 14))) / 4294967296.0


func int_range(min_v: int, max_v: int) -> int:
	return min_v + int(floor(float_value() * float(max_v - min_v + 1)))


func pick(arr: Array) -> Variant:
	return arr[int_range(0, arr.size() - 1)]


func shuffle(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


func sample(arr: Array, n: int) -> Array:
	return shuffle(arr).slice(0, n)


func chance(p: float) -> bool:
	return float_value() < p


func child(label: String) -> Rng:
	return Rng.new(seed + "::" + label)


static func _imul(a: int, b: int) -> int:
	return _to_i32(a * b)


static func _usr(n: int, bits: int) -> int:
	return (_to_u32(n) >> bits) & 0xFFFFFFFF


static func _to_u32(n: int) -> int:
	return n & 0xFFFFFFFF


static func _to_i32(n: int) -> int:
	var u := n & 0xFFFFFFFF
	if u >= 0x80000000:
		return u - 0x100000000
	return u
