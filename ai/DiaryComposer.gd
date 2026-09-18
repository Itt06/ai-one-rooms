class_name DiaryComposer
extends RefCounted

static func compose(time_text:String, activity:String, before:Dictionary, after:Dictionary, recent_activity:String="", recent_memory:String="")->String:
	var label:Dictionary={"read":"本を読んでいる","eat":"食事をしている","drink":"水を飲んでいる","sleep":"寝ている","take_shower":"シャワーを浴びている","use_toilet":"トイレを使っている","use_pc":"PCを使っている","watch_tv":"テレビを見ている","clean":"部屋を片付けている","look_out_window":"窓の外を眺めている","write_diary":"日記を書いている","call_friend":"電話をしている","wait":"ぼんやりしている"}
	var subject:=str(label.get(activity,activity))
	var text:="%s、今日は%s。" % [time_text,subject]
	var changes:Array=[]
	for key in ["hunger","thirst","sleepiness","hygiene_need","toilet_need","boredom","loneliness","stress","discomfort"]:
		var delta:=float(after.get(key,before.get(key,0.0)))-float(before.get(key,0.0))
		if delta<=-8.0: changes.append("%sが少し落ち着いた" % ObserverText.need_label(key))
		elif delta>=8.0: changes.append("%sが強くなった" % ObserverText.need_label(key))
	if not changes.is_empty(): text += " %s。" % "、".join(changes.slice(0,2))
	if recent_activity!="" and recent_activity!=activity: text += " その前は%sだった。" % str(label.get(recent_activity,recent_activity))
	if recent_memory!="": text += " 関連する記憶：%s" % recent_memory
	return text.left(500)
