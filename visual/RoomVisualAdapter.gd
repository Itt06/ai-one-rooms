class_name RoomVisualAdapter
extends RefCounted

const ORIGIN := Vector2(70,70)
const CELL_SIZE := 60.0

static func cell_to_position(cell:Vector2i)->Vector2:
	return ORIGIN + Vector2(cell) * CELL_SIZE

static func position_to_cell(position:Vector2)->Vector2i:
	return Vector2i(round((position.x-ORIGIN.x)/CELL_SIZE),round((position.y-ORIGIN.y)/CELL_SIZE))
