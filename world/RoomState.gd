class_name RoomState
extends RefCounted

var cleanliness := 82.0
var light_on := true
var grid := RoomGrid.new()
var items := {
	"book_01":{"id":"book_01","type":"book","display_name":"Book","location":"bookshelf","held_by":"","container":"bookshelf","portable":true,"properties":{"readable":true}},
	"food_01":{"id":"food_01","type":"simple_food","display_name":"Simple food","location":"fridge","held_by":"","container":"fridge","portable":true,"properties":{"edible":true}}
}
var resources := {"water":6,"simple_food":5,"book":1,"trash":0}
var objects := {
	"bed":{"id":"bed","type":"bed","display_name":"Bed","origin_cell":Vector2i(1,5),"occupied_cells":[Vector2i(1,5),Vector2i(2,5),Vector2i(1,6),Vector2i(2,6)],"interaction_cells":[Vector2i(1,7),Vector2i(2,7)],"rotation":0,"movable":false,"blocks_movement":true,"position":Vector2(170,440),"interaction_point":Vector2(280,440),"supported_actions":["sleep","sit","inspect_object"]},
	"desk":{"id":"desk","display_name":"Desk","position":Vector2(420,440),"interaction_point":Vector2(390,480),"supported_actions":["sit","write_diary","inspect_object"]},
	"chair":{"id":"chair","display_name":"Chair","position":Vector2(450,480),"interaction_point":Vector2(450,500),"supported_actions":["sit","read_book","inspect_object"]},
	"fridge":{"id":"fridge","display_name":"Fridge","position":Vector2(740,230),"interaction_point":Vector2(680,330),"supported_actions":["eat_food","drink_water","inspect_object"]},
	"sink":{"id":"sink","display_name":"Sink","position":Vector2(650,400),"interaction_point":Vector2(620,430),"supported_actions":["drink_water","clean_room","inspect_object"]},
	"shower":{"id":"shower","display_name":"Shower","position":Vector2(610,145),"interaction_point":Vector2(560,210),"supported_actions":["take_shower","inspect_object"]},
	"toilet":{"id":"toilet","display_name":"Toilet","position":Vector2(740,400),"interaction_point":Vector2(700,430),"supported_actions":["use_toilet","inspect_object"]},
	"bookshelf":{"id":"bookshelf","display_name":"Bookshelf","position":Vector2(160,170),"interaction_point":Vector2(270,230),"supported_actions":["read_book","inspect_object"]},
	"pc":{"id":"pc","display_name":"PC","position":Vector2(460,410),"interaction_point":Vector2(460,455),"supported_actions":["use_pc","order_groceries","inspect_object"]},
	"phone":{"id":"phone","display_name":"Phone","position":Vector2(520,455),"interaction_point":Vector2(500,485),"supported_actions":["call_friend","order_groceries","inspect_object"]},
	"tv":{"id":"tv","display_name":"TV","position":Vector2(435,170),"interaction_point":Vector2(435,260),"supported_actions":["watch_tv","inspect_object"]},
	"window":{"id":"window","display_name":"Window","position":Vector2(410,80),"interaction_point":Vector2(410,120),"supported_actions":["look_out_window","inspect_object"]},
	"trash_bin":{"id":"trash_bin","display_name":"Trash bin","position":Vector2(600,520),"interaction_point":Vector2(570,520),"supported_actions":["take_out_trash","inspect_object"]}
}

func _init() -> void:
	var placements := {"desk":Vector2i(5,5),"chair":Vector2i(6,6),"fridge":Vector2i(10,2),"sink":Vector2i(9,5),"shower":Vector2i(8,1),"toilet":Vector2i(10,5),"bookshelf":Vector2i(2,2),"pc":Vector2i(6,5),"phone":Vector2i(7,6),"tv":Vector2i(6,2),"window":Vector2i(5,0),"trash_bin":Vector2i(8,7)}
	for id in placements:
		objects[id]["origin_cell"] = placements[id]; objects[id]["occupied_cells"] = [placements[id]]; objects[id]["interaction_cells"] = [placements[id]+Vector2i(0,1)]; objects[id]["rotation"] = 0; objects[id]["movable"] = false; objects[id]["blocks_movement"] = false
		objects[id]["interaction_point"] = Vector2(70,70) + Vector2(placements[id]) * 60.0

func advance(minutes: float) -> void:
	cleanliness = clamp(cleanliness - minutes * 0.006, 0.0, 100.0)
	var trash := float(resources.get("trash",0))
	if trash > 0.0:
		cleanliness = clamp(cleanliness - minutes * 0.002 * min(trash,10.0),0.0,100.0)

func visible_objects() -> Array:
	var result: Array = []
	for id in objects:
		var object:Dictionary=objects[id]; result.append({"id":id,"type":object.get("type",id),"name":object.display_name,"cells":_cells_for(object),"interaction_cells":object.get("interaction_cells",[])})
	return result

func blocked_cells() -> Array:
	var result:Array=[]
	for id in objects:
		if bool(objects[id].get("blocks_movement",false)):
			for cell in objects[id].get("occupied_cells",[]): result.append(cell)
	return result

func _cells_for(object:Dictionary)->Array:
	var out:Array=[]
	for cell in object.get("occupied_cells",[]): out.append([cell.x,cell.y])
	return out
