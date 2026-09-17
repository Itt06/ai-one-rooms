extends SceneTree

var http:HTTPRequest
var scenarios=["relevant_memory","learned_preference","established_habit","relevant_skill","goal_vs_need","satiation","failed_call_friend_memory","neutral"]

func _initialize()->void:
	http=HTTPRequest.new(); root.add_child(http); await process_frame
	if not await _models(): print("Ornith live test: SKIPPED - local server unavailable"); quit(0); return
	for name in scenarios: await _run_scenario(name)
	quit(0)

func _models()->bool:
	if http.request("http://127.0.0.1:8000/v1/models")!=OK:return false
	var response=await http.request_completed
	return response[0]==HTTPRequest.RESULT_SUCCESS and response[1]>=200 and response[1]<300

func _run_scenario(name:String)->void:
	var room:=RoomState.new(); var resident:=ResidentState.new(); var needs:=ResidentNeeds.new(); var memory:=MemoryStore.new(); var prefs:=PreferenceStore.new(); var habits:=HabitStore.new(); var goals:=GoalStore.new(); var skills:=SkillStore.new()
	_configure(name,room,resident,needs,memory,prefs,habits,goals,skills)
	var available:=PrimitiveToolCatalog.available(room,{"current_cell":resident.current_cell,"held_item_id":resident.held_item_id}); var ids:Array=[]; for item in available:ids.append(str(item.get("tool","")))
	var observation:=ObservationBuilder.build(WorldClock.new(),needs,room,resident.render_position,"idle",memory.retrieve(ids,goals.active_texts(),6,"",[]),goals.active_texts(),prefs.summary(),[],{"habits":habits.summary()},{"cell":resident.current_cell,"posture":resident.posture,"held_item_id":resident.held_item_id},skills.relevant(room,resident.held_item_id,needs.values,resident),{"scenario":name})
	var harness:=ResidentHarness.new(); root.add_child(harness); var done:=false; var accepted:=false; var repairs:=0; var recovered:=0; var failure:=""
	harness.repair_attempted.connect(func(_kind):repairs+=1)
	harness.repair_recovered.connect(func():recovered+=1)
	harness.plan_ready.connect(func(_p,_r,_g,_l,_raw):accepted=true;done=true)
	harness.skill_ready.connect(func(_id,_r,_g,_l,_raw):accepted=true;done=true)
	harness.decision_failed.connect(func(error,_l,_raw):failure=error;done=true)
	harness.request_decision(observation,[],room,goals.active_texts(),{"base_url":"http://127.0.0.1:8000/v1","model":"Ornith-1.5-9B","temperature":0.3,"timeout_ms":30000,"max_tokens":256},FileAccess.get_file_as_string("res://ai/prompts/resident_system_prompt.txt"),resident.snapshot(),needs.snapshot())
	var waited:=0.0
	while not done and waited<45.0:await create_timer(0.25).timeout;waited+=0.25
	print("%s: final_accepted=%s repair_attempts=%d recovered=%d failure=%s"%[name,accepted,repairs,recovered,failure]); harness.queue_free(); await process_frame

func _configure(name:String,room:RoomState,resident:ResidentState,needs:ResidentNeeds,memory:MemoryStore,prefs:PreferenceStore,habits:HabitStore,goals:GoalStore,skills:SkillStore)->void:
	if name in ["relevant_memory","learned_preference","established_habit"]:resident.current_cell=room.objects.bookshelf.interaction_cells[0]
	if name=="relevant_memory":memory.add("Day 1 19:00","read","Reading helped me calm down.","completed",0.8,["book_01"],{"activity":"read","boredom":-20.0})
	if name=="learned_preference":for i in 5:prefs.record("read",0.04,19)
	if name=="established_habit":for i in 4:habits.record({"activity":"read","target":"bed","time_hour":20,"result":{"success":true}})
	if name=="relevant_skill":skills.skills.append({"id":"skill_read_book","name":"read_book","description":"Read a book","steps":[{"tool":"move_near","args":{"target_type":"bookshelf"}},{"tool":"pick_up","args":{"target_type":"book"}},{"tool":"read","args":{"target_type":"book"}}],"status":"active","offer_count":0,"times_used":0,"success_count":0,"failure_count":0})
	if name=="goal_vs_need":goals.apply({"add":["Spend quiet time"],"complete":[],"abandon":[]});needs.values["thirst"]=75.0
	if name=="satiation":prefs.record("read",0.1,20);resident.current_cell=room.objects.bookshelf.interaction_cells[0]
	if name=="failed_call_friend_memory":memory.add("Day 1 18:00","call_friend","Nobody answered.","no_answer",0.7,["phone"],{"loneliness":2.0})
