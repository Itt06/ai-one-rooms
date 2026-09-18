class_name ObservationBuilder
extends RefCounted

static func build(clock: WorldClock, needs: ResidentNeeds, room: RoomState, position: Vector2, action: String, memories: Array, goals: Array, preferences: Dictionary, candidates: Array, habits := {}, resident := {}, available_skills := [], recent_behavior := {}) -> Dictionary:
	var need_states:Dictionary={}
	for key in needs.values:
		var value:=float(needs.values[key]); need_states[key]="critical" if value>=90.0 else ("elevated" if value>=70.0 else "ordinary")
	return {
		"time": clock.snapshot(),
		"self": {
			"needs": needs.values.duplicate(true),
			"current_action": action,
			"location": "room",
			"position_label": _position_label(position, room),
			"cell": [int(resident.get("cell",Vector2i(5,6)).x),int(resident.get("cell",Vector2i(5,6)).y)],
			"posture": str(resident.get("posture","standing")),
			"held_item": resident.get("held_item_id",null)
		},
		"room": {
			"cleanliness": room.cleanliness,
			"trash_level": room.resources.get("trash", 0),
			"light_on": room.light_on
		},
		"visible_objects": room.visible_objects(),
		"resources": room.resources.duplicate(true),
		"need_states": need_states,
		"items": room.items.values().duplicate(true),
		"active_goals": goals.duplicate(true),
		"relevant_memories": memories.duplicate(true),
		"learned_preferences": preferences.duplicate(true),
		"habits": habits.duplicate(true) if habits is Dictionary else {},
		"available_actions": candidates.duplicate(true),
		"available_tools": PrimitiveToolCatalog.available(room,resident),
		"available_skills": available_skills,
		"recent_behavior": recent_behavior,
		"grid": {"size":[RoomGrid.WIDTH,RoomGrid.HEIGHT],"zones":{"center":"central open floor","bed_area":"resting area","desk_area":"work area","window_side":"window side","bathroom_area":"washroom","kitchen_area":"kitchen"}}
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
