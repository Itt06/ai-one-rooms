class_name RoomGrid
extends RefCounted

const WIDTH := 12
const HEIGHT := 8
var cells: Array = []

func _init() -> void:
	for y in HEIGHT:
		var row: Array = []
		for x in WIDTH:
			row.append({"x":x,"y":y,"terrain":"floor","walkable":true,"occupant_ids":[],"zone":_zone_for(x,y),"metadata":{}})
		cells.append(row)

func is_inside(cell: Vector2i) -> bool: return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT
func get_cell(cell: Vector2i) -> Dictionary: return cells[cell.y][cell.x] if is_inside(cell) else {}
func set_walkable(cell: Vector2i, value: bool) -> void:
	if is_inside(cell): cells[cell.y][cell.x].walkable = value
func zone(cell: Vector2i) -> String: return str(get_cell(cell).get("zone","room"))

func find_path(start: Vector2i, goal: Vector2i, blocked: Array = []) -> Array:
	if not is_inside(start) or not is_inside(goal) or not bool(get_cell(goal).get("walkable",false)) or goal in blocked: return []
	var queue: Array = [start]; var previous := {start:Vector2i(-999,-999)}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal: break
		for next in [current+Vector2i(1,0),current+Vector2i(-1,0),current+Vector2i(0,1),current+Vector2i(0,-1)]:
			if not is_inside(next) or next in previous or next in blocked or not bool(get_cell(next).get("walkable",false)): continue
			previous[next] = current; queue.append(next)
	if not previous.has(goal): return []
	var path: Array = []; var cursor := goal
	while cursor != Vector2i(-999,-999): path.push_front(cursor); cursor = previous[cursor]
	return path

func _zone_for(x:int,y:int)->String:
	if y <= 1: return "window_side"
	if x <= 3 and y >= 5: return "bed_area"
	if x >= 8 and y >= 3: return "bathroom_area"
	if x >= 7 and y <= 3: return "kitchen_area"
	if x >= 4 and x <= 6: return "desk_area"
	return "center"
