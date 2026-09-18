class_name SaveManager
extends RefCounted

const SAVE_VERSION := 7
const SAVE_PATH := "user://one_room_save.json"

static func save_state(state: Dictionary, path: String = SAVE_PATH) -> bool:
	var payload := state.duplicate(true)
	payload["save_version"] = SAVE_VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true

static func load_state(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var version := int(parsed.get("save_version", 0))
	if version <= 0:
		return _migrate_legacy(parsed)
	if version < SAVE_VERSION:
		return _migrate_versioned(parsed,version)
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
		"resident_position": [420.0, 390.0], "resident_state": {}, "skills": {"skills":[],"candidate_stats":{}}, "plan_history": [], "finance":{}, "relationships":{}, "resident_mind":{}
	}
	for goal in data.get("goals", []):
		migrated.goal_store.goals.append({"id": "goal_%04d" % (migrated.goal_store.goals.size() + 1), "text": str(goal), "status": "active"})
	return migrated

static func _migrate_versioned(data:Dictionary, from_version:int)->Dictionary:
	var migrated:=data.duplicate(true)
	migrated["save_version"]=SAVE_VERSION
	if not migrated.has("room"):migrated["room"]={}
	if not migrated.has("resident_state"):migrated["resident_state"]={}
	if not migrated.has("plan_history"):migrated["plan_history"]=[]
	if not migrated.has("skills"):migrated["skills"]={"skills":[],"candidate_stats":{}}
	if not migrated.has("habits"):migrated["habits"]={"habits":[]}
	if not migrated.has("recent_activity_history"):migrated["recent_activity_history"]=[]
	if not migrated.has("memory_store"):migrated["memory_store"]={"next_id":1,"entries":[]}
	if not migrated.has("preferences"):migrated["preferences"]={}
	if not migrated.has("diary"):migrated["diary"]=[]
	if not migrated.has("diagnostics"):migrated["diagnostics"]={}
	if not migrated.has("sim_minutes"):migrated["sim_minutes"]=480.0
	if not migrated.has("finance"):migrated["finance"]={}
	if not migrated.has("relationships"):migrated["relationships"]={}
	if not migrated.has("resident_mind"):migrated["resident_mind"]={}
	return migrated
