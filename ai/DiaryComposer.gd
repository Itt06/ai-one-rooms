class_name DiaryComposer
extends RefCounted

static func compose(time_text:String, activity:String, before:Dictionary, after:Dictionary, recent_activity:String="", recent_memory:String="")->String:
	var label:Dictionary={"read":"reading","eat":"eating","drink":"having some water","sleep":"sleeping","take_shower":"taking a shower","use_toilet":"using the toilet","use_pc":"using the computer","watch_tv":"watching TV","clean":"tidying the room","look_out_window":"looking out the window","write_diary":"writing in my diary","call_friend":"trying to call someone","order_groceries":"ordering groceries","take_out_trash":"taking out the trash","wait":"taking a quiet pause"}
	var subject:=str(label.get(activity,activity))
	var text:="%s — Today I spent some time %s." % [time_text,subject]
	var changes:Array=[]
	for key in ["hunger","thirst","sleepiness","hygiene_need","toilet_need","boredom","loneliness","stress","discomfort"]:
		var delta:=float(after.get(key,before.get(key,0.0)))-float(before.get(key,0.0))
		if delta<=-8.0: changes.append("my %s eased" % key.replace("_need",""))
		elif delta>=8.0: changes.append("my %s rose" % key.replace("_need",""))
	if not changes.is_empty(): text += " It was noticeable that %s." % ", and ".join(changes.slice(0,2))
	if recent_activity!="" and recent_activity!=activity: text += " Recently I also %s." % str(label.get(recent_activity,recent_activity))
	if recent_memory!="": text += " I remembered: %s" % recent_memory
	return text.left(500)
