class_name ResidentState
extends RefCounted

var current_cell := Vector2i(5,6)
var next_cell := Vector2i(5,6)
var held_item_id := ""
var posture := "standing"
var render_position := Vector2.ZERO

func serialize()->Dictionary: return {"cell":[current_cell.x,current_cell.y],"next_cell":[next_cell.x,next_cell.y],"held_item_id":held_item_id,"posture":posture,"render_position":[render_position.x,render_position.y]}
func load_state(data)->void:
	if not data is Dictionary:return
	var c=data.get("cell",[5,6]); if c is Array and c.size()>=2: current_cell=Vector2i(int(c[0]),int(c[1]))
	next_cell=current_cell; held_item_id=str(data.get("held_item_id", "")); posture=str(data.get("posture","standing"))
