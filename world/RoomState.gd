class_name RoomState
extends RefCounted

var cleanliness := 82.0
var light_on := true
var resources := {"water":6,"simple_food":5,"book":1,"trash":0}
var objects := {
	"bed":{"id":"bed","display_name":"Bed","position":Vector2(170,440),"interaction_point":Vector2(280,440),"supported_actions":["sleep","sit","inspect_object"]},
	"desk":{"id":"desk","display_name":"Desk","position":Vector2(420,440),"interaction_point":Vector2(390,480),"supported_actions":["sit","write_diary","inspect_object"]},
	"chair":{"id":"chair","display_name":"Chair","position":Vector2(450,480),"interaction_point":Vector2(450,500),"supported_actions":["sit","read_book","inspect_object"]},
	"fridge":{"id":"fridge","display_name":"Fridge","position":Vector2(740,230),"interaction_point":Vector2(680,330),"supported_actions":["eat_food","drink_water","inspect_object"]},
	"sink":{"id":"sink","display_name":"Sink","position":Vector2(650,400),"interaction_point":Vector2(620,430),"supported_actions":["drink_water","clean_room","inspect_object"]},
	"shower":{"id":"shower","display_name":"Shower","position":Vector2(610,145),"interaction_point":Vector2(560,210),"supported_actions":["take_shower","inspect_object"]},
	"toilet":{"id":"toilet","display_name":"Toilet","position":Vector2(740,400),"interaction_point":Vector2(700,430),"supported_actions":["use_toilet","inspect_object"]},
	"bookshelf":{"id":"bookshelf","display_name":"Bookshelf","position":Vector2(160,170),"interaction_point":Vector2(270,230),"supported_actions":["read_book","inspect_object"]},
	"pc":{"id":"pc","display_name":"PC","position":Vector2(460,410),"interaction_point":Vector2(460,455),"supported_actions":["use_pc","inspect_object"]},
	"tv":{"id":"tv","display_name":"TV","position":Vector2(435,170),"interaction_point":Vector2(435,260),"supported_actions":["watch_tv","inspect_object"]},
	"window":{"id":"window","display_name":"Window","position":Vector2(410,80),"interaction_point":Vector2(410,120),"supported_actions":["look_out_window","inspect_object"]},
	"trash_bin":{"id":"trash_bin","display_name":"Trash bin","position":Vector2(600,520),"interaction_point":Vector2(570,520),"supported_actions":["take_out_trash","inspect_object"]}
}

func advance(minutes: float) -> void:
	cleanliness = clamp(cleanliness - minutes * 0.006, 0.0, 100.0)
	var trash := float(resources.get("trash",0))
	if trash > 0.0:
		cleanliness = clamp(cleanliness - minutes * 0.002 * min(trash,10.0),0.0,100.0)

func visible_objects() -> Array:
	var result: Array = []
	for id in objects:
		result.append({"id":id,"name":objects[id].display_name})
	return result
