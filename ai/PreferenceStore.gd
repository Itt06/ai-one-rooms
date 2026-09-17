class_name PreferenceStore
extends RefCounted

var values: Dictionary = {}
var counts: Dictionary = {}
var recent_actions: Array = []
var sleep_hours: Array = []
var target_counts: Dictionary = {}

func record(action: String, improvement: float, hour := -1) -> void:
	counts[action] = int(counts.get(action, 0)) + 1
	values[action] = clamp(float(values.get(action, 0.0)) + improvement, -1.0, 1.0)
	recent_actions.push_front(action)
	if recent_actions.size() > 12:
		recent_actions.resize(12)
	if action == "sleep" and hour >= 0:
		sleep_hours.push_front(hour)
		if sleep_hours.size() > 14:
			sleep_hours.resize(14)

func record_life_event(event:Dictionary)->void:
	var action:=str(event.get("activity","")); var target:=str(event.get("target",""))
	if action=="":return
	var before:Dictionary=event.get("before_needs",{}); var after:Dictionary=event.get("after_needs",{}); var improvement:=0.0
	for key in ["boredom","stress","discomfort","loneliness"]: improvement+=float(before.get(key,0.0))-float(after.get(key,0.0))
	record(action,clamp(improvement/350.0,-0.05,0.05),int(event.get("time_hour",-1)))
	target_counts[action+":"+target]=int(target_counts.get(action+":"+target,0))+1

func summary() -> Dictionary:
	var top := values.keys()
	top.sort_custom(func(a, b): return abs(float(values[a])) > abs(float(values[b])))
	var compact := {}
	for key in top.slice(0, min(6, top.size())):
		compact[key] = snapped(float(values[key]), 0.01)
	return compact

func habit_summary() -> Dictionary:
	var usual_sleep_hour = null
	if not sleep_hours.is_empty():
		var total := 0.0
		for hour in sleep_hours:
			total += float(hour)
		usual_sleep_hour = int(round(total / sleep_hours.size()))
	return {
		"recent_actions": recent_actions.duplicate(),
		"action_counts": counts.duplicate(true),
		"target_counts": target_counts.duplicate(true),
		"usual_sleep_hour": usual_sleep_hour
	}

func serialize() -> Dictionary:
	return {"values": values.duplicate(true), "counts": counts.duplicate(true), "recent_actions": recent_actions.duplicate(), "sleep_hours": sleep_hours.duplicate(), "target_counts": target_counts.duplicate(true)}

func load_state(data) -> void:
	values = {}
	counts = {}
	recent_actions = []
	sleep_hours = []
	target_counts = {}
	if not (data is Dictionary):
		return
	var loaded_values = data.get("values", {})
	var loaded_counts = data.get("counts", {})
	var loaded_recent = data.get("recent_actions", [])
	var loaded_sleep = data.get("sleep_hours", [])
	var loaded_targets = data.get("target_counts", {})
	if loaded_values is Dictionary:
		values = loaded_values.duplicate(true)
	if loaded_counts is Dictionary:
		counts = loaded_counts.duplicate(true)
	if loaded_recent is Array:
		recent_actions = loaded_recent.duplicate()
	if loaded_sleep is Array:
		sleep_hours = loaded_sleep.duplicate()
	if loaded_targets is Dictionary:
		target_counts = loaded_targets.duplicate(true)
