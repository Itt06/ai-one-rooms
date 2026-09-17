class_name ResidentNeeds
extends RefCounted

const RATES := {"hunger":0.10,"thirst":0.16,"sleepiness":0.08,"hygiene_need":0.04,"boredom":0.05,"loneliness":0.015,"stress":0.01,"discomfort":0.02}
var values := {"hunger":28.0,"thirst":32.0,"sleepiness":20.0,"hygiene_need":22.0,"boredom":38.0,"loneliness":18.0,"stress":12.0,"discomfort":8.0}

func advance(minutes: float) -> void:
	for key in RATES: values[key] = clamp(values[key] + RATES[key] * minutes, 0.0, 100.0)
	if values.hunger > 85: values.stress = min(100.0, values.stress + minutes * 0.03)
	if values.thirst > 85: values.stress = min(100.0, values.stress + minutes * 0.06)
	if values.sleepiness > 90: values.discomfort = min(100.0, values.discomfort + minutes * 0.05)
	if values.hygiene_need > 85: values.discomfort = min(100.0, values.discomfort + minutes * 0.04)

func apply(effects: Dictionary) -> void:
	for key in effects: values[key] = clamp(values.get(key, 0.0) + float(effects[key]), 0.0, 100.0)
