class_name PrimitiveToolExecutor
extends RefCounted

static func execute(step:Dictionary, room:RoomState, resident:ResidentState, needs:ResidentNeeds)->Dictionary:
	var tool:=str(step.get("tool","")); var raw_args:Dictionary=step.get("args",{}); var target:=str(raw_args.get("target",""))
	if tool=="move_object": return room.move_object(target,Vector2i(int(raw_args.x),int(raw_args.y)),int(room.objects[target].get("rotation",0)),[resident.current_cell])
	elif tool=="rotate_object": return room.rotate_object(target,int(raw_args.rotation),[resident.current_cell])
	elif tool=="pick_up": resident.held_item_id=target; room.items[target].location="held"; room.items[target].held_by="resident"; room.items[target].container=null; room.items[target].grid_cell=null; resident.revision+=1; room.revision+=1
	elif tool=="put_down": room.items[target].location="floor"; room.items[target].held_by=""; room.items[target].container=null; room.items[target].grid_cell=Vector2i(int(raw_args.x),int(raw_args.y)); resident.held_item_id=""; resident.revision+=1; room.revision+=1
	elif tool=="sit": resident.posture="sitting"; resident.posture_target_id=target; resident.revision+=1
	elif tool=="stand": resident.posture="standing"; resident.posture_target_id=""; resident.revision+=1
	elif tool=="lie_down": resident.posture="lying"; resident.posture_target_id=target; resident.revision+=1
	elif tool=="turn_on" or tool=="open": room.objects[target]["state"]=true
	elif tool=="turn_off" or tool=="close": room.objects[target]["state"]=false
	elif tool in ActivityCatalog.DEFINITIONS: return {"ok":false,"tool":tool,"target":target,"error":"timed_activity_requires_activity_executor"}
	return {"ok":true,"tool":tool,"target":target,"result":_result_name(tool)}

static func _result_name(tool:String)->String:
	match tool:
		"pick_up":return "picked_up"
		"put_down":return "put_down"
		"sit":return "sitting"
		"stand":return "standing"
		"lie_down":return "lying"
		"read":return "read"
		"eat":return "ate"
		"drink":return "drank"
	return "completed"
