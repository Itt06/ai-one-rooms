class_name GoalStore
extends RefCounted
var goals: Array = []
func apply(updates) -> void:
	if not updates is Dictionary: return
	for text in updates.get("add",[]):
		var s:=str(text).strip_edges(); if s.length() > 0 and s.length() <= 120 and goals.size() < 5 and not _has(s): goals.append({"id":"goal_%04d"%goals.size(),"text":s,"status":"active"})
	for text in updates.get("complete",[]): _set_status(str(text),"completed")
	for text in updates.get("abandon",[]): _set_status(str(text),"abandoned")
func _has(text:String)->bool:
	for g in goals:
		if g.text==text or g.id==text: return true
	return false
func _set_status(text:String,state:String)->void: for g in goals: if g.text==text or g.id==text: g.status=state
