class_name GoalStore
extends RefCounted

const MAX_ACTIVE := 5
const MAX_TEXT_LENGTH := 160

var goals: Array = []
var _next_id := 1

func active_texts() -> Array:
	var result: Array = []
	for goal in goals:
		if goal is Dictionary and str(goal.get("status", "")) == "active":
			result.append(str(goal.get("text", "")))
	return result

func active_records() -> Array:
	var result: Array = []
	for goal in goals:
		if goal is Dictionary and str(goal.get("status", "")) == "active":
			result.append(goal.duplicate(true))
	return result

func apply(updates) -> void:
	if not (updates is Dictionary):
		return
	for value in updates.get("add", []):
		var text := str(value).strip_edges()
		if text == "" or text.length() > MAX_TEXT_LENGTH or _has(text) or active_texts().size() >= MAX_ACTIVE:
			continue
		goals.append({"id": "goal_%04d" % _next_id, "text": text, "status": "active"})
		_next_id += 1
	for value in updates.get("complete", []):
		_set_status(str(value), "completed")
	for value in updates.get("abandon", []):
		_set_status(str(value), "abandoned")

func serialize() -> Dictionary:
	return {"next_id": _next_id, "goals": goals.duplicate(true)}

func load_state(data) -> void:
	goals = []
	_next_id = 1
	if not (data is Dictionary):
		return
	var loaded = data.get("goals", [])
	if loaded is Array:
		for goal in loaded:
			if goal is Dictionary:
				goals.append(goal.duplicate(true))
	_next_id = max(1, int(data.get("next_id", goals.size() + 1)))

func _has(text_or_id: String) -> bool:
	for goal in goals:
		if str(goal.get("text", "")) == text_or_id or str(goal.get("id", "")) == text_or_id:
			return true
	return false

func _set_status(text_or_id: String, new_status: String) -> void:
	for goal in goals:
		if str(goal.get("text", "")) == text_or_id or str(goal.get("id", "")) == text_or_id:
			goal["status"] = new_status
			return
