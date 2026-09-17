class_name PrimitiveToolValidator
extends RefCounted

static func validate(step, room: RoomState, grid: RoomGrid, resident: Dictionary, items: Dictionary) -> Dictionary:
	if not step is Dictionary: return _fail("step_not_object")
	var tool := str(step.get("tool","")); if not PrimitiveToolCatalog.TOOLS.has(tool): return _fail("unknown_tool")
	if step.has("action") or step.has("target") or not step.has("args") or not (step.args is Dictionary): return _fail("canonical_step_requires_tool_and_args_object")
	var raw_args:Dictionary = step.args
	var target := str(raw_args.get("target", ""))
	if tool == "move_to":
		var args:Dictionary = step.args; if not (args.get("x") is int) or not (args.get("y") is int): return _fail("cell_must_be_integer")
		var destination:=Vector2i(int(args.x),int(args.y)); if not grid.is_inside(destination) or not grid.find_path(resident.current_cell,destination).size(): return _fail("destination_unreachable")
	if tool == "move_near" and not room.objects.has(target): return _fail("target_not_found")
	if tool in ["move_object","rotate_object"]:
		if not room.objects.has(target) or not bool(room.objects[target].get("movable",false)): return _fail("object_not_movable")
		if tool=="move_object" and (not raw_args.get("x") is int or not raw_args.get("y") is int): return _fail("destination_cell_must_be_integer")
		if tool=="rotate_object" and int(raw_args.get("rotation",-1)) not in [0,90,180,270]: return _fail("invalid_rotation")
		if tool=="move_object":
			var placement:=room.validate_object_placement(target,Vector2i(int(raw_args.x),int(raw_args.y)),int(room.objects[target].get("rotation",0)))
			if not bool(placement.get("ok",false)): return _fail(str(placement.get("error","invalid_placement")))
	if tool in ["pick_up","put_down","eat","read"] and not items.has(target): return _fail("item_not_found")
	if tool == "pick_up" and (resident.get("held_item_id","") != "" or not bool(items[target].get("portable",false))): return _fail("hands_or_item_invalid")
	if tool == "pick_up":
		var container:=str(items[target].get("container","")); if room.objects.has(container) and not _near_any(resident.get("current_cell",Vector2i(-1,-1)),room.objects[container].get("interaction_cells",[])): return _fail("target_not_reachable")
	if tool in ["eat","read"] and resident.get("held_item_id","") != target: return _fail("item_not_held")
	if tool=="put_down":
		if resident.get("held_item_id","")!=target or not raw_args.get("x") is int or not raw_args.get("y") is int: return _fail("invalid_drop_args")
		var drop:=Vector2i(int(raw_args.x),int(raw_args.y)); if not grid.is_inside(drop) or drop in room.blocked_cells(): return _fail("drop_cell_blocked")
	return {"ok":true,"step":step}

static func _fail(error:String)->Dictionary: return {"ok":false,"error":error}
static func _near_any(cell:Vector2i, candidates:Array)->bool:
	for candidate in candidates:
		if cell.distance_to(candidate) <= 1: return true
	return false
