class_name ObserverText
extends RefCounted

const NEEDS := {"hunger":"空腹","thirst":"のどの渇き","sleepiness":"眠気","hygiene_need":"清潔","toilet_need":"トイレ","boredom":"退屈","loneliness":"寂しさ","stress":"ストレス","discomfort":"不快感","sexual_desire":"性欲"}
const ACTIVITIES := {"read":"本を読んでいる","sleep":"寝ている","drink":"水を飲んでいる","eat":"食事をしている","use_pc":"PCを使っている","watch_tv":"テレビを見ている","clean":"部屋を片付けている","take_shower":"シャワーを浴びている","use_toilet":"トイレを使っている","write_diary":"日記を書いている","call_friend":"誰かに電話している","order_groceries":"食料を注文している","take_out_trash":"ゴミを捨てている","wait":"ぼんやりしている","look_out_window":"窓の外を眺めている","remote_work":"仕事をしている","masturbate":"性欲を解消している","message_contact":"連絡している","call_contact":"電話している","meet_contact":"相手と一緒に過ごしている","invite_for_sex":"親密な誘いをしている","sex":"パートナーと親密な時間を過ごしている"}
const PREFS := {"read":"読書","sleep":"睡眠","drink":"水分補給","eat":"食事","use_pc":"PCを使うこと","watch_tv":"テレビを見ること","clean":"片付け","take_shower":"シャワー","use_toilet":"トイレ","write_diary":"日記を書くこと","call_friend":"電話すること","look_out_window":"窓の外を見ること","order_groceries":"食料を注文すること","take_out_trash":"ゴミ出し","wait":"ぼんやりすること","remote_work":"仕事","masturbate":"一人の時間","message_contact":"連絡","call_contact":"電話","meet_contact":"会うこと","invite_for_sex":"親密な誘い","sex":"親密な時間"}

static func need_label(id:String)->String: return str(NEEDS.get(id,id))
static func activity_label(id:String)->String: return str(ACTIVITIES.get(id,id))
static func activity_noun(id:String)->String:
	return {"read":"読書","sleep":"睡眠","drink":"水分補給","eat":"食事","use_pc":"PC","watch_tv":"テレビ","clean":"片付け","take_shower":"シャワー","use_toilet":"トイレ","write_diary":"日記","call_friend":"電話","look_out_window":"窓の外を見ること","wait":"ひと休み"}.get(id,"行動")
static func activity_completed_label(id:String)->String:
	return {"read":"本を読み終えた","sleep":"眠りから起きた","drink":"水を飲んだ","eat":"食事を終えた","use_pc":"PCを使い終えた","watch_tv":"テレビを見終えた","clean":"部屋を片付けた","take_shower":"シャワーを浴びた","use_toilet":"トイレを済ませた","write_diary":"日記を書いた","call_friend":"電話を終えた","look_out_window":"窓の外を眺めた","wait":"ひと休みした","remote_work":"仕事を終えた","masturbate":"性欲を解消した","message_contact":"連絡を終えた","call_contact":"電話を終えた","meet_contact":"一緒に過ごした","invite_for_sex":"親密な誘いをした","sex":"パートナーと親密な時間を過ごした","order_groceries":"食料を注文した"}.get(id,"行動を終えた")
static func need_state(value:float)->String:
	if value>=85.0: return "かなり強い"
	if value>=60.0: return "少し気になる"
	return "落ち着いている"
static func resource_quality(value:int)->String:
	if value<=0: return "ない"
	if value<=2: return "ほとんどない"
	if value<=4: return "少ない"
	return "十分"
static func trash_quality(value:int)->String:
	if value<=0: return "なし"
	if value<=2: return "少ない"
	if value<=5: return "増えてきた"
	return "多い"
static func status_label(value:String)->String:
	return {"thinking":"考え中","moving":"移動中","acting":"行動中","idle":"休んでいる","starting":"始めようとしている","running":"行動中"}.get(value,value)
static func public_reason(value:String)->String:
	if value=="": return "住人が自分で選んだ行動です。"
	for character in value:
		if character.to_ascii_buffer().size()>0 and character.to_ascii_buffer()[0] >= 65 and character.to_ascii_buffer()[0] <= 122: return "住人が自分で選んだ行動です。"
	return value.left(120)
static func connection_label(value:String)->String:
	if value.to_lower().contains("offline"): return "AI 未接続"
	if value.to_lower().contains("connected"): return "AI 接続中"
	return value
static func habit_label(text:String)->String:
	var lower:=text.to_lower()
	var action:="read" if lower.contains("read") else ("use_pc" if lower.contains("use_pc") or lower.contains("computer") else ("sleep" if lower.contains("sleep") else ""))
	var period:="夜" if lower.contains("night") else ("夕方" if lower.contains("evening") else ("朝" if lower.contains("morning") else ""))
	if action!="": return "%sに%sことが多い" % [period, {"read":"本を読む","use_pc":"PCを使う","sleep":"寝る"}.get(action,"何かをする")] if period!="" else "%sことが多い" % {"read":"本を読む","use_pc":"PCを使う","sleep":"寝る"}.get(action,"何かをする")
	return "生活の傾向が少し見えてきた"
static func skill_label(skill:Dictionary)->String:
	var ids:=" ".join(Array(skill.get("steps",[])).map(func(step): return str(step.get("tool",""))))
	if ids.contains("pick_up") and ids.contains("read"): return "本棚から本を取って読む"
	if ids.contains("use_pc"): return "机に座ってPCを使う"
	return "身についた行動の組み合わせ"
static func object_label(id:String)->String:
	return {"bed":"ベッド","bookshelf":"本棚","book_01":"本","desk":"机","chair":"椅子","fridge":"冷蔵庫","sink":"シンク","pc":"PC","tv":"テレビ","window":"窓","trash_bin":"ゴミ箱","shower":"シャワー","toilet":"トイレ"}.get(id,id)
static func time_label(text:String, period:String)->String:
	return text.replace("Day ","").replace(" ","日目 ")+"　"+{"morning":"朝","afternoon":"昼","evening":"夕方","night":"夜"}.get(period,period)
