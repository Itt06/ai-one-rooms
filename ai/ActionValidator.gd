class_name ActionValidator
extends RefCounted

const MAX_REASON_LENGTH := 200
const MAX_GOALS := 5
const MAX_GOAL_LENGTH := 160

static func validate(decision, candidates: Array, room: RoomState, existing_goals: Array) -> Dictionary:
	if not (decision is Dictionary):
		return _fail("Decision is not a JSON object")
	if not decision.has("action") or not (decision.action is Dictionary):
		return _fail("Missing action object")
	var action_id := str(decision.action.get("id", ""))
	var target_id := str(decision.action.get("target", ""))
	if action_id == "":
		return _fail("Missing action id")
	var candidate := _candidate_for(action_id, target_id, candidates)
	if candidate.is_empty():
		return _fail("Action/target pair is not currently available")
	if target_id != "" and not room.objects.has(target_id):
		return _fail("Target does not exist")
	if target_id != "":
		var supported: Array = room.objects[target_id].get("supported_actions", [])
		if action_id not in supported:
			return _fail("Target does not support this action")
	if action_id == "eat_food" and int(room.resources.get("simple_food", 0)) <= 0:
		return _fail("No food available")
	if action_id == "drink_water" and int(room.resources.get("water", 0)) <= 0:
		return _fail("No water available")
	if action_id == "read_book" and int(room.resources.get("book", 0)) <= 0:
		return _fail("No book available")
	var goal_result := validate_goal_updates(decision.get("goal_updates", {}), existing_goals)
	if not bool(goal_result.get("ok", false)):
		return goal_result
	var reason := str(decision.get("reason", "")).strip_edges()
	if reason.length() > MAX_REASON_LENGTH:
		reason = reason.left(MAX_REASON_LENGTH)
	return {
		"ok": true,
		"error": "",
		"decision": {
			"action": {"id": action_id, "target": target_id},
			"reason": reason,
			"goal_updates": goal_result.get("updates", {"add": [], "complete": [], "abandon": []}),
			"diary_text": decision.get("diary_text", null)
		}
	}

static func validate_goal_updates(raw_updates, existing_goals: Array) -> Dictionary:
	if not (raw_updates is Dictionary):
		return _fail("goal_updates must be an object")
	var normalized := {"add": [], "complete": [], "abandon": []}
	for key in normalized.keys():
		var values = raw_updates.get(key, [])
		if not (values is Array):
			return _fail("goal_updates.%s must be an array" % key)
		for value in values:
			var text := str(value).strip_edges()
			if text == "" or text.length() > MAX_GOAL_LENGTH:
				return _fail("Invalid goal text")
			if key == "add":
				if text in existing_goals or text in normalized["add"]:
					continue
				if existing_goals.size() + normalized["add"].size() >= MAX_GOALS:
					return _fail("Too many active goals")
				normalized["add"].append(text)
			else:
				if text not in existing_goals:
					return _fail("Cannot update an unknown goal")
				normalized[key].append(text)
	return {"ok": true, "error": "", "updates": normalized}

static func _candidate_for(action_id: String, target_id: String, candidates: Array) -> Dictionary:
	for candidate in candidates:
		if candidate is Dictionary and str(candidate.get("id", "")) == action_id and str(candidate.get("target_id", "")) == target_id:
			return candidate
	return {}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
