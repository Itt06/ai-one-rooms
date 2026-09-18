class_name WorldClock
extends RefCounted

var total_minutes: float = 480.0
var paused := false

func advance(real_delta: float, speed: float) -> void:
	if not paused: total_minutes += real_delta * speed * 2.0

func snapshot() -> Dictionary:
	var day_minutes:=fmod(total_minutes,1440.0)
	var hour:=int(day_minutes/60.0)
	var period:="night" if hour<6 else ("morning" if hour<12 else ("afternoon" if hour<18 else ("evening" if hour<22 else "night")))
	return {"day": int(total_minutes / 1440.0) + 1, "hour": hour, "minute": int(fmod(total_minutes, 60.0)), "period":period}

func text() -> String:
	var t := snapshot(); return "Day %d %02d:%02d" % [t.day, t.hour, t.minute]
