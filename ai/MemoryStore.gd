class_name MemoryStore
extends RefCounted

const MAX_ENTRIES := 120

var entries: Array = []
var _next_id := 1

func add(time: String, action: String, summary: String, result: String, salience := 0.5, objects := [], context := {}) -> void:
	var text := summary.strip_edges()
	if text == "":
		return
	entries.push_front({
		"id": "mem_%04d" % _next_id,
		"simulation_time": time,
		"type": "episode",
		"summary": text,
		"salience": clamp(float(salience), 0.0, 1.0),
		"related_action": action,
		"related_objects": objects.duplicate(true) if objects is Array else [],
		"need_context": context.duplicate(true) if context is Dictionary else {},
		"result": result
	})
	_next_id += 1
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)

func retrieve(action_ids: Array, goals: Array, limit := 6, current_target := "", strong_needs := []) -> Array:
	var scored: Array = []
	for i in range(entries.size()):
		var memory: Dictionary = entries[i]
		var score := float(memory.get("salience", 0.5)) * 1.4
		score += max(0.0, 1.0 - float(i) / 24.0)
		if str(memory.get("related_action", "")) in action_ids:
			score += 0.25
		if current_target != "" and current_target in memory.get("related_objects", []):
			score += 0.35
		var lower_summary := str(memory.get("summary", "")).to_lower()
		for goal in goals:
			for token in _tokens(str(goal)):
				if token.length() >= 3 and token in lower_summary:
					score += 0.08
		for need_name in strong_needs:
			if str(need_name).to_lower() in lower_summary:
				score += 0.12
		scored.append({"score": score, "memory": memory})
	scored.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var result: Array = []
	for row in scored.slice(0, min(limit, scored.size())):
		result.append(row.memory.duplicate(true))
	return result

func serialize() -> Dictionary:
	return {"next_id": _next_id, "entries": entries.duplicate(true)}

func load_state(data) -> void:
	entries = []
	_next_id = 1
	if not (data is Dictionary):
		return
	var loaded = data.get("entries", [])
	if loaded is Array:
		for memory in loaded:
			if memory is Dictionary:
				entries.append(memory.duplicate(true))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	_next_id = max(1, int(data.get("next_id", entries.size() + 1)))

static func _tokens(text: String) -> PackedStringArray:
	var normalized := text.to_lower()
	for separator in [".", ",", "!", "?", ":", ";", "-", "_", "\n"]:
		normalized = normalized.replace(separator, " ")
	return normalized.split(" ", false)
