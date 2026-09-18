class_name ObservationBuilder
extends RefCounted

static func build(clock: WorldClock, needs: ResidentNeeds, room: RoomState, position: Vector2, action: String, memories: Array, goals: Array, preferences: Dictionary, candidates: Array, habits := {}, resident := {}, available_skills := [], recent_behavior := {}, life_context:Dictionary={}) -> Dictionary:
	var need_states:Dictionary={}
	for key in needs.values:
		var value:float=float(needs.values[key]); var threshold:float=ActivityExecutor.CRITICAL_SLEEPINESS if key=="sleepiness" else ActivityExecutor.CRITICAL_THIRST if key=="thirst" else ActivityExecutor.CRITICAL_TOILET if key=="toilet_need" else ActivityExecutor.CRITICAL_DISCOMFORT if key=="discomfort" else 100.1
		need_states[key]="critical" if value>=threshold else intensity_for(value)
	var observation:={
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
			"private_stains": room.private_stains,
			"light_on": room.light_on
		},
		"visible_objects": room.visible_objects(),
		"resources": room.resources.duplicate(true),
		"household_supplies": {"tissues": int(room.resources.get("tissues",0)), "stains": room.private_stains},
		"need_states": need_states,
		"felt_pressures": felt_pressures(needs),
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

static func intensity_for(value:float)->String:
	if value>=95.0:return "intense"
	if value>=85.0:return "strong"
	if value>=70.0:return "elevated"
	if value>=40.0:return "ordinary"
	return "low"

static func felt_pressures(needs:ResidentNeeds, limit:int=4)->Array:
	var pressures:Array=[]
	for key in needs.values:
		var value:float=float(needs.values[key])
		pressures.append({"need":str(key),"value":value,"intensity":intensity_for(value)})
	pressures.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a.get("value",0.0))>float(b.get("value",0.0)))
	return pressures.slice(0,min(limit,pressures.size()))

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
