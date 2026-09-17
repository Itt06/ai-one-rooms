class_name PlanHistory
extends RefCounted

var entries: Array = []
func add(plan_id:String, why:String, steps:Array, results:Array, success:bool, started:String, completed:String, status:="completed", failure_reason=null)->void:
	entries.push_front({"plan_id":plan_id,"reason":why,"steps":steps,"tools":steps,"results":results,"status":status,"success":success,"started_at":started,"completed_at":completed,"failure_reason":failure_reason})
	if entries.size()>50: entries.resize(50)
func serialize()->Array: return entries.duplicate(true)
func load_state(value)->void: entries=value.duplicate(true) if value is Array else []
