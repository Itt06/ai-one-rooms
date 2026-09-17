class_name ActionCatalog
extends RefCounted

const DEFINITIONS := {
	"wait":{"display_name":"Wait","target_type":"none","duration_minutes":10.0,"effects":{}},
	"eat_food":{"display_name":"Eat food","target_type":"object","duration_minutes":15.0,"effects":{"hunger":-45.0,"resource.simple_food":-1}},
	"drink_water":{"display_name":"Drink water","target_type":"object","duration_minutes":10.0,"effects":{"thirst":-50.0,"resource.water":-1}},
	"sleep":{"display_name":"Sleep","target_type":"object","duration_minutes":120.0,"effects":{"sleepiness":-65.0,"stress":-5.0}},
	"use_toilet":{"display_name":"Use toilet","target_type":"object","duration_minutes":10.0,"effects":{"toilet_need":-80.0,"discomfort":-16.0}},
	"take_shower":{"display_name":"Take shower","target_type":"object","duration_minutes":30.0,"effects":{"hygiene_need":-55.0,"discomfort":-15.0}},
	"sit":{"display_name":"Sit","target_type":"object","duration_minutes":10.0,"effects":{"discomfort":-2.0}},
	"read_book":{"display_name":"Read a book","target_type":"object","duration_minutes":30.0,"effects":{"boredom":-35.0,"stress":-5.0}},
	"use_pc":{"display_name":"Use PC","target_type":"object","duration_minutes":60.0,"effects":{"boredom":-25.0,"stress":3.0}},
	"call_friend":{"display_name":"Call a friend","target_type":"object","duration_minutes":20.0,"effects":{"loneliness":-50.0,"stress":-5.0,"boredom":-8.0}},
	"order_groceries":{"display_name":"Order groceries","target_type":"object","duration_minutes":10.0,"effects":{"resource.simple_food":6}},
	"watch_tv":{"display_name":"Watch TV","target_type":"object","duration_minutes":45.0,"effects":{"boredom":-30.0}},
	"look_out_window":{"display_name":"Look out window","target_type":"object","duration_minutes":15.0,"effects":{"boredom":-8.0,"stress":-2.0}},
	"clean_room":{"display_name":"Clean room","target_type":"object","duration_minutes":30.0,"effects":{"discomfort":-20.0}},
	"take_out_trash":{"display_name":"Take out trash","target_type":"object","duration_minutes":15.0,"effects":{"discomfort":-10.0}},
	"write_diary":{"display_name":"Write diary","target_type":"object","duration_minutes":20.0,"effects":{"stress":-4.0}},
	"inspect_object":{"display_name":"Inspect object","target_type":"object","duration_minutes":10.0,"effects":{"boredom":-4.0}}
}

static func candidates(room: RoomState) -> Array:
	var result: Array = []
	for id in DEFINITIONS:
		if not _requirements_met(id, room):
			continue
		var definition: Dictionary = DEFINITIONS[id]
		if str(definition.get("target_type", "none")) == "none":
			result.append(_candidate(id, definition, "", ""))
			continue
		for object_id in room.objects:
			var object: Dictionary = room.objects[object_id]
			if id not in object.get("supported_actions", []):
				continue
			if id == "drink_water" and object_id == "fridge" and int(room.resources.get("water",0)) <= 0:
				continue
			result.append(_candidate(id, definition, str(object_id), str(object.get("display_name", object_id))))
	return result

static func _candidate(id: String, definition: Dictionary, target_id: String, target_name: String) -> Dictionary:
	return {
		"id": id,
		"display_name": str(definition.get("display_name", id)),
		"target_id": target_id,
		"target_name": target_name,
		"duration_minutes": float(definition.get("duration_minutes", 10.0))
	}

static func _requirements_met(id: String, room: RoomState) -> bool:
	if id == "eat_food" and int(room.resources.get("simple_food", 0)) <= 0:
		return false
	if id == "read_book" and int(room.resources.get("book", 0)) <= 0:
		return false
	if id == "take_out_trash" and int(room.resources.get("trash", 0)) <= 0:
		return false
	if id == "clean_room" and float(room.cleanliness) >= 97.0:
		return false
	if id == "order_groceries" and int(room.resources.get("simple_food",0)) > 2:
		return false
	return true
