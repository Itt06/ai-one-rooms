class_name SkillExecutor
extends RefCounted

static func expand(skill:Dictionary, room:RoomState)->Array:
	var result:Array=[]
	for step in skill.get("steps",[]):
		var copy:Dictionary=step.duplicate(true); var args:Dictionary=copy.get("args",{}); var kind:=str(args.get("target_type",""))
		if kind!="":
			var id:=_resolve(kind,room,copy.get("tool","")); if id=="":return []
			args={"target":id}; copy["args"]=args
		result.append(copy)
	return result
static func _resolve(kind:String,room:RoomState,tool:String)->String:
	if tool in ["read","pick_up","eat","put_down"]:
		for id in room.items: if str(room.items[id].get("type",""))==kind and str(room.items[id].get("location",""))!="consumed":return id
	else:
		for id in room.objects: if str(room.objects[id].get("type",id))==kind:return id
	return ""
