class_name MemoryStore
extends RefCounted

const MAX_ENTRIES := 120

var entries: Array = []
var _next_id := 1

func add(time: String, action: String, summary: String, result: String, salience := 0.5, objects := [], context := {}) -> void:
	var text := summary.strip_edges()
	if text == "":
		return
	if not entries.is_empty() and str(entries[0].get("summary","")) == text and str(entries[0].get("related_action","")) == action:
		entries[0]["salience"] = max(float(entries[0].get("salience",0.5)),float(salience)); return
	entries.push_front({
		"id": "mem_%04d" % _next_id,
		"simulation_time": time,
		"type": "episode",
		"summary": text,
		"salience": clamp(float(salience), 0.0, 1.0),
		"related_action": action,
		"related_objects": objects.duplicate(true) if objects is Array else [],
		"need_context": context.duplicate(true) if context is Dictionary else {},
		"result": result
	})
	_next_id += 1
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)

func add_life_event(event:Dictionary)->void:
	if event.is_empty():return
	var activity:=str(event.get("activity","activity")); var target:=str(event.get("target",""))
	var summary:=_narrate(event)
	add(str(event.get("time","")),activity,summary,str(event.get("result",{}).get("reason","completed")),float(event.get("salience",0.5)),[target] if target!="" else [],event.get("need_delta",{}))
	if not entries.is_empty():
		entries[0]["event_type"]="activity_completed"; entries[0]["activity"]=activity; entries[0]["target"]=target; entries[0]["need_effects"]=event.get("need_delta",{}); entries[0]["tags"]=event.get("tags",[])

static func _narrate(event:Dictionary)->String:
	var activity:=str(event.get("activity","")); var delta:Dictionary=event.get("need_delta",{})
	var benefit:=""
	for key in ["boredom","stress","discomfort","loneliness","sleepiness"]:
		if float(delta.get(key,0.0)) < -5.0: benefit=key.replace("_need",""); break
	var phrases={"read":"I spent some time reading","sleep":"I slept for a while","drink":"I had some water","eat":"I ate something","shower":"I took a shower","clean":"I tidied the room","watch_tv":"I watched TV","use_pc":"I used the computer","call_friend":"I tried calling someone"}
	var text:=str(phrases.get(activity,"I spent some time on %s"%activity))
	if benefit!="": text+="; it helped with my %s"%benefit
	return text+"."

func retrieve(action_ids: Array, goals: Array, limit := 6, current_target := "", strong_needs := [], topic_context := []) -> Array:
	var scored: Array = []
	for i in range(entries.size()):
		var memory: Dictionary = entries[i]
		var score := float(memory.get("salience", 0.5)) * 1.4
		score += max(0.0, 1.0 - float(i) / 24.0)
		if str(memory.get("related_action", "")) in action_ids:
			score += 0.25
		if current_target != "" and current_target in memory.get("related_objects", []):
			score += 0.35
		var lower_summary := str(memory.get("summary", "")).to_lower()
		for topic in topic_context:
			var topic_text:=str(topic).to_lower()
			if topic_text=="": continue
			if topic_text in lower_summary or topic_text in str(memory.get("related_objects",[])).to_lower() or topic_text in str(memory.get("related_action","")).to_lower(): score += 0.5
		for goal in goals:
			for token in _tokens(str(goal)):
				if token.length() >= 3 and token in lower_summary:
					score += 0.08
		var effects:Dictionary=memory.get("need_effects",memory.get("need_context",{}))
		for need_name in strong_needs:
			if float(effects.get(str(need_name),0.0)) < 0.0: score += 0.18
		scored.append({"score": score, "memory": memory})
	scored.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var result: Array = []
	for row in scored.slice(0, min(limit, scored.size())):
		result.append(row.memory.duplicate(true))
	return result

func serialize() -> Dictionary:
	return {"next_id": _next_id, "entries": entries.duplicate(true)}

func load_state(data) -> void:
	entries = []
	_next_id = 1
	if not (data is Dictionary):
		return
	var loaded = data.get("entries", [])
	if loaded is Array:
		for memory in loaded:
			if memory is Dictionary:
				entries.append(memory.duplicate(true))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	_next_id = max(1, int(data.get("next_id", entries.size() + 1)))

static func _tokens(text: String) -> PackedStringArray:
	var normalized := text.to_lower()
	for separator in [".", ",", "!", "?", ":", ";", "-", "_", "\n"]:
		normalized = normalized.replace(separator, " ")
	return normalized.split(" ", false)
