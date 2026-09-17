class_name ActionExecutor
extends RefCounted

enum State { IDLE, MOVING_TO_TARGET, RUNNING, COMPLETED, FAILED, INTERRUPTED }

var state: State = State.IDLE
var action_id := ""
var target_id := ""
var reason := ""
var remaining_minutes := 0.0
var target_position := Vector2.ZERO
var before_needs: Dictionary = {}
var last_result: Dictionary = {}

func begin(id: String, target: String, why: String, room: RoomState, needs: ResidentNeeds, current_position: Vector2) -> Dictionary:
	reset()
	if not ActionCatalog.DEFINITIONS.has(id):
		state = State.FAILED
		last_result = {"event": "action_failed", "reason": "Unknown action"}
		return last_result
	var definition: Dictionary = ActionCatalog.DEFINITIONS[id]
	if target != "" and not room.objects.has(target):
		state = State.FAILED
		last_result = {"event": "action_failed", "reason": "Target does not exist"}
		return last_result
	action_id = id
	target_id = target
	reason = why
	remaining_minutes = float(definition.get("duration_minutes", 10.0))
	before_needs = needs.values.duplicate(true)
	if target_id != "":
		target_position = room.objects[target_id].interaction_point
		state = State.MOVING_TO_TARGET if current_position.distance_to(target_position) > 4.0 else State.RUNNING
	else:
		target_position = current_position
		state = State.RUNNING
	last_result = {"event": "action_queued", "action": action_id, "target": target_id}
	return last_result

func update(delta_seconds: float, elapsed_sim_minutes: float, current_position: Vector2, move_speed: float, needs: ResidentNeeds) -> Dictionary:
	var new_position := current_position
	var event := ""
	if state == State.MOVING_TO_TARGET:
		var speed_multiplier := 0.55 if float(needs.values.get("sleepiness", 0.0)) > 90.0 else 1.0
		new_position = current_position.move_toward(target_position, move_speed * speed_multiplier * delta_seconds)
		if new_position.distance_to(target_position) <= 2.0:
			new_position = target_position
			state = State.RUNNING
			event = "action_started"
	elif state == State.RUNNING:
		remaining_minutes = max(0.0, remaining_minutes - elapsed_sim_minutes)
		if remaining_minutes <= 0.0:
			state = State.COMPLETED
			event = "action_completed"
	return {"position": new_position, "event": event, "state": state_name()}

func apply_completion(room: RoomState, needs: ResidentNeeds) -> Dictionary:
	if state != State.COMPLETED or not ActionCatalog.DEFINITIONS.has(action_id):
		return {"ok": false, "reason": "Action is not completed"}
	var definition: Dictionary = ActionCatalog.DEFINITIONS[action_id]
	var need_effects := {}
	for key in definition.get("effects", {}):
		var value = definition.effects[key]
		if str(key).begins_with("resource."):
			var resource_name := str(key).trim_prefix("resource.")
			room.resources[resource_name] = max(0, int(room.resources.get(resource_name, 0)) + int(value))
		else:
			need_effects[key] = value
	needs.apply(need_effects)
	if action_id == "clean_room":
		room.cleanliness = min(100.0, room.cleanliness + 20.0)
	if action_id == "take_out_trash":
		room.resources.trash = 0
	if action_id == "eat_food":
		room.resources.trash = int(room.resources.get("trash", 0)) + 1
	var result := {
		"ok": true,
		"action": action_id,
		"target": target_id,
		"before_needs": before_needs,
		"after_needs": needs.values.duplicate(true),
		"result": "completed"
	}
	last_result = result
	return result

func interrupt(message: String) -> Dictionary:
	if state not in [State.MOVING_TO_TARGET, State.RUNNING]:
		return {"ok": false, "reason": "Nothing to interrupt"}
	state = State.INTERRUPTED
	last_result = {"ok": true, "event": "action_interrupted", "action": action_id, "target": target_id, "reason": message}
	return last_result

func reset() -> void:
	state = State.IDLE
	action_id = ""
	target_id = ""
	reason = ""
	remaining_minutes = 0.0
	target_position = Vector2.ZERO
	before_needs = {}

func is_idle() -> bool:
	return state == State.IDLE

func is_active() -> bool:
	return state in [State.MOVING_TO_TARGET, State.RUNNING]

func state_name() -> String:
	match state:
		State.IDLE: return "idle"
		State.MOVING_TO_TARGET: return "moving"
		State.RUNNING: return "acting"
		State.COMPLETED: return "completed"
		State.FAILED: return "failed"
		State.INTERRUPTED: return "interrupted"
	return "unknown"
