class_name MemoryStore
extends RefCounted

var entries: Array = []
func add(time: String, action: String, summary: String, result: String, salience := 0.5, objects := [], context := {}) -> void:
	entries.push_front({"id":"mem_%04d" % (entries.size()+1),"simulation_time":time,"type":"episode","summary":summary,"salience":salience,"related_action":action,"related_objects":objects,"need_context":context,"result":result})
	if entries.size() > 50: entries.resize(50)

func retrieve(action_ids: Array, goals: Array, limit := 6) -> Array:
	var scored: Array = []
	for i in entries.size():
		var e: Dictionary = entries[i]; var score: float = float(e.salience) + max(0.0, 1.0 - float(i) / 20.0)
		if e.related_action in action_ids: score += 0.25
		for g in goals: if str(g).to_lower() in str(e.summary).to_lower(): score += 0.2
		scored.append({"score":score,"memory":e})
	scored.sort_custom(func(a,b): return a.score > b.score)
	var out: Array = []; for x in scored.slice(0,limit): out.append(x.memory)
	return out
