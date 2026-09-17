class_name PrimitiveToolCatalog
extends RefCounted

const TOOLS := {
	"move_to":{"target":"cell","args_schema":{"x":"integer","y":"integer"}},"move_near":{"target":"object","args_schema":{"target":"object_id"}},
	"move_object":{"target":"object","args_schema":{"target":"object_id","x":"integer","y":"integer"}},"rotate_object":{"target":"object","args_schema":{"target":"object_id","rotation":"integer"}},
	"inspect":{"target":"object","args_schema":{"target":"object_id"}},"pick_up":{"target":"item","args_schema":{"target":"item_id"}},"put_down":{"target":"item","args_schema":{"target":"item_id","x":"integer","y":"integer"}},
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
		if id == "eat" and not _has_item(room,"simple_food"): continue
		if id == "read" and not _has_item(room,"book"): continue
		if id == "drink" and int(room.resources.get("water",0)) <= 0: continue
		if id in ["move_object","rotate_object"]:
			var movable_found:=false
			for object_id in room.objects:
				if bool(room.objects[object_id].get("movable",false)): movable_found=true; break
			if not movable_found: continue
		var entry={"tool":id,"target_type":TOOLS[id].target,"args_schema":TOOLS[id].args_schema}
		if TOOLS[id].target=="object":
			entry["valid_targets"]=_object_targets(room,id)
			if id=="sit":entry["valid_targets"]=["bed","chair"]
			if id in ["move_object","rotate_object"]:entry["valid_targets"]=room.objects.keys().filter(func(object_id):return bool(room.objects[object_id].get("movable",false)))
		if TOOLS[id].target=="item":entry["valid_targets"]=_item_targets(room,id)
		result.append(entry)
	return result

static func _has_item(room:RoomState,item_type:String)->bool:
	for id in room.items:
		if str(room.items[id].get("type",""))==item_type and str(room.items[id].get("location","")) not in ["consumed","held"]: return true
	return false

static func _object_targets(room:RoomState,tool:String)->Array:
	var out:Array=[]
	for id in room.objects:
		var object:Dictionary=room.objects[id]
		var supported:Array=object.get("supported_actions",[])
		if tool in ["move_near","inspect"] or tool in ["open","close","turn_on","turn_off"] or tool in ["move_object","rotate_object"]: out.append(id)
		elif tool=="drink" and "drink_water" in supported: out.append(id)
	return out

static func _item_targets(room:RoomState,tool:String)->Array:
	var out:Array=[]
	for id in room.items:
		var item:Dictionary=room.items[id]
		if str(item.get("location",""))=="consumed": continue
		if tool=="pick_up" and bool(item.get("portable",false)) and str(item.get("location",""))!="held": out.append(id)
		elif tool=="put_down" and str(item.get("location",""))=="held": out.append(id)
		elif tool=="read" and str(item.get("type",""))=="book": out.append(id)
		elif tool=="eat" and str(item.get("type",""))=="simple_food": out.append(id)
	return out
