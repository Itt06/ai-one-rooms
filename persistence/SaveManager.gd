class_name SaveManager
extends RefCounted

const SAVE_VERSION := 4
const SAVE_PATH := "user://one_room_save.json"

static func save_state(state: Dictionary) -> bool:
	var payload := state.duplicate(true)
	payload["save_version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true

static func load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary):
		return {}
	var version := int(parsed.get("save_version", 0))
	if version <= 0:
		return _migrate_legacy(parsed)
	if version > SAVE_VERSION:
		return {}
	return parsed

static func _migrate_legacy(data: Dictionary) -> Dictionary:
	var migrated := {
		"save_version": SAVE_VERSION,
		"sim_minutes": float(data.get("sim_minutes", 480.0)),
		"needs": data.get("needs", {}),
		"room": {
			"resources": data.get("inventory", {}),
			"cleanliness": float(data.get("room_cleanliness", 82.0)),
			"light_on": true
		},
		"memory_store": {"next_id": 1, "entries": data.get("memories", [])},
		"goal_store": {"next_id": 1, "goals": []},
		"preferences": {},
		"diary": data.get("diary", []),
		"decision_history": [],
		"resident_position": [420.0, 390.0], "resident_state": {}, "skills": {"skills":[],"candidate_stats":{}}, "plan_history": []
	}
	for goal in data.get("goals", []):
		migrated.goal_store.goals.append({"id": "goal_%04d" % (migrated.goal_store.goals.size() + 1), "text": str(goal), "status": "active"})
	return migrated
