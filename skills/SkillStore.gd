class_name SkillStore
extends RefCounted

const MAX_SKILLS:=20
var skills:Array=[]
var candidate_stats:Dictionary={}

func learn(history:Array, room:RoomState)->void:
	var detected:=SkillCandidateDetector.detect(history,room)
	candidate_stats["candidate_detections"]=int(candidate_stats.get("candidate_detections",0))+detected.size()
	for candidate in detected:
		candidate_stats["eligible_sequences"] = int(candidate_stats.get("eligible_sequences",0))+1
		var normalized:=SkillCandidateDetector.normalize(candidate.steps,room); var id:="skill_"+_name_for(normalized)
		if _find(id)!=null: continue
		candidate_stats["threshold_reached"]=int(candidate_stats.get("threshold_reached",0))+1
		skills.append({"id":id,"name":id.trim_prefix("skill_"),"description":_description(normalized),"steps":_abstract(candidate.steps,room),"times_observed":candidate.successes,"offer_count":0,"times_used":0,"success_count":0,"failure_count":0,"status":"active"})
		candidate_stats["skills_created"]=int(candidate_stats.get("skills_created",0))+1
		if skills.size()>MAX_SKILLS: skills.pop_front()

func relevant(room:RoomState, held_item:String, needs:Dictionary, resident:ResidentState=null)->Array:
	var out:Array=[]
	for skill in skills:
		if skill.status!="active":continue
		var expanded:=SkillExecutor.expand(skill,room)
		if expanded.is_empty():continue
		if resident!=null:
			var check:=PlanPreflight.validate(expanded,room,resident,ResidentNeeds.new())
			if not bool(check.get("ok",false)):continue
		skill.offer_count=int(skill.get("offer_count",0))+1
		candidate_stats["skills_offered"]=int(candidate_stats.get("skills_offered",0))+1
		out.append({"id":skill.id,"name":skill.name,"description":skill.description,"success_rate":_rate(skill),"steps":skill.get("steps",[]).duplicate(true)})
		if out.size()>=8:break
	return out

func get_skill(id:String)->Dictionary:
	for skill in skills: if skill.id==id:return skill
	return {}
func mark_used(id:String,success:bool)->void:
	var skill:=get_skill(id); if skill.is_empty():return
	skill.times_used+=1; if success:skill.success_count+=1
	else:skill.failure_count+=1
	if skill.times_used>=3 and _rate(skill)<0.3:skill.status="inactive"
func serialize()->Dictionary:return {"skills":skills,"candidate_stats":candidate_stats}
func load_state(data)->void:
	if data is Dictionary:skills=data.get("skills",[]);candidate_stats=data.get("candidate_stats",{})
func _find(id:String): for skill in skills: if skill.id==id:return skill
func _rate(skill:Dictionary)->float:
	var total:=int(skill.get("success_count",0))+int(skill.get("failure_count",0)); return 0.5 if total==0 else float(skill.success_count)/total
func _name_for(sequence:Array)->String:return ("_".join(sequence)).replace(":type:","_").replace("-","_").left(48)
func _description(sequence:Array)->String:return "Use a learned sequence: "+" -> ".join(sequence)
func _abstract(steps:Array,room:RoomState)->Array:
	var out:Array=[]
	for step in steps:
		var copy:Dictionary=step.duplicate(true); var args:Dictionary=copy.get("args",{}); var target:=str(args.get("target",""));
		if room.objects.has(target): args={"target_type":room.objects[target].get("type",target)}
		elif room.items.has(target): args={"target_type":room.items[target].get("type",target)}
		copy["args"]=args; out.append(copy)
	return out
