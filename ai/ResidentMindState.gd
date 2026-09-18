class_name ResidentMindState
extends RefCounted

const LIST_FIELDS:= ["wants","concerns","avoidances","short_term_intentions"]
const TEXT_FIELDS:= ["mood","social_attitude","energy_attitude"]

var mood:="neutral"
var wants:Array=[]
var concerns:Array=[]
var avoidances:Array=[]
var short_term_intentions:Array=[]
var social_attitude:="neutral"
var energy_attitude:="ordinary"
var updated_at_minutes:=0.0
var source_revision:=0

func snapshot()->Dictionary:
	return {"mood":mood,"wants":wants.duplicate(),"concerns":concerns.duplicate(),"avoidances":avoidances.duplicate(),"short_term_intentions":short_term_intentions.duplicate(),"social_attitude":social_attitude,"energy_attitude":energy_attitude}

func serialize()->Dictionary:
	var data:=snapshot(); data["updated_at_minutes"]=updated_at_minutes; data["source_revision"]=source_revision; return data

func load_state(data)->bool:
	var checked:=validate(data)
	if not bool(checked.get("ok",false)):return false
	mood=str(data.mood); wants=data.wants.duplicate(); concerns=data.concerns.duplicate(); avoidances=data.avoidances.duplicate(); short_term_intentions=data.short_term_intentions.duplicate()
	social_attitude=str(data.social_attitude); energy_attitude=str(data.energy_attitude); updated_at_minutes=float(data.get("updated_at_minutes",0.0)); source_revision=int(data.get("source_revision",0)); return true

static func neutral()->Dictionary:
	return {"mood":"neutral","wants":[],"concerns":[],"avoidances":[],"short_term_intentions":[],"social_attitude":"neutral","energy_attitude":"ordinary"}

static func validate(data)->Dictionary:
	if not data is Dictionary:return {"ok":false,"error":"mind_not_object"}
	for field in TEXT_FIELDS:
		if not data.has(field) or not data[field] is String or str(data[field]).strip_edges()=="" or str(data[field]).length()>120:return {"ok":false,"error":"invalid_%s"%field}
	for field in LIST_FIELDS:
		if not data.has(field) or not data[field] is Array or data[field].size()>3:return {"ok":false,"error":"invalid_%s"%field}
		for item in data[field]:
			if not item is String or str(item).strip_edges()=="" or str(item).length()>140:return {"ok":false,"error":"invalid_%s_item"%field}
			if _contains_action_id(str(item)):return {"ok":false,"error":"action_reference_in_%s"%field}
	return {"ok":true}

static func _contains_action_id(text:String)->bool:
	var lower:=text.to_lower()
	var forbidden:Array=["move_to","move_near","pick_up","turn_on","lie_down","use_pc","watch_tv","remote_work","order_groceries","message_contact","call_contact","meet_contact","invite_for_sex","take_out_trash","write_diary"]
	for id in forbidden:
		if str(id) in lower:return true
	return false
