class_name ObservationBuilder
extends RefCounted
static func build(clock: WorldClock, needs: ResidentNeeds, room: RoomState, position: Vector2, action: String, memories: Array, goals: Array, preferences: Dictionary, candidates: Array) -> Dictionary:
	return {"time":clock.snapshot(),"self":{"needs":needs.values,"current_action":action,"location":"room","position_label":"inside"},"room":{"cleanliness":room.cleanliness,"trash_level":room.resources.trash,"light_on":room.light_on},"visible_objects":room.visible_objects(),"resources":room.resources,"active_goals":goals,"relevant_memories":memories,"learned_preferences":preferences,"available_actions":candidates}
