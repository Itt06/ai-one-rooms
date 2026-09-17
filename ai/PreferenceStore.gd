class_name PreferenceStore
extends RefCounted
var values := {}
var counts := {}
func record(action: String, improvement: float) -> void:
	counts[action] = int(counts.get(action, 0)) + 1; values[action] = clamp(float(values.get(action, 0.0)) + improvement, -1.0, 1.0)
func summary() -> Dictionary: return values
