class_name ResidentVisualAdapter
extends RefCounted

const ATLAS_PATH := "res://assets/visual_v21/resident/resident_sheet.png"
const SUPPLEMENTAL_PATH := "res://assets/visual_v21/resident/resident_supplemental.png"
const COL := 307.5
const ROW := 319.5
const BOTTOM_COL := 246.0

static func region_for(activity:String, status:String, posture:String, frame:int)->Rect2:
	if activity=="sleep" or posture=="lying": return Rect2(COL, ROW*2.0, COL, ROW)
	if activity=="read": return Rect2(COL*2.0, ROW*2.0, COL, ROW)
	if activity=="use_pc": return Rect2(COL*3.0, ROW*2.0, COL, ROW)
	if activity=="watch_tv": return Rect2(0, ROW*3.0, BOTTOM_COL, 319)
	if activity=="eat": return Rect2(BOTTOM_COL,ROW*3.0,BOTTOM_COL,319)
	if activity=="drink": return Rect2(BOTTOM_COL*2.0,ROW*3.0,BOTTOM_COL,319)
	if activity=="write_diary": return Rect2(BOTTOM_COL*3.0,ROW*3.0,BOTTOM_COL,319)
	if activity=="call_friend": return Rect2(BOTTOM_COL*4.0,ROW*3.0,BOTTOM_COL,319)
	if activity=="clean": return Rect2(0, ROW, COL, ROW)
	if posture=="sitting": return Rect2(0, ROW*2.0, COL, ROW)
	if status=="moving": return Rect2(COL* (2 if frame%2==0 else 3), ROW, COL, ROW)
	return Rect2(0,0,COL,ROW)

static func uses_supplemental(activity:String)->bool:
	return activity in ["look_out_window","take_shower","use_toilet","clean","take_out_trash","order_groceries","wait"]

static func supplemental_region(activity:String)->Rect2:
	const W:=443.5
	const H:=443.5
	var index:int=int({"look_out_window":0,"take_shower":1,"use_toilet":2,"clean":3,"take_out_trash":4,"order_groceries":5,"wait":6}.get(activity,6))
	return Rect2(float(index%4)*W,float(index/4)*H,W,H)

static func offset_for(activity:String)->Vector2:
	if activity=="sleep": return Vector2(0,10)
	if activity in ["read","use_pc","watch_tv","write_diary"]: return Vector2(0,8)
	return Vector2(0,0)

static func held_prop(item_id:String, activity:String)->String:
	if item_id!="": return "本" if item_id.contains("book") else "持ち物"
	if activity=="read": return "本"
	if activity=="eat": return "食器"
	if activity=="drink": return "カップ"
	return ""
