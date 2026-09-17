class_name ActionCatalog
extends RefCounted

const DEFINITIONS := {
	"wait":{"display_name":"Wait","target_type":"none","duration_minutes":10.0,"effects":{}},
	"eat_food":{"display_name":"Eat food","target_type":"fridge","duration_minutes":15.0,"effects":{"hunger":-45.0,"resource.simple_food":-1}},
	"drink_water":{"display_name":"Drink water","target_type":"fridge","duration_minutes":10.0,"effects":{"thirst":-50.0,"resource.water":-1}},
	"sleep":{"display_name":"Sleep","target_type":"bed","duration_minutes":120.0,"effects":{"sleepiness":-65.0,"stress":-5.0}},
	"use_toilet":{"display_name":"Use toilet","target_type":"toilet","duration_minutes":10.0,"effects":{"discomfort":-12.0}},
	"take_shower":{"display_name":"Take shower","target_type":"shower","duration_minutes":30.0,"effects":{"hygiene_need":-55.0,"discomfort":-15.0}},
	"sit":{"display_name":"Sit","target_type":"chair","duration_minutes":10.0,"effects":{}},
	"read_book":{"display_name":"Read a book","target_type":"bookshelf","duration_minutes":30.0,"effects":{"boredom":-35.0,"stress":-5.0}},
	"use_pc":{"display_name":"Use PC","target_type":"pc","duration_minutes":60.0,"effects":{"boredom":-25.0,"stress":3.0}},
	"watch_tv":{"display_name":"Watch TV","target_type":"tv","duration_minutes":45.0,"effects":{"boredom":-30.0}},
	"look_out_window":{"display_name":"Look out window","target_type":"window","duration_minutes":15.0,"effects":{"boredom":-8.0}},
	"clean_room":{"display_name":"Clean room","target_type":"sink","duration_minutes":30.0,"effects":{"discomfort":-20.0}},
	"take_out_trash":{"display_name":"Take out trash","target_type":"trash_bin","duration_minutes":15.0,"effects":{"discomfort":-10.0}},
	"write_diary":{"display_name":"Write diary","target_type":"desk","duration_minutes":20.0,"effects":{"stress":-4.0}},
	"inspect_object":{"display_name":"Inspect object","target_type":"none","duration_minutes":10.0,"effects":{"boredom":-4.0}}
}

static func candidates(room: RoomState) -> Array:
	var result: Array = []
	for id in DEFINITIONS:
		if id == "eat_food" and room.resources.simple_food <= 0: continue
		if id == "drink_water" and room.resources.water <= 0: continue
		if id == "read_book" and room.resources.book <= 0: continue
		var d: Dictionary = DEFINITIONS[id]; var item := {"id":id,"display_name":d.display_name,"target_type":d.target_type,"duration_minutes":d.duration_minutes}
		if d.target_type == "none": item.target_id = ""
		else: item.target_id = d.target_type
		result.append(item)
	return result
