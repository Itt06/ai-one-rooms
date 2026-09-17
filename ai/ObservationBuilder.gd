class_name ObservationBuilder
extends RefCounted

static func build(clock: WorldClock, needs: ResidentNeeds, room: RoomState, position: Vector2, action: String, memories: Array, goals: Array, preferences: Dictionary, candidates: Array, habits := {}) -> Dictionary:
	return {
		"time": clock.snapshot(),
		"self": {
			"needs": needs.values.duplicate(true),
			"current_action": action,
			"location": "room",
			"position_label": _position_label(position, room)
		},
		"room": {
			"cleanliness": room.cleanliness,
			"trash_level": room.resources.get("trash", 0),
			"light_on": room.light_on
		},
		"visible_objects": room.visible_objects(),
		"resources": room.resources.duplicate(true),
		"active_goals": goals.duplicate(true),
		"relevant_memories": memories.duplicate(true),
		"learned_preferences": preferences.duplicate(true),
		"habits": habits.duplicate(true) if habits is Dictionary else {},
		"available_actions": candidates.duplicate(true)
	}

static func _position_label(position: Vector2, room: RoomState) -> String:
	var best_id := "room"
	var best_distance := INF
	for id in room.objects:
		var point: Vector2 = room.objects[id].interaction_point
		var distance := position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best_id = id
	return "near_%s" % best_id if best_distance < 90.0 else "room"
