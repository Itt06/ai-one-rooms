class_name WorldClock
extends RefCounted

var total_minutes: float = 480.0
var paused := false

func advance(real_delta: float, speed: float) -> void:
	if not paused: total_minutes += real_delta * speed * 2.0

func snapshot() -> Dictionary:
	return {"day": int(total_minutes / 1440.0) + 1, "hour": int(fmod(total_minutes, 1440.0) / 60.0), "minute": int(fmod(total_minutes, 60.0))}

func text() -> String:
	var t := snapshot(); return "Day %d %02d:%02d" % [t.day, t.hour, t.minute]
