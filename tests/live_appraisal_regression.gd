extends SceneTree

const TIMEOUT:=60.0
var scenarios:Array=["arousal_stress_solitude","arousal_lonely_relationship","high_boredom","high_stress","low_cash","dirty_room","tired_late_night","positive_social_memory"]
var totals:Dictionary={"requests":0,"accepted":0,"repairs":0,"recovered":0,"failures":0,"timeouts":0,"latency_total":0}

func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--scenario" and i+1<args.size():scenarios=str(args[i+1]).split(",")
	var probe:=HTTPRequest.new();root.add_child(probe);probe.timeout=5.0;await process_frame
	if probe.request("http://127.0.0.1:8000/v1/models")!=OK:print("Appraisal live test: SKIPPED - local server unavailable");quit(0);return
	var response=await probe.request_completed
	if response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]<200 or response[1]>=300:print("Appraisal live test: SKIPPED - local server unavailable");quit(0);return
	probe.queue_free()
	for i in scenarios.size():await _run_scenario(str(scenarios[i]),i)
	print("APPRAISAL SUMMARY")
	for key in totals:print("%s: %d"%[key,int(totals[key])])
	quit(0 if int(totals.timeouts)==0 else 1)

func _run_scenario(name:String,index:int)->void:
	var clock:=WorldClock.new();var needs:=ResidentNeeds.new();var room:=RoomState.new();var finance:=ResidentFinance.new();var relationships:=RelationshipStore.new();var memories:=MemoryStore.new()
	_configure(name,clock,needs,room,finance,relationships,memories)
	var life_context:={"finances":finance.snapshot(clock.total_minutes),"relationships":relationships.observation()}
	var facts:=ObservationBuilder.build_appraisal_facts(clock,needs,room,memories.retrieve([],[],6),[],{}, {},{},life_context)
	var harness:=ResidentAppraisalHarness.new();root.add_child(harness);await process_frame
	var state:={"done":false,"accepted":false,"mind":{},"repairs":0,"latency":0,"error":""}
	harness.repair_attempted.connect(func():state.repairs+=1;totals.repairs+=1)
	harness.repair_recovered.connect(func():totals.recovered+=1)
	harness.appraisal_ready.connect(func(mind,latency):state.done=true;state.accepted=true;state.mind=mind;state.latency=latency)
	harness.appraisal_failed.connect(func(error,latency):state.done=true;state.error=error;state.latency=latency)
	totals.requests+=1;print("[%d/%d] %s: requesting"%[index+1,scenarios.size(),name])
	harness.request_appraisal(_config(),FileAccess.get_file_as_string("res://ai/prompts/resident_appraisal_prompt.txt"),facts)
	var waited:=0.0
	while not bool(state.done) and waited<TIMEOUT:await create_timer(0.25).timeout;waited+=0.25
	if not bool(state.done):state.error="BENCHMARK_TIMEOUT";totals.timeouts+=1
	if bool(state.accepted):totals.accepted+=1
	else:totals.failures+=1
	totals.latency_total+=int(state.latency)
	print("Scenario: %s\naccepted: %s\nmood: %s\nwants: %s\nconcerns: %s\navoidances: %s\nsocial attitude: %s\nenergy attitude: %s\nrepair count: %d\nlatency_ms: %d\nerror: %s"%[name,state.accepted,str(state.mind.get("mood","")),JSON.stringify(state.mind.get("wants",[])),JSON.stringify(state.mind.get("concerns",[])),JSON.stringify(state.mind.get("avoidances",[])),str(state.mind.get("social_attitude","")),str(state.mind.get("energy_attitude","")),state.repairs,state.latency,state.error])
	if bool(state.accepted) and name in ["arousal_stress_solitude","arousal_lonely_relationship","high_boredom"]:await _follow_up(name,state.mind,clock,needs,room,finance,relationships)
	harness.queue_free();await process_frame

func _follow_up(name:String,mind:Dictionary,clock:WorldClock,needs:ResidentNeeds,room:RoomState,finance:ResidentFinance,relationships:RelationshipStore)->void:
	var resident:=ResidentState.new();var life_context:={"cash":finance.cash,"contact_targets":relationships.contacts.keys(),"accepted_partner_targets":[],"sexual_partner_options":relationships.sex_partner_candidates(finance.cash),"finances":finance.snapshot(clock.total_minutes),"relationships":relationships.observation(),"resident_mind":mind}
	var available:=PrimitiveToolCatalog.available(room,{"current_cell":resident.current_cell,"held_item_id":resident.held_item_id},life_context)
	var observation:=ObservationBuilder.build(clock,needs,room,resident.render_position,"idle",[],[],{},available,{}, {"cell":resident.current_cell,"posture":resident.posture,"held_item_id":resident.held_item_id},[],{},life_context)
	var harness:=ResidentHarness.new();root.add_child(harness);await process_frame
	var state:={"done":false,"accepted":false,"tools":[],"reason":"","error":""}
	harness.plan_ready.connect(func(plan,reason,_g,_l,_r):state.done=true;state.accepted=true;state.reason=reason;for step in plan:state.tools.append(str(step.get("tool",""))))
	harness.skill_ready.connect(func(id,reason,_g,_l,_r):state.done=true;state.accepted=true;state.reason=reason;state.tools=["skill:"+str(id)])
	harness.decision_failed.connect(func(error,_l,_r):state.done=true;state.error=error)
	harness.request_decision(observation,available,room,[],_config(),FileAccess.get_file_as_string("res://ai/prompts/resident_system_prompt.txt"),resident.snapshot(),needs.snapshot())
	var waited:=0.0;while not bool(state.done) and waited<TIMEOUT:await create_timer(0.25).timeout;waited+=0.25
	print("FOLLOW-UP %s: mind=%s tools=%s primary=%s reason=%s accepted=%s error=%s"%[name,str(mind.get("mood","")),JSON.stringify(state.tools),_primary(state.tools),state.reason,state.accepted,state.error])
	harness.queue_free();await process_frame

func _configure(name:String,clock:WorldClock,needs:ResidentNeeds,room:RoomState,finance:ResidentFinance,relationships:RelationshipStore,memories:MemoryStore)->void:
	if name in ["arousal_stress_solitude","arousal_lonely_relationship"]:needs.values.sexual_desire=95.0
	if name=="arousal_stress_solitude":needs.values.stress=85.0;needs.values.loneliness=15.0
	if name=="arousal_lonely_relationship":needs.values.stress=20.0;needs.values.loneliness=90.0;relationships.contacts.girlfriend_01.relationship=90;relationships.contacts.girlfriend_01.trust=90;relationships.contacts.girlfriend_01.availability=true
	if name=="high_boredom":needs.values.boredom=98.0;needs.values.sexual_desire=20.0;needs.values.loneliness=15.0;needs.values.stress=10.0
	if name=="high_stress":needs.values.stress=95.0;needs.values.boredom=15.0;needs.values.loneliness=15.0
	if name=="low_cash":finance.cash=100
	if name=="dirty_room":room.cleanliness=15.0;room.resources.trash=5;room.private_stains=2
	if name=="tired_late_night":clock.total_minutes=23.0*60.0;needs.values.sleepiness=92.0
	if name=="positive_social_memory":memories.add("Day 1 19:00","meet_contact","I recently spent a pleasant evening with my girlfriend and enjoyed her company.","completed",0.9,["girlfriend_01"],{"loneliness":-35.0})

func _primary(tools:Array)->String:
	for tool in tools:
		if ActivityCatalog.DEFINITIONS.has(str(tool)):return str(tool)
	return ""

func _config()->Dictionary:return {"base_url":"http://127.0.0.1:8000/v1","model":"Ornith-1.5-9B","temperature":0.3,"timeout_ms":30000,"max_tokens":256}
