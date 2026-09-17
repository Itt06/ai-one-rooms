class_name PrimitiveToolCatalog
extends RefCounted

const TOOLS := {
	"move_to":{"target":"cell","args":["x","y"]},"move_near":{"target":"object","args":["target"]},
	"inspect":{"target":"object","args":["target"]},"pick_up":{"target":"item","args":["target"]},"put_down":{"target":"item","args":["target"]},
	"open":{"target":"object","args":["target"]},"close":{"target":"object","args":["target"]},
	"sit":{"target":"object","args":["target"]},"stand":{"target":"none","args":[]},"lie_down":{"target":"object","args":["target"]},
	"turn_on":{"target":"object","args":["target"]},"turn_off":{"target":"object","args":["target"]},
	"eat":{"target":"item","args":["target"]},"drink":{"target":"object","args":["target"]},"read":{"target":"item","args":["target"]},"wait":{"target":"none","args":[]}
}

static func available(room: RoomState, resident: Dictionary) -> Array:
	var result: Array = []
	for id in TOOLS:
		if id == "pick_up" and resident.get("held_item_id","") != "": continue
		if id == "put_down" and resident.get("held_item_id","") == "": continue
		if id in ["eat","read"] and resident.get("held_item_id","") == "": continue
		result.append({"tool":id,"target_type":TOOLS[id].target,"args":TOOLS[id].args})
	return result
