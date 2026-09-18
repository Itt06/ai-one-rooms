class_name ResidentVisualAdapter
extends RefCounted

const ATLAS_PATH := "res://assets/visual_v21/resident/resident_sheet.png"
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
