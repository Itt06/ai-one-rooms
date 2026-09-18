class_name ResidentMovement
extends RefCounted

var path:Array=[]
var path_index:=0

static func prepare_posture(state:ResidentState)->void:
	if state.posture=="standing": return
	state.posture="standing"
	state.posture_target_id=""
	state.revision+=1
func begin(grid:RoomGrid,start:Vector2i,destination:Vector2i,blocked:Array)->bool:
	path=grid.find_path(start,destination,blocked); path_index=1; return not path.is_empty()
func update(state:ResidentState,delta:float,speed:float)->bool:
	if path.is_empty() or path_index>=path.size(): return true
	var target:Vector2i=path[path_index]; state.render_position=state.render_position.move_toward(Vector2(target)*60.0+Vector2(70,70),speed*delta)
	if state.render_position.distance_to(Vector2(target)*60.0+Vector2(70,70))<3.0:
		state.current_cell=target; state.revision+=1; path_index+=1
	return path_index>=path.size()
