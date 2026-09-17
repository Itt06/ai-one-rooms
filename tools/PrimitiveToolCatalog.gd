class_name PrimitiveToolCatalog
extends RefCounted

const TOOLS := {
	"move_to":{"target":"cell","args_schema":{"x":"integer","y":"integer"}},"move_near":{"target":"object","args_schema":{"target":"object_id"}},
	"move_object":{"target":"object","args_schema":{"target":"object_id","x":"integer","y":"integer"}},"rotate_object":{"target":"object","args_schema":{"target":"object_id","rotation":"integer"}},
	"inspect":{"target":"object","args_schema":{"target":"object_id"}},"pick_up":{"target":"item","args_schema":{"target":"item_id"}},"put_down":{"target":"item","args_schema":{"target":"item_id","x":"integer","y":"integer"}},
	"open":{"target":"object","args_schema":{"target":"object_id"}},"close":{"target":"object","args_schema":{"target":"object_id"}},"sit":{"target":"object","args_schema":{"target":"object_id"}},"stand":{"target":"none","args_schema":{}},"lie_down":{"target":"object","args_schema":{"target":"object_id"}},
	"turn_on":{"target":"object","args_schema":{"target":"object_id"}},"turn_off":{"target":"object","args_schema":{"target":"object_id"}},
	"read":{"target":"item","args_schema":{"target":"item_id"}},"eat":{"target":"item","args_schema":{"target":"item_id"}},"drink":{"target":"object","args_schema":{"target":"object_id"}},
	"sleep":{"target":"object","args_schema":{"target":"object_id"}},"take_shower":{"target":"object","args_schema":{"target":"object_id"}},"use_toilet":{"target":"object","args_schema":{"target":"object_id"}},"use_pc":{"target":"object","args_schema":{"target":"object_id"}},"watch_tv":{"target":"object","args_schema":{"target":"object_id"}},"clean":{"target":"object","args_schema":{"target":"object_id"}},"look_out_window":{"target":"object","args_schema":{"target":"object_id"}},"write_diary":{"target":"object","args_schema":{"target":"object_id"}},"call_friend":{"target":"object","args_schema":{"target":"object_id"}},"order_groceries":{"target":"object","args_schema":{"target":"object_id"}},"take_out_trash":{"target":"object","args_schema":{"target":"object_id"}},"wait":{"target":"none","args_schema":{}}
}

static func available(room:RoomState,resident:Dictionary)->Array:
	var result:Array=[]
	for id in TOOLS:
		if id=="pick_up" and resident.get("held_item_id","")!="":continue
		if id=="put_down" and resident.get("held_item_id","")=="":continue
		if id in ["eat","read"] and _item_targets(room,id).is_empty():continue
		if id=="drink" and _object_targets(room,id).is_empty():continue
		if id=="take_out_trash" and int(room.resources.get("trash",0))<=0:continue
		if id=="clean" and float(room.cleanliness)>=97.0:continue
		if id=="order_groceries" and room.item_quantity("simple_food")>2:continue
		var targets:Array=[]
		if TOOLS[id].target=="object":targets=_object_targets(room,id)
		elif TOOLS[id].target=="item":targets=_item_targets(room,id)
		if TOOLS[id].target!="none" and targets.is_empty():continue
		var entry={"tool":id,"target_type":TOOLS[id].target,"args_schema":TOOLS[id].args_schema}
		if TOOLS[id].target!="none":entry["valid_targets"]=targets
		result.append(entry)
	return result

static func _object_targets(room:RoomState,tool:String)->Array:
	var result:Array=[]
	for id in room.objects:
		var object:Dictionary=room.objects[id]; var affordances:Array=object.get("supported_tools",[])
		if tool=="move_near" or tool=="inspect":result.append(id); continue
		if tool in ["move_object","rotate_object"] and bool(object.get("movable",false)):result.append(id); continue
		if tool in ["open","turn_on"] and not bool(object.get("state",false)) and tool in affordances:result.append(id); continue
		if tool in ["close","turn_off"] and bool(object.get("state",false)) and tool in affordances:result.append(id); continue
		if tool in affordances:result.append(id)
	return result

static func _item_targets(room:RoomState,tool:String)->Array:
	var result:Array=[]
	for id in room.items:
		var item:Dictionary=room.items[id]; var quantity:=int(item.get("quantity",1))
		if quantity<=0 or str(item.get("location",""))=="consumed":continue
		if tool=="pick_up" and bool(item.get("portable",false)) and str(item.get("location",""))!="held":result.append(id)
		elif tool=="put_down" and str(item.get("location",""))=="held":result.append(id)
		elif tool=="read" and str(item.get("type",""))=="book" and bool(item.get("properties",{}).get("readable",true)):result.append(id)
		elif tool=="eat" and str(item.get("type",""))=="simple_food" and bool(item.get("properties",{}).get("edible",true)):result.append(id)
	return result
