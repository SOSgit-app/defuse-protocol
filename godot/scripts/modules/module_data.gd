class_name ModuleData
extends RefCounted
## Loads JSON from res://data/modules/

static var _cache: Dictionary = {}


static func load_json(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := "res://data/modules/%s.json" % name
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "Missing %s" % path)
	var parsed = JSON.parse_string(f.get_as_text())
	assert(typeof(parsed) == TYPE_DICTIONARY, "%s must be an object" % path)
	_cache[name] = parsed
	return parsed
