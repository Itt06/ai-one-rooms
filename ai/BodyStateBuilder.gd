class_name BodyStateBuilder
extends RefCounted

static func descriptions(needs:ResidentNeeds)->Array:
	var result:Array=[]
	var entries:Array=[
		["hunger","You feel hungry.","You feel very hungry."],
		["thirst","You feel thirsty.","You feel extremely thirsty."],
		["sleepiness","Your body feels tired.","Your body feels heavy and extremely tired."],
		["hygiene_need","You feel less fresh and clean.","You feel very unclean."],
		["toilet_need","You feel some pressure to use the toilet.","You urgently need the toilet."],
		["boredom","You feel understimulated.","You feel very understimulated and restless."],
		["loneliness","You notice the absence of company.","You feel the absence of company strongly."],
		["stress","You feel somewhat tense.","You feel wound up and mentally tense."],
		["discomfort","You feel physically uncomfortable.","You feel severe physical discomfort."],
		["sexual_desire","You feel sexually aroused.","You feel intensely sexually aroused."]
	]
	for row in entries:
		var value:=float(needs.values.get(row[0],0.0))
		if value>=85.0:result.append(row[2])
		elif value>=55.0:result.append(row[1])
	return result

static func physical_constraints(needs:ResidentNeeds)->Array:
	var result:Array=[]
	var rows:Array=[
		["thirst",ActivityExecutor.CRITICAL_THIRST,"severe_thirst","You are extremely thirsty and cannot comfortably sustain long unrelated activity."],
		["toilet_need",ActivityExecutor.CRITICAL_TOILET,"urgent_toilet_need","You urgently need the toilet and cannot comfortably sustain long unrelated activity."],
		["sleepiness",ActivityExecutor.CRITICAL_SLEEPINESS,"extreme_fatigue","You are extremely sleepy and cannot comfortably sustain long unrelated activity."],
		["discomfort",ActivityExecutor.CRITICAL_DISCOMFORT,"severe_discomfort","You are in severe physical discomfort and cannot comfortably sustain long unrelated activity."]
	]
	for row in rows:
		if float(needs.values.get(row[0],0.0))>=float(row[1]):result.append({"condition":row[2],"severity":"critical","description":row[3]})
	return result
