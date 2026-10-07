class_name ModuleRegistry
extends RefCounted
## Registry of ported modules.

static func get_module(type: String) -> Dictionary:
	match type:
		"wires":
			return _entry(WiresModule.TYPE, WiresModule.NAME, WiresModule.generate, WiresModule.action)
		"symbols":
			return _entry(SymbolsModule.TYPE, SymbolsModule.NAME, SymbolsModule.generate, SymbolsModule.action)
		"memory":
			return _entry(MemoryModule.TYPE, MemoryModule.NAME, MemoryModule.generate, MemoryModule.action)
		"morse":
			return _entry(MorseModule.TYPE, MorseModule.NAME, MorseModule.generate, MorseModule.action)
		"logicgrid":
			return _entry(LogicGridModule.TYPE, LogicGridModule.NAME, LogicGridModule.generate, LogicGridModule.action)
		"ordnance":
			return _entry(OrdnanceModule.TYPE, OrdnanceModule.NAME, OrdnanceModule.generate, OrdnanceModule.action)
		"comms":
			return _entry(CommsModule.TYPE, CommsModule.NAME, CommsModule.generate, CommsModule.action)
		"threatplot":
			return _entry(ThreatPlotModule.TYPE, ThreatPlotModule.NAME, ThreatPlotModule.generate, ThreatPlotModule.action)
		"brevity":
			return _entry(BrevityModule.TYPE, BrevityModule.NAME, BrevityModule.generate, BrevityModule.action)
		_:
			return {}


static func is_ported(type: String) -> bool:
	return not get_module(type).is_empty()


static func all_ported() -> Array:
	return [
		"wires", "symbols", "memory", "morse", "logicgrid",
		"ordnance", "comms", "threatplot", "brevity"
	]


static func _entry(type: String, name: String, generate: Callable, action: Callable) -> Dictionary:
	return {"type": type, "name": name, "generate": generate, "action": action}
