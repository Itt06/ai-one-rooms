class_name ObserverText
extends RefCounted

const NEED_LABELS={"hunger":"空腹","thirst":"のどの渇き","sleepiness":"眠気","hygiene_need":"清潔","toilet_need":"トイレ","boredom":"退屈","loneliness":"寂しさ","stress":"ストレス","discomfort":"不快感"}
const ACTIVITIES={"read":"本を読んでいる","sleep":"寝ている","drink":"水を飲んでいる","eat":"食事をしている","use_pc":"PCを使っている","watch_tv":"テレビを見ている","clean":"部屋を片付けている","take_shower":"シャワーを浴びている","use_toilet":"トイレを使っている","write_diary":"日記を書いている","call_friend":"誰かに電話している","order_groceries":"食料を注文している","take_out_trash":"ゴミを捨てに行っている","wait":"ぼんやりしている","look_out_window":"窓の外を眺めている"}
const PREFERENCE_NAMES={"read":"読書","sleep":"睡眠","drink":"水分補給","eat":"食事","use_pc":"PCを使うこと","watch_tv":"テレビを見ること","clean":"片付け","take_shower":"シャワー","use_toilet":"トイレ","write_diary":"日記","call_friend":"電話","look_out_window":"窓の外を眺めること","wait":"ぼんやりすること"}
const OBJECTS={"bed":"ベッド","desk":"机","chair":"椅子","fridge":"冷蔵庫","sink":"流し台","shower":"シャワー","toilet":"トイレ","bookshelf":"本棚","pc":"PC","phone":"電話","tv":"テレビ","window":"窓","trash_bin":"ゴミ箱","book_01":"本","food_stack":"食料"}

static func need_label(id:String)->String:return str(NEED_LABELS.get(id,id))
static func activity_label(id:String)->String:return str(ACTIVITIES.get(id,id))
static func period_label(id:String)->String:
	return {"morning":"朝","afternoon":"昼","evening":"夕方","night":"夜"}.get(id,id)
static func time_label(clock_text:String,period:String)->String:
	var parts:=clock_text.replace("Day ","").split(" ",false)
	return (parts[0]+"日 "+parts[1] if parts.size()>=2 else clock_text)+"　"+period_label(period)
static func object_label(id:String)->String:return str(OBJECTS.get(id,id))
static func need_state(value:float,threshold:float)->String:
	if value>=threshold:return "限界に近い"
	if value>=70.0:return "かなり気になる"
	if value>=40.0:return "少し気になる"
	return "落ち着いている"
static func status(value:String,activity:String="")->String:
	match value:
		"thinking":return "考え中"
		"moving":return "移動中"
		"acting":return activity_label(activity)
		"starting","running":return activity_label(activity)
		"idle":return "何をするか考えている"
	return value
static func connection(value:String)->String:
	if "Offline" in value:return "AI 未接続"
	if "Timeout" in value:return "AI タイムアウト"
	if "invalid" in value:return "AI 応答を確認中"
	if "Connected" in value:return "AI 接続中"
	return value
static func room_quality(value:float)->String:
	if value>=80.0:return "きれい"
	if value>=55.0:return "ふつう"
	return "少し散らかっている"
static func resource_quality(value:int,kind:String)->String:
	if kind=="trash":return "少ない" if value<=1 else ("少しある" if value<=3 else "多い")
	return "十分" if value>=4 else ("少なめ" if value>=1 else "ほとんどない")
static func preference_text(id:String,value:float)->String:
	var name:=str(PREFERENCE_NAMES.get(id,activity_label(id)))
	return "%sを好むようだ" % name if value>=0.1 else ("%sはあまり好まないようだ" % name if value<=-0.1 else "")
static func skill_text(skill:Dictionary)->String:
	var steps:Array=skill.get("steps",[]); var names:Array=[]
	for step in steps:
		var tool:=str(step.get("tool","")); var args:Dictionary=step.get("args",{}); var target:=object_label(str(args.get("target_type",args.get("target",""))))
		if tool=="move_near":continue
		if tool=="pick_up":names.append("%sから%sを取る" % [target,"本" if target=="本" else target])
		elif tool=="read":names.append("%sを読む" % target)
		else:names.append(activity_label(tool))
	return "、".join(names) if not names.is_empty() else "覚えたやり方"
