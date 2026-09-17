class_name ActivityExecutor
extends RefCounted

enum State { IDLE, STARTING, RUNNING, COMPLETED, FAILED, INTERRUPTED }
var state:State=State.IDLE
var activity_id:=""
var target_id:=""
var reason:=""
var remaining_minutes:=0.0
var before_needs:Dictionary={}
var started_cell:=Vector2i(0,0)

func begin(id:String,target:String,why:String,room:RoomState,needs:ResidentNeeds,resident:ResidentState)->Dictionary:
	reset()
	var definition:=ActivityCatalog.get_definition(id)
	if definition.is_empty(): state=State.FAILED; return {"ok":false,"error":"unknown_activity"}
	if definition.target_kind=="none":
		if target!="": state=State.FAILED; return {"ok":false,"error":"target_not_allowed"}
	elif not room.objects.has(target) and not room.items.has(target):
		state=State.FAILED; return {"ok":false,"error":"target_not_found"}
	if definition.has("target_type"):
		var target_data:Dictionary=room.objects.get(target,room.items.get(target,{}))
		if str(target_data.get("type",""))!=str(definition.target_type): state=State.FAILED; return {"ok":false,"error":"target_type_mismatch"}
	if definition.target_kind=="object" and not InteractionResolver.is_at_interaction_cell(room,target,resident.current_cell): state=State.FAILED; return {"ok":false,"error":"target_not_interactable_now"}
	if id in ["use_pc","watch_tv","order_groceries"] and target in ["pc","tv"] and not bool(room.objects[target].get("state",false)): state=State.FAILED; return {"ok":false,"error":"target_is_off"}
	if id=="drink" and target=="fridge" and not bool(room.objects[target].get("state",false)): state=State.FAILED; return {"ok":false,"error":"fridge_closed"}
	activity_id=id; target_id=target; reason=why; remaining_minutes=float(definition.duration_minutes); before_needs=needs.values.duplicate(true); started_cell=resident.current_cell; state=State.STARTING
	return {"ok":true,"state":"starting","activity":id,"target":target}

func update(elapsed_minutes:float)->Dictionary:
	if state==State.STARTING: state=State.RUNNING
	if state==State.RUNNING:
		remaining_minutes=max(0.0,remaining_minutes-elapsed_minutes)
		if remaining_minutes<=0.0: state=State.COMPLETED
	return {"state":state_name(),"completed":state==State.COMPLETED}

func complete(room:RoomState,needs:ResidentNeeds,resident:ResidentState,diary_text:String="")->Dictionary:
	if state!=State.COMPLETED:return {"ok":false,"error":"activity_not_completed"}
	var definition:=ActivityCatalog.get_definition(activity_id); var effects:Dictionary=definition.get("effects",{}); needs.apply(effects)
	for key in definition.get("resource_effect",{}):
		if key=="simple_food": room.add_item_quantity("simple_food",int(definition.resource_effect[key]),"fridge")
		elif key=="water" and target_id=="sink": pass
		else: room.resources[key]=max(0,int(room.resources.get(key,0))+int(definition.resource_effect[key]))
	if bool(definition.get("consumes_item",false)):
		room.consume_item(target_id)
		if int(room.items.get(target_id,{}).get("quantity",0))<=0: resident.held_item_id=""
	if activity_id=="clean": room.cleanliness=min(100.0,room.cleanliness+20.0)
	if activity_id=="take_out_trash": room.resources["trash"]=0
	if activity_id=="eat": room.resources["trash"]=int(room.resources.get("trash",0))+1
	if activity_id=="order_groceries": room.resources["trash"]=int(room.resources.get("trash",0))+1
	var result:Dictionary={"ok":true,"activity":activity_id,"target":target_id,"duration_minutes":float(definition.duration_minutes),"before_needs":before_needs,"after_needs":needs.values.duplicate(true),"result":"completed","location":[started_cell.x,started_cell.y]}
	if activity_id=="write_diary": result["diary_text"]=diary_text
	reset()
	return result

func start(id:String,target:String,why:String,room:RoomState,needs:ResidentNeeds,resident:ResidentState)->Dictionary:
	return begin(id,target,why,room,needs,resident)

func interrupt(why:String)->Dictionary:
	if state not in [State.STARTING,State.RUNNING]: return {"ok":false,"error":"activity_not_running"}
	state=State.INTERRUPTED
	return {"ok":true,"activity":activity_id,"target":target_id,"result":"interrupted","reason":why}

func reset()->void:
	state=State.IDLE; activity_id=""; target_id=""; reason=""; remaining_minutes=0.0; before_needs={}

func is_active()->bool:return state in [State.STARTING,State.RUNNING]
func state_name()->String:
	match state:
		State.IDLE:return "idle"
		State.STARTING:return "starting"
		State.RUNNING:return "running"
		State.COMPLETED:return "completed"
		State.FAILED:return "failed"
		State.INTERRUPTED:return "interrupted"
	return "unknown"
