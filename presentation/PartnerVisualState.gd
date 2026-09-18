class_name PartnerVisualState
extends RefCounted

enum Phase { HIDDEN, ENTERING, APPROACHING, WAITING, AT_BED, INTIMATE, LEAVING }

const ENTRANCE := Vector2(835,500)
const VISIT_TARGET := Vector2(520,470)
const BED_TARGET := Vector2(235,430)
var phase:Phase=Phase.HIDDEN
var contact_id:=""
var relation_type:=""
var position:=ENTRANCE
var target_position:=VISIT_TARGET
var speed:=180.0
var visual_variant:="default"

func begin_visit(contact:Dictionary, activity:String, resident_position:Vector2)->bool:
	if contact.is_empty() or not bool(contact.get("adult",false)): return false
	if activity=="sex" and str(contact.get("relation_type",""))=="family": return false
	contact_id=str(contact.get("id","")); relation_type=str(contact.get("relation_type","")); visual_variant=_variant_for(relation_type)
	position=ENTRANCE; target_position=BED_TARGET if activity=="sex" else resident_position; phase=Phase.ENTERING
	return true

func update(delta:float, activity:String, resident_position:Vector2)->void:
	if phase==Phase.HIDDEN:return
	if phase==Phase.ENTERING: target_position=VISIT_TARGET; phase=Phase.APPROACHING
	if phase in [Phase.APPROACHING,Phase.LEAVING]:
		var destination:=ENTRANCE if phase==Phase.LEAVING else target_position
		position=position.move_toward(destination,speed*delta)
		if position.distance_to(destination)<2.0:
			if phase==Phase.LEAVING: reset()
			elif activity=="sex": target_position=BED_TARGET; phase=Phase.AT_BED
			else: phase=Phase.WAITING
	elif phase==Phase.AT_BED and activity=="sex":
		if position.distance_to(BED_TARGET)>2.0: position=position.move_toward(BED_TARGET,speed*delta)
		else: phase=Phase.INTIMATE

func end_visit()->void:
	if phase!=Phase.HIDDEN: phase=Phase.LEAVING; target_position=ENTRANCE

func reset()->void:
	phase=Phase.HIDDEN; contact_id=""; relation_type=""; position=ENTRANCE; target_position=ENTRANCE; visual_variant="default"

func phase_name()->String:
	return ["HIDDEN","ENTERING","APPROACHING","WAITING","AT_BED","INTIMATE","LEAVING"][int(phase)]

static func _variant_for(kind:String)->String:
	return {"girlfriend":"warm","dating_match":"light","casual_partner":"casual","sex_worker":"neutral","friend":"friend","family":"family"}.get(kind,"default")
