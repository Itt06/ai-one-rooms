class_name SkillCandidateDetector
extends RefCounted

const MIN_SUCCESSES := 3
const MIN_STEPS := 3
const MAX_STEPS := 6

static func normalize(steps:Array, room:RoomState)->Array:
	var out:Array=[]
	for step in steps:
		if not step is Dictionary: continue
		var tool:=str(step.get("tool","")); var args:Dictionary=step.get("args",{})
		if tool in ["wait","move_to"]: out.append(tool); continue
		var target:=str(args.get("target","")); var kind:=target
		if room.objects.has(target): kind=str(room.objects[target].get("type",target))
		elif room.items.has(target): kind=str(room.items[target].get("type",target))
		out.append("%s:type:%s"%[tool,kind])
	return out

static func detect(history:Array, room:RoomState)->Array:
	var stats:Dictionary={}
	for entry in history:
		if not entry is Dictionary or str(entry.get("status",""))!="completed" or not bool(entry.get("success",false)): continue
		var steps:Array=entry.get("steps",entry.get("tools",[])); if steps.size()<MIN_STEPS or steps.size()>MAX_STEPS: continue
		var key:=JSON.stringify(normalize(steps,room)); if key in ["[\"wait\"]"]: continue
		if not stats.has(key): stats[key]={"steps":steps,"successes":0,"failures":0}
		stats[key].successes+=1
	var result:Array=[]
	for key in stats:
		if stats[key].successes>=MIN_SUCCESSES: result.append(stats[key])
	return result
