class_name PlanExecutor
extends RefCounted

var plan:Array=[]; var index:=0; var plan_id:=""; var reason:=""; var results:Array=[]; var active:=false
func begin(new_plan:Array,why:String)->void: plan=new_plan.duplicate(true); index=0; reason=why; results=[]; plan_id="plan_%d"%Time.get_ticks_msec(); active=true
func current()->Dictionary: return plan[index] if active and index<plan.size() else {}
func advance(result:Dictionary)->bool:
	results.append(result)
	index += 1
	if index >= plan.size():
		active = false
		return true
	return false
func abort(result:Dictionary)->void: results.append(result); active=false
