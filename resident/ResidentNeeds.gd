class_name ResidentNeeds
extends RefCounted

const RATES := {
	"hunger":0.10,
	"thirst":0.08,
	"sleepiness":0.08,
	"hygiene_need":0.04,
	"toilet_need":0.04,
	"boredom":0.05,
	"loneliness":0.015,
	"stress":0.01,
	# Discomfort is a slow accumulating consequence, not a guaranteed
	# multi-day death spiral. Critical thresholds remain authoritative.
	"discomfort":0.005
}

var values := {
	"hunger":28.0,
	"thirst":32.0,
	"sleepiness":20.0,
	"hygiene_need":22.0,
	"toilet_need":18.0,
	"boredom":38.0,
	"loneliness":18.0,
	"stress":12.0,
	"discomfort":8.0
}

func advance(minutes: float, suppressed_needs:Array=[] ) -> void:
	for key in RATES:
		if key in suppressed_needs: continue
		values[key] = clamp(float(values.get(key,0.0)) + float(RATES[key]) * minutes, 0.0, 100.0)
	if float(values.hunger) > 85.0:
		values.stress = min(100.0, float(values.stress) + minutes * 0.0005)
	if float(values.thirst) > 85.0:
		values.stress = min(100.0, float(values.stress) + minutes * 0.001)
	if float(values.sleepiness) > 90.0:
		values.discomfort = min(100.0, float(values.discomfort) + minutes * 0.0008)
	if float(values.hygiene_need) > 85.0:
		values.discomfort = min(100.0, float(values.discomfort) + minutes * 0.0005)
	if float(values.toilet_need) > 85.0:
		values.discomfort = min(100.0, float(values.discomfort) + minutes * 0.001)

func apply(effects: Dictionary) -> void:
	for key in effects:
		values[key] = clamp(float(values.get(key,0.0)) + float(effects[key]), 0.0, 100.0)

func snapshot()->Dictionary:
	return values.duplicate(true)

func load_snapshot(snapshot:Dictionary)->void:
	for key in values:
		if snapshot.has(key): values[key]=clamp(float(snapshot[key]),0.0,100.0)
