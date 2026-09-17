class_name PrimitiveToolCatalog
extends RefCounted

const TOOLS := {
	"move_to":{"target":"cell","args_schema":{"x":"integer","y":"integer"}},"move_near":{"target":"object","args_schema":{"target":"object_id"}},
	"inspect":{"target":"object","args_schema":{"target":"object_id"}},"pick_up":{"target":"item","args_schema":{"target":"item_id"}},"put_down":{"target":"item","args_schema":{"target":"item_id"}},
	"open":{"target":"object","args_schema":{"target":"object_id"}},"close":{"target":"object","args_schema":{"target":"object_id"}},
	"sit":{"target":"object","args_schema":{"target":"object_id"}},"stand":{"target":"none","args_schema":{}},"lie_down":{"target":"object","args_schema":{"target":"object_id"}},
	"turn_on":{"target":"object","args_schema":{"target":"object_id"}},"turn_off":{"target":"object","args_schema":{"target":"object_id"}},
	"eat":{"target":"item","args_schema":{"target":"item_id"}},"drink":{"target":"object","args_schema":{"target":"object_id"}},"read":{"target":"item","args_schema":{"target":"item_id"}},"wait":{"target":"none","args_schema":{}}
}

static func available(room: RoomState, resident: Dictionary) -> Array:
	var result: Array = []
	for id in TOOLS:
		if id == "pick_up" and resident.get("held_item_id","") != "": continue
		if id == "put_down" and resident.get("held_item_id","") == "": continue
		if id in ["eat","read"] and resident.get("held_item_id","") == "": continue
		result.append({"tool":id,"target_type":TOOLS[id].target,"args_schema":TOOLS[id].args_schema})
	return result
