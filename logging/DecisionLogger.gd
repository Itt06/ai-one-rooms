class_name DecisionLogger
extends RefCounted

const LOG_PATH := "user://decision_log.jsonl"

static func append(entry: Dictionary) -> bool:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	return true
