extends SceneTree

const TIMEOUT := 60.0
const CONFIG := {"base_url":"http://127.0.0.1:8000/v1","model":"Ornith-1.5-9B","temperature":0.3,"timeout_ms":30000,"max_tokens":256}
var names := ["aroused_solitude","lonely_closeness","lonely_meet","stressed_tv","financial_work","messy_clean","declined_invite"]

func _initialize() -> void:
	var probe := HTTPRequest.new(); root.add_child(probe); probe.timeout = 5.0; await process_frame
	if probe.request("http://127.0.0.1:8000/v1/models") != OK:
		print("Experience appraisal live test: SKIPPED - local server unavailable"); quit(0); return
	var response = await probe.request_completed
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] < 200 or response[1] >= 300:
		print("Experience appraisal live test: SKIPPED - local server unavailable"); quit(0); return
	for i in names.size(): await _run(str(names[i]), i)
	print("Experience appraisal live regression complete: %d/%d scenarios terminated" % [names.size(), names.size()]); quit(0)

func _run(name:String, index:int) -> void:
	var clock := WorldClock.new(); var needs := ResidentNeeds.new(); var room := RoomState.new(); var finance := ResidentFinance.new(); var relationships := RelationshipStore.new(); var memories := MemoryStore.new(); var mind := ResidentMindState.new()
	var activity := "masturbate"; var objective := {"result":"completed","need_effects":{}}
	match name:
		"aroused_solitude": needs.values.sexual_desire = 95.0; needs.values.stress = 70.0; needs.values.loneliness = 20.0
		"lonely_closeness": needs.values.sexual_desire = 95.0; needs.values.loneliness = 90.0; activity = "masturbate"; mind.social_attitude = "seeking closeness"
		"lonely_meet": needs.values.loneliness = 90.0; activity = "meet_contact"; mind.wants = ["company"]
		"stressed_tv": needs.values.stress = 90.0; activity = "watch_tv"; mind.concerns = ["unwinding"]
		"financial_work": finance.cash = 100.0; activity = "remote_work"; mind.concerns = ["financial security"]
		"messy_clean": room.cleanliness = 15.0; activity = "clean"; mind.concerns = ["order"]
		"declined_invite": activity = "invite_for_sex"; objective = {"result":"declined","need_effects":{}}
	var facts := {"resident_mind_before":mind.snapshot(),"activity":activity,"target":"","objective_result":objective,"objective_changes":{},"body_before":needs.snapshot(),"body_after":needs.snapshot(),"relationship_result":relationships.observation(),"financial_context":finance.snapshot(clock.total_minutes),"relevant_memory":memories.retrieve([],[],6)}
	var harness := ExperienceAppraisalHarness.new(); root.add_child(harness); await process_frame
	var state := {"done":false,"accepted":false,"result":{},"error":"","repairs":0,"latency":0}
	harness.repair_attempted.connect(func(): state.repairs += 1; print("[%d/%d] %s: repair" % [index+1,names.size(),name]))
	harness.appraisal_ready.connect(func(result, latency): state.done=true; state.accepted=true; state.result=result; state.latency=latency)
	harness.appraisal_failed.connect(func(error, latency): state.done=true; state.error=error; state.latency=latency)
	print("[%d/%d] %s: requesting activity=%s" % [index+1,names.size(),name,activity]); harness.request_appraisal(CONFIG, FileAccess.get_file_as_string("res://ai/prompts/resident_experience_prompt.txt"), facts)
	var waited := 0.0
	while not bool(state.done) and waited < TIMEOUT: await create_timer(0.25).timeout; waited += 0.25
	if not bool(state.done): state.error = "BENCHMARK_TIMEOUT"
	print("Scenario: %s\nactivity: %s\nobjective: %s\naccepted: %s\nfelt_result: %s\nemotional_tone: %s\nsatisfaction: %s\nsurprise: %s\nmeaning: %s\nfuture_inclination: %s\nrepair_count: %d\nlatency_ms: %d\nerror: %s" % [name,activity,JSON.stringify(objective),state.accepted,str(state.result.get("felt_result","")),str(state.result.get("emotional_tone","")),str(state.result.get("satisfaction","")),str(state.result.get("surprise","")),str(state.result.get("meaning","")),str(state.result.get("future_inclination","")),state.repairs,state.latency,state.error])
	harness.queue_free(); await process_frame
