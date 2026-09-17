class_name PrimitiveToolValidator
extends RefCounted

static func validate(step, room:RoomState, grid:RoomGrid, resident:Dictionary, items:Dictionary)->Dictionary:
	if not step is Dictionary:return _fail("step_not_object")
	var tool:=str(step.get("tool","")); if not PrimitiveToolCatalog.TOOLS.has(tool):return _fail("unknown_tool")
	if step.has("action") or step.has("target") or not step.has("args") or not (step.args is Dictionary):return _fail("canonical_step_requires_tool_and_args_object")
	var definition:Dictionary=PrimitiveToolCatalog.TOOLS[tool]; var args:Dictionary=step.args; var target:=str(args.get("target",""))
	for key in args: if not definition.args_schema.has(key):return _fail("unknown_argument")
	for key in definition.args_schema: if not args.has(key):return _fail("missing_argument")
	if definition.target=="none" and not args.is_empty():return _fail("arguments_not_allowed")
	if definition.target in ["object","item"] and target=="":return _fail("target_required_in_args")
	if definition.target=="object" and not room.objects.has(target):return _fail("target_not_found")
	if definition.target=="item" and not items.has(target):return _fail("item_not_found")
	if tool=="move_to":
		if not _integer_number(args.x) or not _integer_number(args.y):return _fail("cell_must_be_integer")
		var destination:=Vector2i(int(args.x),int(args.y)); if not grid.is_inside(destination) or grid.find_path(resident.current_cell,destination,room.blocked_cells()).is_empty():return _fail("destination_unreachable")
	if tool=="move_near":
		if InteractionResolver.nearest_cell(room,target,resident.current_cell).get("ok",false)!=true:return _fail("target_unreachable")
	if tool in ["sit","lie_down"]:
		if tool=="sit" and target not in ["bed","chair"]:return _fail("invalid_posture_target")
		if not InteractionResolver.is_at_interaction_cell(room,target,resident.current_cell):return _fail("target_not_interactable_now")
	if tool in ["move_object","rotate_object"]:
		if not bool(room.objects[target].get("movable",false)):return _fail("object_not_movable")
		if not InteractionResolver.is_at_interaction_cell(room,target,resident.current_cell):return _fail("target_not_interactable_now")
		if tool=="move_object" and (not _integer_number(args.x) or not _integer_number(args.y)):return _fail("destination_cell_must_be_integer")
		if tool=="rotate_object" and int(args.rotation) not in [0,90,180,270]:return _fail("invalid_rotation")
		if tool=="move_object" and not bool(room.validate_object_placement(target,Vector2i(int(args.x),int(args.y)),int(room.objects[target].get("rotation",0)),[resident.current_cell]).get("ok",false)):return _fail("invalid_placement")
	if tool in ["open","close","turn_on","turn_off"] and tool not in room.objects[target].get("supported_tools",[]):return _fail("tool_not_supported")
	if tool in ["open","close","turn_on","turn_off"] and not InteractionResolver.is_at_interaction_cell(room,target,resident.current_cell):return _fail("target_not_interactable_now")
	if tool in ["open","turn_on"] and bool(room.objects[target].get("state",false)):return _fail("already_active")
	if tool in ["close","turn_off"] and not bool(room.objects[target].get("state",false)):return _fail("already_inactive")
	if tool in ["read","eat"]:
		var expected:="book" if tool=="read" else "simple_food"
		if str(items[target].get("type",""))!=expected or resident.get("held_item_id","")!=target:return _fail("item_not_held_or_wrong_type")
	if tool=="pick_up":
		if resident.get("held_item_id","")!="" or str(items[target].get("location",""))=="held" or not bool(items[target].get("portable",false)) or int(items[target].get("quantity",1))<=0:return _fail("hands_or_item_invalid")
		var container:=str(items[target].get("container",""))
		if room.objects.has(container) and not InteractionResolver.is_at_interaction_cell(room,container,resident.current_cell):return _fail("item_requires_proximity_to_%s"%container)
		if room.objects.has(container) and container=="fridge" and not bool(room.objects[container].get("state",false)):return _fail("fridge_closed")
	if tool in ["use_pc","watch_tv","order_groceries"] and target in ["pc","tv"] and not bool(room.objects[target].get("state",false)):return _fail("target_is_off")
	if tool=="put_down":
		if resident.get("held_item_id","")!=target or not _integer_number(args.x) or not _integer_number(args.y):return _fail("invalid_drop_args")
		var drop:=Vector2i(int(args.x),int(args.y)); if not grid.is_inside(drop) or drop in room.blocked_cells() or drop==resident.current_cell:return _fail("drop_cell_blocked")
	if definition.target=="object" and tool in ActivityCatalog.DEFINITIONS and tool not in ["move_near","inspect","move_object","rotate_object"]:
		if not InteractionResolver.is_at_interaction_cell(room,target,resident.current_cell):return _fail("target_not_interactable_now")
	return {"ok":true,"step":step}

static func _fail(error:String)->Dictionary:return {"ok":false,"error":error}

static func _integer_number(value)->bool:
	return (value is int) or (value is float and is_equal_approx(float(value),round(float(value))))
