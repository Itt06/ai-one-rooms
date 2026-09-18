class_name ObserverText
extends RefCounted

const NEEDS := {"hunger":"空腹","thirst":"のどの渇き","sleepiness":"眠気","hygiene_need":"清潔","toilet_need":"トイレ","boredom":"退屈","loneliness":"寂しさ","stress":"ストレス","discomfort":"不快感"}
const ACTIVITIES := {"read":"本を読んでいる","sleep":"寝ている","drink":"水を飲んでいる","eat":"食事をしている","use_pc":"PCを使っている","watch_tv":"テレビを見ている","clean":"部屋を片付けている","take_shower":"シャワーを浴びている","use_toilet":"トイレを使っている","write_diary":"日記を書いている","call_friend":"誰かに電話している","wait":"ぼんやりしている","look_out_window":"窓の外を眺めている"}
const PREFS := {"read":"読書","sleep":"睡眠","drink":"水分補給","eat":"食事","use_pc":"PCを使うこと","watch_tv":"テレビを見ること","clean":"片付け","wait":"ぼんやりすること"}

static func need_label(id:String)->String: return str(NEEDS.get(id,id))
static func activity_label(id:String)->String: return str(ACTIVITIES.get(id,id))
static func need_state(value:float)->String:
	if value>=85.0: return "かなり強い"
	if value>=60.0: return "少し気になる"
	return "落ち着いている"
static func object_label(id:String)->String:
	return {"bed":"ベッド","bookshelf":"本棚","book_01":"本","desk":"机","chair":"椅子","fridge":"冷蔵庫","sink":"シンク","pc":"PC","tv":"テレビ","window":"窓","trash_bin":"ゴミ箱","shower":"シャワー","toilet":"トイレ"}.get(id,id)
static func time_label(text:String, period:String)->String:
	return text.replace("Day ","").replace(" ","日 ")+"　"+{"morning":"朝","afternoon":"昼","evening":"夕方","night":"夜"}.get(period,period)
