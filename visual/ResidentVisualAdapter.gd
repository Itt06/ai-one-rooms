class_name ResidentVisualAdapter
extends RefCounted

const ATLAS_PATH := "res://assets/visual_v21/resident/resident_sheet.png"
const CELL := 384.0

static func region_for(activity:String, status:String, posture:String, frame:int)->Rect2:
	if activity=="sleep" or posture=="lying": return Rect2(CELL, CELL*2.0, CELL, CELL)
	if activity=="read": return Rect2(CELL*2.0, CELL*2.0, CELL, CELL)
	if activity=="use_pc": return Rect2(CELL*3.0, CELL*2.0, CELL, CELL)
	if activity=="watch_tv": return Rect2(CELL, 0, CELL, CELL)
	if activity=="eat": return Rect2(0,CELL*3.0,CELL,CELL)
	if activity=="drink": return Rect2(CELL,CELL*3.0,CELL,CELL)
	if activity=="write_diary": return Rect2(CELL*2.0,CELL*3.0,CELL,CELL)
	if activity=="call_friend": return Rect2(CELL*3.0,CELL*3.0,CELL,CELL)
	if activity=="clean": return Rect2(0, CELL, CELL, CELL)
	if posture=="sitting": return Rect2(0, CELL*2.0, CELL, CELL)
	if status=="moving": return Rect2(CELL* (2 if frame%2==0 else 3), CELL, CELL, CELL)
	return Rect2(0,0,CELL,CELL)

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
