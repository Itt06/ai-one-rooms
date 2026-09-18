class_name DiaryComposer
extends RefCounted

static func compose(time_text:String, activity:String, before:Dictionary, after:Dictionary, recent_activity:String="", recent_memory:String="")->String:
	var subject:=ObserverText.activity_label(activity)
	var text:="%s、今日は%s。" % [time_text,subject]
	var changes:Array=[]
	for key in ["hunger","thirst","sleepiness","hygiene_need","toilet_need","boredom","loneliness","stress","discomfort"]:
		var delta:=float(after.get(key,before.get(key,0.0)))-float(before.get(key,0.0))
		if delta<=-8.0: changes.append("%sが少し落ち着いた" % ObserverText.need_label(key))
		elif delta>=8.0: changes.append("%sが強くなった" % ObserverText.need_label(key))
	if not changes.is_empty(): text += " %s。" % "、".join(changes.slice(0,2))
	if recent_activity!="" and recent_activity!=activity: text += " 最近は%sもした。" % ObserverText.activity_label(recent_activity)
	if recent_memory!="": text += " 思い出していたこと：%s" % recent_memory
	return text.left(500)
