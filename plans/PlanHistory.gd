class_name PlanHistory
extends RefCounted

var entries: Array = []
func add(plan_id:String, why:String, tools:Array, results:Array, success:bool, started:String, completed:String)->void:
	entries.push_front({"plan_id":plan_id,"reason":why,"tools":tools,"results":results,"success":success,"started_at":started,"completed_at":completed})
	if entries.size()>50: entries.resize(50)
func serialize()->Array: return entries.duplicate(true)
func load_state(value)->void: entries=value.duplicate(true) if value is Array else []
