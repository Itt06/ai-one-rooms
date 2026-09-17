class_name RoomState
extends RefCounted

var cleanliness := 82.0
var light_on := true
var revision := 0
var grid := RoomGrid.new()
var items := {
	"book_01":{"id":"book_01","type":"book","display_name":"Book","location":"bookshelf","held_by":"","container":"bookshelf","grid_cell":Vector2i(2,2),"rotation":0,"size":Vector2i(1,1),"blocks_movement":false,"portable":true,"properties":{"readable":true}},
	"food_stack":{"id":"food_stack","type":"simple_food","display_name":"Simple food","quantity":5,"location":"fridge","held_by":"","container":"fridge","grid_cell":null,"rotation":0,"size":Vector2i(1,1),"blocks_movement":false,"portable":true,"properties":{"edible":true}}
}
var resources := {"water":6,"trash":0}
var objects := {
	"bed":{"id":"bed","type":"bed","display_name":"Bed","origin_cell":Vector2i(1,5),"occupied_cells":[Vector2i(1,5),Vector2i(2,5),Vector2i(1,6),Vector2i(2,6)],"interaction_cells":[Vector2i(1,7),Vector2i(2,7)],"rotation":0,"movable":false,"blocks_movement":true,"position":Vector2(170,440),"interaction_point":Vector2(280,440),"supported_actions":["sleep","sit","inspect_object"]},
	"desk":{"id":"desk","display_name":"Desk","position":Vector2(420,440),"interaction_point":Vector2(390,480),"supported_actions":["sit","write_diary","inspect_object"]},
	"chair":{"id":"chair","display_name":"Chair","position":Vector2(450,480),"interaction_point":Vector2(450,500),"supported_actions":["sit","read_book","inspect_object"]},
	"fridge":{"id":"fridge","display_name":"Fridge","position":Vector2(740,230),"interaction_point":Vector2(680,330),"state":false,"supported_actions":["eat_food","drink_water","inspect_object"]},
	"sink":{"id":"sink","display_name":"Sink","position":Vector2(650,400),"interaction_point":Vector2(620,430),"supported_actions":["drink_water","clean_room","inspect_object"]},
	"shower":{"id":"shower","display_name":"Shower","position":Vector2(610,145),"interaction_point":Vector2(560,210),"supported_actions":["take_shower","inspect_object"]},
	"toilet":{"id":"toilet","display_name":"Toilet","position":Vector2(740,400),"interaction_point":Vector2(700,430),"supported_actions":["use_toilet","inspect_object"]},
	"bookshelf":{"id":"bookshelf","display_name":"Bookshelf","position":Vector2(160,170),"interaction_point":Vector2(270,230),"supported_actions":["read_book","inspect_object"]},
	"pc":{"id":"pc","type":"pc","display_name":"PC","position":Vector2(460,410),"interaction_point":Vector2(460,455),"state":false,"supported_actions":["use_pc","order_groceries","inspect_object"]},
	"phone":{"id":"phone","display_name":"Phone","position":Vector2(520,455),"interaction_point":Vector2(500,485),"supported_actions":["call_friend","order_groceries","inspect_object"]},
	"tv":{"id":"tv","display_name":"TV","position":Vector2(435,170),"interaction_point":Vector2(435,260),"state":false,"supported_actions":["watch_tv","inspect_object"]},
	"window":{"id":"window","display_name":"Window","position":Vector2(410,80),"interaction_point":Vector2(410,120),"supported_actions":["look_out_window","inspect_object"]},
	"trash_bin":{"id":"trash_bin","display_name":"Trash bin","position":Vector2(600,520),"interaction_point":Vector2(570,520),"supported_actions":["take_out_trash","inspect_object"]}
}

func _init() -> void:
	var placements := {"desk":Vector2i(5,5),"chair":Vector2i(6,6),"fridge":Vector2i(10,2),"sink":Vector2i(9,5),"shower":Vector2i(8,1),"toilet":Vector2i(10,5),"bookshelf":Vector2i(2,2),"pc":Vector2i(6,5),"phone":Vector2i(7,6),"tv":Vector2i(6,2),"window":Vector2i(5,0),"trash_bin":Vector2i(8,7)}
	for id in placements:
		objects[id]["origin_cell"] = placements[id]; objects[id]["occupied_cells"] = [placements[id]]; objects[id]["interaction_cells"] = [placements[id]+Vector2i(0,1)]; objects[id]["rotation"] = 0; objects[id]["movable"] = false; objects[id]["blocks_movement"] = false
		objects[id]["interaction_point"] = Vector2(70,70) + Vector2(placements[id]) * 60.0
	objects["chair"]["movable"] = true; objects["trash_bin"]["movable"] = true
	objects["chair"]["blocks_movement"] = true; objects["trash_bin"]["blocks_movement"] = true
	for id in placements:
		_recalculate_placement(objects[id])
	_setup_affordances()

func _setup_affordances() -> void:
	var affordances := {"bed":["move_near","inspect","sit","lie_down","sleep"],"desk":["move_near","inspect","sit","write_diary"],"chair":["move_near","inspect","sit"],"fridge":["move_near","inspect","open","close","drink","order_groceries"],"sink":["move_near","inspect","drink","clean"],"shower":["move_near","inspect","take_shower"],"toilet":["move_near","inspect","use_toilet"],"bookshelf":["move_near","inspect"],"pc":["move_near","inspect","turn_on","turn_off","use_pc","order_groceries"],"phone":["move_near","inspect","call_friend"],"tv":["move_near","inspect","turn_on","turn_off","watch_tv"],"window":["move_near","inspect","look_out_window"],"trash_bin":["move_near","inspect","take_out_trash"]}
	for id in affordances: objects[id]["supported_tools"] = affordances[id]

func advance(minutes: float) -> void:
	# A lived-in room degrades over days, not in a single afternoon.
	cleanliness = clamp(cleanliness - minutes * 0.001, 0.0, 100.0)
	var trash := float(resources.get("trash",0))
	if trash > 0.0:
		cleanliness = clamp(cleanliness - minutes * 0.0003 * min(trash,10.0),0.0,100.0)

func item_quantity(item_type:String)->int:
	var total:=0
	for id in items:
		if str(items[id].get("type",""))==item_type and str(items[id].get("location",""))!="consumed": total += int(items[id].get("quantity",1))
	return total

func add_item_quantity(item_type:String, amount:int, location:String)->void:
	if amount<=0:return
	for id in items:
		if str(items[id].get("type",""))==item_type and str(items[id].get("location",""))==location:
			items[id]["quantity"]=int(items[id].get("quantity",1))+amount; revision+=1; return
	var new_id:="%s_stack_%d"%[item_type,items.size()+1]
	items[new_id]={"id":new_id,"type":item_type,"display_name":item_type,"quantity":amount,"location":location,"held_by":"","container":location,"grid_cell":null,"portable":false}
	revision+=1

func consume_item(item_id:String)->bool:
	if not items.has(item_id):return false
	var item:Dictionary=items[item_id]; var quantity:=int(item.get("quantity",1))
	if quantity<=0:return false
	if quantity>1: item["quantity"]=quantity-1
	else: item["location"]="consumed"; item["quantity"]=0
	item["held_by"]=""; item["container"]=null; item["grid_cell"]=null; revision+=1; return true

func visible_objects() -> Array:
	var result: Array = []
	for id in objects:
		var object:Dictionary=objects[id]; result.append({"id":id,"type":object.get("type",id),"name":object.display_name,"cells":_cells_for(object),"interaction_cells":object.get("interaction_cells",[]),"supported_tools":object.get("supported_tools",[]),"state":object.get("state",false)})
	return result

func serialize()->Dictionary:
	var placement:Dictionary={}
	for id in objects: placement[id]={"origin_cell":[objects[id].origin_cell.x,objects[id].origin_cell.y],"rotation":objects[id].get("rotation",0),"state":objects[id].get("state",false)}
	var saved_items:Dictionary={}
	for id in items:
		var item:Dictionary=items[id].duplicate(true)
		for key in ["grid_cell","size"]:
			if item.get(key) is Vector2i: item[key]=[item[key].x,item[key].y]
		saved_items[id]=item
	return {"cleanliness":cleanliness,"light_on":light_on,"revision":revision,"resources":resources.duplicate(true),"items":saved_items,"objects":placement}

func load_state(data)->void:
	if not data is Dictionary:return
	cleanliness=float(data.get("cleanliness",cleanliness)); light_on=bool(data.get("light_on",light_on)); revision=int(data.get("revision",revision))
	if data.get("resources",{}) is Dictionary: resources.merge(data.resources,true)
	if data.get("items",{}) is Dictionary: items.merge(data.items,true)
	for item_id in items:
		if items[item_id].get("grid_cell") is Array and items[item_id].grid_cell.size()>=2: items[item_id].grid_cell=Vector2i(int(items[item_id].grid_cell[0]),int(items[item_id].grid_cell[1]))
		if items[item_id].get("size") is Array and items[item_id].size.size()>=2: items[item_id].size=Vector2i(int(items[item_id].size[0]),int(items[item_id].size[1]))
	var saved_items=data.get("items",{})
	if saved_items is Dictionary and saved_items.has("food_01") and not saved_items.has("food_stack"):
		items.erase("food_01"); items["food_stack"]["quantity"]=max(0,int(data.get("resources",{}).get("simple_food",1)))
	resources.erase("simple_food"); resources.erase("book")
	for id in data.get("objects",{}):
		if objects.has(id) and data.objects[id] is Dictionary:
			var c=data.objects[id].get("origin_cell",[]); if c is Array and c.size()>=2: objects[id].origin_cell=Vector2i(int(c[0]),int(c[1]))
			objects[id].rotation=int(data.objects[id].get("rotation",0)); objects[id].state=data.objects[id].get("state",false); _recalculate_placement(objects[id])

func repair_integrity(resident:ResidentState)->void:
	if resident.held_item_id!="" and not items.has(resident.held_item_id): resident.held_item_id=""
	if resident.held_item_id!="":
		items[resident.held_item_id]["location"]="held"; items[resident.held_item_id]["held_by"]="resident"; items[resident.held_item_id]["container"]=null; items[resident.held_item_id]["grid_cell"]=null
	for item_id in items:
		if int(items[item_id].get("quantity",1))<=0: items[item_id]["location"]="consumed"; items[item_id]["held_by"]=""; items[item_id]["container"]=null
	if resident.posture_target_id!="" and not objects.has(resident.posture_target_id): resident.posture_target_id=""; resident.posture="standing"
	if not grid.is_inside(resident.current_cell): resident.current_cell=Vector2i(5,6)
	for id in objects:
		if not bool(objects[id].get("movable",false)): continue
		if not bool(validate_object_placement(id,objects[id].origin_cell,int(objects[id].rotation)).get("ok",false)):
			for y in grid.HEIGHT:
				for x in grid.WIDTH:
					var candidate:=Vector2i(x,y)
					if bool(validate_object_placement(id,candidate,int(objects[id].rotation),[resident.current_cell]).get("ok",false)):
						objects[id].origin_cell=candidate; _recalculate_placement(objects[id]); break
				if bool(validate_object_placement(id,objects[id].origin_cell,int(objects[id].rotation),[resident.current_cell]).get("ok",false)): break

func blocked_cells() -> Array:
	var result:Array=[]
	for id in objects:
		if bool(objects[id].get("blocks_movement",false)):
			for cell in objects[id].get("occupied_cells",[]): result.append(cell)
	return result

func move_object(object_id:String, origin:Vector2i, rotation:int, additional_blocked:Array=[])->Dictionary:
	if not objects.has(object_id) or not bool(objects[object_id].get("movable",false)): return {"ok":false,"error":"object_not_movable"}
	var object:Dictionary=objects[object_id]; var old_origin:Vector2i=object.origin_cell; var old_rotation:int=object.rotation
	object.origin_cell=origin; object.rotation=rotation; _recalculate_placement(object)
	for cell in object.occupied_cells:
		if not grid.is_inside(cell) or cell in blocked_cells_excluding(object_id) or cell in additional_blocked: object.origin_cell=old_origin; object.rotation=old_rotation; _recalculate_placement(object); return {"ok":false,"error":"placement_collision_or_escape"}
	revision+=1
	return {"ok":true,"object":object_id,"origin_cell":[origin.x,origin.y],"rotation":rotation}

func rotate_object(object_id:String, rotation:int, additional_blocked:Array=[])->Dictionary:
	if rotation not in [0,90,180,270]: return {"ok":false,"error":"invalid_rotation"}
	if not objects.has(object_id): return {"ok":false,"error":"object_not_found"}
	return move_object(object_id,objects[object_id].origin_cell,rotation,additional_blocked)

func validate_object_placement(object_id:String, origin:Vector2i, rotation:int, additional_blocked:Array=[])->Dictionary:
	if not objects.has(object_id) or not bool(objects[object_id].get("movable",false)): return {"ok":false,"error":"object_not_movable"}
	var size:=Vector2i(1,1); if object_id=="bed":size=Vector2i(2,2)
	if rotation in [90,270]:size=Vector2i(size.y,size.x)
	var cells:Array=[]; for y in size.y: for x in size.x: cells.append(origin+Vector2i(x,y))
	for cell in cells:
		if not grid.is_inside(cell) or cell in blocked_cells_excluding(object_id) or cell in additional_blocked: return {"ok":false,"error":"placement_collision_or_escape"}
	return {"ok":true}

func blocked_cells_excluding(excluded:String)->Array:
	var result:Array=[]
	for id in objects:
		if id==excluded:continue
		if bool(objects[id].get("blocks_movement",false)):
			for cell in objects[id].get("occupied_cells",[]):result.append(cell)
	return result

func _recalculate_placement(object:Dictionary)->void:
	var origin:Vector2i=object.origin_cell; var size:Vector2i=Vector2i(1,1)
	if object.id=="bed":size=Vector2i(2,2)
	if int(object.rotation) in [90,270]:size=Vector2i(size.y,size.x)
	object.occupied_cells=[]; for y in size.y: for x in size.x: object.occupied_cells.append(origin+Vector2i(x,y))
	var candidates=[origin+Vector2i(0,size.y),origin+Vector2i(size.x-1,size.y),origin+Vector2i(-1,0),origin+Vector2i(size.x,0),origin+Vector2i(0,-1)]
	object.interaction_cells=[]
	for cell in candidates:
		if grid.is_inside(cell) and cell not in object.occupied_cells and cell not in object.interaction_cells: object.interaction_cells.append(cell)
	object.interaction_point=Vector2(70,70)+Vector2(object.interaction_cells[0])*60.0 if not object.interaction_cells.is_empty() else Vector2(-100,-100)

func _cells_for(object:Dictionary)->Array:
	var out:Array=[]
	for cell in object.get("occupied_cells",[]): out.append([cell.x,cell.y])
	return out
