class_name InteractionResolver
extends RefCounted

static func nearest_cell(room: RoomState, object_id: String, from_cell: Vector2i) -> Dictionary:
	if not room.objects.has(object_id): return {"ok":false,"error":"target_not_found"}
	var object:Dictionary = room.objects[object_id]
	var best:Dictionary = {}
	for cell in object.get("interaction_cells",[]):
		if not cell is Vector2i or not room.grid.is_inside(cell): continue
		var path:Array = room.grid.find_path(from_cell,cell,room.blocked_cells())
		if path.is_empty(): continue
		if best.is_empty() or path.size() < int(best.get("distance",999999)):
			best = {"ok":true,"cell":cell,"path":path,"distance":path.size()}
	return best if not best.is_empty() else {"ok":false,"error":"target_unreachable"}

static func reachable_cells(room:RoomState, object_id:String, from_cell:Vector2i)->Array:
	var result:Array=[]
	if not room.objects.has(object_id): return result
	for cell in room.objects[object_id].get("interaction_cells",[]):
		if cell is Vector2i and room.grid.is_inside(cell) and not room.grid.find_path(from_cell,cell,room.blocked_cells()).is_empty(): result.append(cell)
	return result

static func is_at_interaction_cell(room:RoomState, object_id:String, resident_cell:Vector2i)->bool:
	if not room.objects.has(object_id): return false
	for cell in room.objects[object_id].get("interaction_cells",[]):
		if cell == resident_cell: return true
	return false
