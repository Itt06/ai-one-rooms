class_name PlanPreflight
extends RefCounted

static func validate(plan:Array, room:RoomState, resident:ResidentState, needs:ResidentNeeds)->Dictionary:
	if plan.is_empty() or plan.size()>6:return {"ok":false,"error":"plan_length"}
	var room_copy:=RoomState.new(); room_copy.load_state(room.serialize())
	var resident_copy:=ResidentState.new(); resident_copy.load_state(resident.serialize())
	var needs_copy:=ResidentNeeds.new(); needs_copy.values=needs.values.duplicate(true)
	for step in plan:
		var checked:=PrimitiveToolValidator.validate(step,room_copy,room_copy.grid,{"current_cell":resident_copy.current_cell,"held_item_id":resident_copy.held_item_id},room_copy.items)
		if not bool(checked.get("ok",false)):return {"ok":false,"error":str(checked.get("error","step_rejected"))}
		var tool:=str(step.get("tool","")); var args:Dictionary=step.get("args",{})
		if tool=="move_near":
			var nearest:=InteractionResolver.nearest_cell(room_copy,str(args.target),resident_copy.current_cell); if not bool(nearest.get("ok",false)):return {"ok":false,"error":"target_unreachable"}
			resident_copy.current_cell=nearest.cell
		elif tool=="move_to": resident_copy.current_cell=Vector2i(int(args.x),int(args.y))
		elif ActivityCatalog.DEFINITIONS.has(tool):
			var activity:=ActivityExecutor.new(); var started:=activity.begin(tool,str(args.get("target","")),"preflight",room_copy,needs_copy,resident_copy)
			if not bool(started.get("ok",false)):return {"ok":false,"error":str(started.get("error","activity_rejected"))}
			activity.remaining_minutes=0.0; activity.update(0.0); var result:=activity.complete(room_copy,needs_copy,resident_copy)
			if not bool(result.get("ok",false)):return {"ok":false,"error":"activity_preflight_failed"}
		else:
			var result:=PrimitiveToolExecutor.execute(step,room_copy,resident_copy,needs_copy)
			if not bool(result.get("ok",false)):return {"ok":false,"error":str(result.get("error","executor_rejected"))}
	return {"ok":true}
