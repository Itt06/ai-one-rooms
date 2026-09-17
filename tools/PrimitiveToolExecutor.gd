class_name PrimitiveToolExecutor
extends RefCounted

static func execute(step:Dictionary, room:RoomState, resident:ResidentState, needs:ResidentNeeds)->Dictionary:
	var tool:=str(step.get("tool","")); var raw_args=step.get("args",{}); var target:=str(step.get("target",raw_args.get("target","") if raw_args is Dictionary else ""))
	if tool=="pick_up": resident.held_item_id=target; room.items[target].location="resident"; room.items[target].held_by="resident"
	elif tool=="put_down": room.items[target].location="room"; room.items[target].held_by=""; resident.held_item_id=""
	elif tool=="sit": resident.posture="sitting"
	elif tool=="stand": resident.posture="standing"
	elif tool=="lie_down": resident.posture="lying"
	elif tool=="read": needs.apply({"boredom":-35.0,"stress":-5.0})
	elif tool=="eat": needs.apply({"hunger":-45.0}); resident.held_item_id=""; room.items[target].location="consumed"
	elif tool=="drink": needs.apply({"thirst":-50.0})
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
