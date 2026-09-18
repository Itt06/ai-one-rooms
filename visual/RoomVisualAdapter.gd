class_name RoomVisualAdapter
extends RefCounted

const ORIGIN := Vector2(70,64)
const CELL_SIZE := 52.0
const ATLAS_PATH := "res://assets/visual_v21/dollhouse_furniture_sheet.png"

static func atlas_region(object_id:String)->Rect2:
	match object_id:
		"bed": return Rect2(35,285,390,325)
		"desk": return Rect2(410,285,315,270)
		"chair": return Rect2(715,300,190,265)
		"bookshelf": return Rect2(900,285,185,320)
		"pc": return Rect2(535,295,180,150)
		"tv": return Rect2(1090,300,360,245)
		"fridge": return Rect2(820,550,210,315)
		"sink": return Rect2(1080,550,230,260)
		"shower": return Rect2(1300,550,230,430)
		"toilet": return Rect2(1010,770,285,250)
		"trash_bin": return Rect2(50,800,230,210)
		"window": return Rect2(580,0,760,285)
	return Rect2()

static func cell_to_position(cell:Vector2i)->Vector2:
	return ORIGIN + Vector2(cell) * CELL_SIZE

static func position_to_cell(position:Vector2)->Vector2i:
	return Vector2i(round((position.x-ORIGIN.x)/CELL_SIZE),round((position.y-ORIGIN.y)/CELL_SIZE))
