class_name ObservationBuilder
extends RefCounted

static func build(clock: WorldClock, needs: ResidentNeeds, room: RoomState, position: Vector2, action: String, memories: Array, goals: Array, preferences: Dictionary, candidates: Array, habits := {}, resident := {}, available_skills := [], recent_behavior := {}, life_context:Dictionary={}) -> Dictionary:
	var observation:={
		"time": clock.snapshot(),
		"self": {
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
			"private_stains": room.private_stains,
			"light_on": room.light_on
		},
		"visible_objects": room.visible_objects(),
		"resources": room.resources.duplicate(true),
		"household_supplies": {"tissues": int(room.resources.get("tissues",0)), "stains": room.private_stains},
		"resident_mind": life_context.get("resident_mind",ResidentMindState.neutral()),
		"physical_constraints": BodyStateBuilder.physical_constraints(needs),
		"items": room.items.values().duplicate(true),
		"active_goals": goals.duplicate(true),
		"relevant_memories": memories.duplicate(true),
		"learned_preferences": preferences.duplicate(true),
		"habits": habits.duplicate(true) if habits is Dictionary else {},
		"available_tools": PrimitiveToolCatalog.available(room,resident,life_context),
		"available_skills": available_skills,
		"recent_behavior": recent_behavior,
		"grid": {"size":[RoomGrid.WIDTH,RoomGrid.HEIGHT],"zones":{"center":"central open floor","bed_area":"resting area","desk_area":"work area","window_side":"window side","bathroom_area":"washroom","kitchen_area":"kitchen"}}
	}
	if life_context.has("finances"):observation["finances"]=life_context.finances
	if life_context.has("relationships"):observation["relationships"]=life_context.relationships
	if life_context.has("sexual_partner_options"):observation["sexual_partner_options"]=life_context.sexual_partner_options
	return observation

static func build_appraisal_facts(clock:WorldClock,needs:ResidentNeeds,room:RoomState,memories:Array,goals:Array,preferences:Dictionary,habits:Dictionary,recent_behavior:Dictionary,life_context:Dictionary)->Dictionary:
	return {
		"body_state":BodyStateBuilder.descriptions(needs),
		"physical_constraints":BodyStateBuilder.physical_constraints(needs),
		"time":clock.snapshot(),
		"recent_events":recent_behavior,
		"room_state":{"cleanliness_description":"clean" if room.cleanliness>=70.0 else "somewhat messy" if room.cleanliness>=40.0 else "very messy","trash":"present" if int(room.resources.get("trash",0))>0 else "none","food_available":room.item_quantity("simple_food")>0},
		"finance":life_context.get("finances",{}),
		"relationships":life_context.get("relationships",{}),
		"relevant_memories":memories,
		"preferences":preferences,
		"habits":habits,
		"active_goals":goals
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
