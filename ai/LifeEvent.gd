class_name LifeEvent
extends RefCounted

static func activity_completed(time:String, activity:String, target:String, location:Vector2i, duration:float, before:Dictionary, after:Dictionary, context:Dictionary, result:String="completed") -> Dictionary:
	var delta:Dictionary={}
	for key in before:
		delta[key]=snapped(float(after.get(key,before[key]))-float(before[key]),0.01)
	return {"type":"activity_completed","time":time,"activity":activity,"target":target,"location":[location.x,location.y],"duration_minutes":duration,"before_needs":before.duplicate(true),"after_needs":after.duplicate(true),"need_delta":delta,"context":context.duplicate(true),"result":{"success":result=="completed","reason":result}}
