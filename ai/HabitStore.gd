class_name HabitStore
extends RefCounted

const MAX_HABITS:=24
var habits:Array=[]

func record(event:Dictionary)->void:
	if not bool(event.get("result",{}).get("success",true)): return
	var activity:=str(event.get("activity","")); if activity=="": return
	var hour:=int(event.get("time_hour",event.get("context",{}).get("time_of_day",-1)))
	var period:="morning" if hour>=6 and hour<12 else ("afternoon" if hour<18 else ("evening" if hour<24 else "night"))
	var target:=str(event.get("target","")); var target_type:=target
	var key:=activity+"|"+period+"|"+target_type
	var row:=_find(key)
	if row.is_empty():
		row={"id":"habit_%s"%key.replace("|","_"),"activity":activity,"context":{"time_of_day":period,"target_type":target_type},"count":0,"confidence":0.0,"key":key}; habits.append(row)
	row.count=int(row.get("count",0))+1
	if row.count>=3: row.confidence=clamp(float(row.get("confidence",0.0))+0.08,0.0,1.0)
	if habits.size()>MAX_HABITS: habits.pop_front()

func summary()->Array:
	var out:Array=[]
	for row in habits:
		if float(row.get("confidence",0.0))>=0.16: out.append("often %s in the %s"%[row.get("activity",""),row.get("context",{}).get("time_of_day","")])
	return out.slice(0,min(6,out.size()))

func serialize()->Dictionary:return {"habits":habits.duplicate(true)}
func load_state(data)->void:
	habits=data.get("habits",[]).duplicate(true) if data is Dictionary and data.get("habits",[]) is Array else []
	if habits.size()>MAX_HABITS:habits.resize(MAX_HABITS)
func _find(key:String)->Dictionary:
	for row in habits:
		if str(row.get("key",""))==key:return row
	return {}
