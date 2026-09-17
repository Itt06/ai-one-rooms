extends SceneTree

var failures := 0

func _initialize() -> void:
	_test_needs()
	_test_candidates_and_validation()
	_test_action_executor()
	_test_memory_and_goals()
	_test_grid_and_primitives()
	_test_skill_learning()
	_test_decision_schema()
	_test_object_manipulation()
	_test_unified_life_loop()
	_test_affordances_and_reachability()
	_test_save_round_trip_and_migration()
	_test_harness_authoritative_snapshot()
	_test_v11_life_loop()
	_test_timed_activity_lifecycle()
	_test_skill_production_path()
	_test_multiday_world_dynamics()
	if failures == 0:
		print("ai-one-rooms tests: PASS")
		quit(0)
	else:
		push_error("ai-one-rooms tests: %d failure(s)" % failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_needs() -> void:
	var needs := ResidentNeeds.new()
	var hunger_before := float(needs.values.get("hunger",0.0))
	var toilet_before := float(needs.values.get("toilet_need",0.0))
	needs.advance(10.0)
	_check(float(needs.values.get("hunger",0.0)) > hunger_before, "hunger should increase with time")
	_check(float(needs.values.get("toilet_need",0.0)) > toilet_before, "toilet need should increase with time")
	needs.apply({"hunger":-999.0})
	_check(float(needs.values.get("hunger",0.0)) == 0.0, "needs should clamp at zero")

func _test_candidates_and_validation() -> void:
	var room := RoomState.new()
	var candidates := ActionCatalog.candidates(room)
	var valid := ActionValidator.validate({"action":{"id":"eat_food","target":"fridge"},"reason":"Hungry.","goal_updates":{"add":[],"complete":[],"abandon":[]}},candidates,room,[])
	_check(bool(valid.get("ok",false)), "eat_food should validate while food exists")
	var sink_water := ActionValidator.validate({"action":{"id":"drink_water","target":"sink"},"reason":"Thirsty.","goal_updates":{"add":[],"complete":[],"abandon":[]}},candidates,room,[])
	_check(bool(sink_water.get("ok",false)), "sink should be a valid water target")
	room.items["food_stack"]["quantity"] = 0
	room.resources["water"] = 0
	candidates = ActionCatalog.candidates(room)
	var invalid_food := ActionValidator.validate({"action":{"id":"eat_food","target":"fridge"},"reason":"Hungry.","goal_updates":{"add":[],"complete":[],"abandon":[]}},candidates,room,[])
	_check(not bool(invalid_food.get("ok",false)), "eat_food should be rejected when food is unavailable")
	var sink_without_bottles := ActionValidator.validate({"action":{"id":"drink_water","target":"sink"},"reason":"Thirsty.","goal_updates":{"add":[],"complete":[],"abandon":[]}},candidates,room,[])
	_check(bool(sink_without_bottles.get("ok",false)), "sink water should remain available without bottled water")
	var invented := ActionValidator.validate({"action":{"id":"teleport","target":"bed"},"reason":"","goal_updates":{"add":[],"complete":[],"abandon":[]}},candidates,room,[])
	_check(not bool(invented.get("ok",false)), "invented actions must be rejected")
	var has_grocery_option := false
	for candidate in candidates:
		if str(candidate.get("id","")) == "order_groceries": has_grocery_option = true
	_check(has_grocery_option, "grocery ordering should appear when food is low")

func _test_action_executor() -> void:
	var room := RoomState.new()
	var needs := ResidentNeeds.new()
	var resident := ResidentState.new()
	var executor := ActivityExecutor.new()
	resident.held_item_id = "food_stack"
	room.items["food_stack"].location = "held"
	var started := executor.begin("eat","food_stack","I am hungry.",room,needs,resident)
	_check(bool(started.get("ok",false)), "activity should queue")
	var update := executor.update(20.0)
	_check(bool(update.get("completed",false)), "activity should complete after duration")
	var food_before := int(room.items["food_stack"].get("quantity",0))
	var hunger_before := float(needs.values.get("hunger",0.0))
	var result := executor.complete(room,needs,resident)
	_check(bool(result.get("ok",false)), "completed action effects should apply")
	_check(int(room.items["food_stack"].get("quantity",0)) == food_before - 1, "food should be consumed")
	_check(float(needs.values.get("hunger",0.0)) < hunger_before, "eating should reduce hunger")
	var sink_executor := ActivityExecutor.new()
	var sink_pos: Vector2 = room.objects["sink"].interaction_point
	var water_before := int(room.resources.get("water",0))
	sink_executor.begin("drink","sink","I am thirsty.",room,needs,resident)
	sink_executor.update(20.0)
	sink_executor.complete(room,needs,resident)
	_check(int(room.resources.get("water",0)) == water_before, "tap water should not consume bottled water")

func _test_memory_and_goals() -> void:
	var memory := MemoryStore.new()
	memory.add("Day 1 09:00","use_pc","I stayed on the computer and felt tired.","completed",0.8,["pc"],{"sleepiness":80})
	memory.add("Day 1 10:00","read_book","Reading was calming.","completed",0.6,["bookshelf"],{"stress":50})
	var retrieved := memory.retrieve(["use_pc"],[],1,"pc",["sleepiness"])
	_check(retrieved.size() == 1 and str(retrieved[0].get("related_action","")) == "use_pc", "memory retrieval should prefer relevant episodes")
	var goals := GoalStore.new()
	goals.apply({"add":["Finish the book"],"complete":[],"abandon":[]})
	_check("Finish the book" in goals.active_texts(), "goal should be active after add")
	goals.apply({"add":[],"complete":["Finish the book"],"abandon":[]})
	_check(not ("Finish the book" in goals.active_texts()), "completed goal should leave active set")

func _test_grid_and_primitives() -> void:
	var grid:=RoomGrid.new(); var room:=RoomState.new(); var resident:=ResidentState.new()
	_check(grid.is_inside(Vector2i(0,0)) and not grid.is_inside(Vector2i(-1,0)), "grid bounds should be enforced")
	var path:=grid.find_path(resident.current_cell,Vector2i(6,4),room.blocked_cells())
	_check(not path.is_empty(), "walkable destination should have a path")
	var invalid:=PrimitiveToolValidator.validate({"tool":"move_to","args":{"x":-1,"y":999}},room,grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(not bool(invalid.get("ok",false)), "invalid move_to should be rejected")
	var plan:=PlanExecutor.new(); plan.begin([{"tool":"wait"}],"I want to pause.")
	_check(plan.active and plan.current().get("tool","")=="wait", "plan should expose one current step")
	_check(plan.advance({"ok":true}), "single-step plan should complete")
	var canonical:=PrimitiveToolValidator.validate({"tool":"move_to","args":{"x":6,"y":4}},room,grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(bool(canonical.get("ok",false)), "canonical move_to should validate")
	var legacy:=PrimitiveToolValidator.validate({"action":"move_to","target":"center","args":[6,4]},room,grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(not bool(legacy.get("ok",false)), "legacy primitive shape should be rejected")

func _test_skill_learning() -> void:
	var room:=RoomState.new(); var history:=PlanHistory.new()
	var steps:=[{"tool":"move_near","args":{"target":"bookshelf"}},{"tool":"pick_up","args":{"target":"book_01"}},{"tool":"read","args":{"target":"book_01"}}]
	for i in 3: history.add("p%d"%i,"read",steps,[],true,"t","t")
	var store:=SkillStore.new(); store.learn(history.entries,room)
	_check(store.skills.size()==1, "three repeated successful plans should create a skill")
	var expanded:=SkillExecutor.expand(store.skills[0],room)
	_check(expanded.size()==3 and expanded[1].args.target=="book_01", "skill targets should resolve to current instances")

func _test_decision_schema() -> void:
	var valid_plan={"decision_type":"plan","reason":"move","plan":[{"tool":"wait","args":{}}],"goal_updates":{"add":[],"complete":[],"abandon":[]}}
	_check(bool(DecisionSchema.validate(valid_plan).get("ok",false)), "valid plan decision should pass")
	var valid_skill={"decision_type":"skill","reason":"read","skill":{"id":"skill_read_in_bed","args":{}},"goal_updates":{"add":[],"complete":[],"abandon":[]}}
	_check(bool(DecisionSchema.validate(valid_skill).get("ok",false)), "valid skill decision should pass")
	_check(not bool(DecisionSchema.validate(valid_plan.merged({"skill":null})).get("ok",false)), "plan plus null skill should fail")
	_check(not bool(DecisionSchema.validate({"tool":"wait","args":{}}).get("ok",false)), "missing decision type should fail")
	_check(not bool(DecisionSchema.validate({"decision_type":"plan","reason":"x","plan":[{"tool":"wait","args":[]}],"goal_updates":{"add":[],"complete":[],"abandon":[]}}).get("ok",false)), "array args should fail")

func _test_object_manipulation() -> void:
	var room:=RoomState.new(); var needs:=ResidentNeeds.new(); var resident:=ResidentState.new(); resident.current_cell=room.objects.bookshelf.interaction_cells[0]
	var pick:=PrimitiveToolValidator.validate({"tool":"pick_up","args":{"target":"book_01"}},room,room.grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(bool(pick.get("ok",false)), "near book pickup should validate")
	PrimitiveToolExecutor.execute({"tool":"pick_up","args":{"target":"book_01"}},room,resident,needs)
	_check(resident.held_item_id=="book_01" and room.items.book_01.location=="held", "pickup should update held state")
	var drop:=PrimitiveToolValidator.validate({"tool":"put_down","args":{"target":"book_01","x":4,"y":4}},room,room.grid,{"current_cell":resident.current_cell,"held_item_id":"book_01"},room.items)
	_check(bool(drop.get("ok",false)), "valid drop should validate")
	PrimitiveToolExecutor.execute({"tool":"put_down","args":{"target":"book_01","x":4,"y":4}},room,resident,needs)
	_check(resident.held_item_id=="" and room.items.book_01.grid_cell==Vector2i(4,4), "drop should update item location")
	var moved:=room.move_object("chair",Vector2i(5,1),0); _check(bool(moved.get("ok",false)), "movable chair should move")
	_check(room.objects.chair.origin_cell==Vector2i(5,1), "chair placement should change")
	var rotated:=room.rotate_object("chair",90); _check(bool(rotated.get("ok",false)), "chair should rotate")

func _test_unified_life_loop() -> void:
	var room:=RoomState.new(); var resident:=ResidentState.new(); var needs:=ResidentNeeds.new()
	var plan:=[{"tool":"move_near","args":{"target":"bookshelf"}},{"tool":"pick_up","args":{"target":"book_01"}},{"tool":"move_near","args":{"target":"bed"}},{"tool":"sit","args":{"target":"bed"}},{"tool":"read","args":{"target":"book_01"}}]
	var preflight:=PlanPreflight.validate(plan,room,ResidentState.new(),ResidentNeeds.new())
	_check(bool(preflight.get("ok",false)), "preflight should accept a reachable read plan")
	resident.current_cell=room.objects.bookshelf.interaction_cells[0]
	PrimitiveToolExecutor.execute({"tool":"pick_up","args":{"target":"book_01"}},room,resident,needs)
	var activity:=ActivityExecutor.new(); var started:=activity.begin("read","book_01","I want to read.",room,needs,resident)
	_check(bool(started.get("ok",false)), "read activity should start")
	_check(not bool(activity.update(29.0).get("completed",false)), "read should still be running before duration")
	_check(bool(activity.update(1.0).get("completed",false)), "read should complete at duration")
	var boredom_before:=float(needs.values.boredom); var result:=activity.complete(room,needs,resident)
	_check(bool(result.get("ok",false)) and float(needs.values.boredom)<boredom_before, "read result should apply authoritative effects")
	var wait:=ActivityExecutor.new(); wait.begin("wait","","I will pause.",room,needs,resident)
	_check(not bool(wait.update(9.0).get("completed",false)), "wait should consume time")
	_check(bool(wait.update(1.0).get("completed",false)), "wait should complete after ten minutes")

func _test_affordances_and_reachability() -> void:
	var room:=RoomState.new(); var resident:=ResidentState.new(); resident.current_cell=Vector2i(0,0)
	var far_data={"current_cell":resident.current_cell,"held_item_id":""}
	for probe in [
		{"tool":"pick_up","args":{"target":"book_01"}},
		{"tool":"sit","args":{"target":"chair"}},
		{"tool":"lie_down","args":{"target":"bed"}},
		{"tool":"open","args":{"target":"fridge"}},
		{"tool":"move_object","args":{"target":"chair","x":5,"y":1}}
	]:
		var rejected:=PrimitiveToolValidator.validate(probe,room,room.grid,far_data,room.items)
		_check(not bool(rejected.get("ok",false)), "remote interaction should be rejected: %s"%probe.tool)
	resident.current_cell=room.objects["bookshelf"].interaction_cells[0]
	var near_pick:=PrimitiveToolValidator.validate({"tool":"pick_up","args":{"target":"book_01"}},room,room.grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(bool(near_pick.get("ok",false)), "near interaction should be accepted")
	var tools:=PrimitiveToolCatalog.available(room,{"held_item_id":""}); var fridge_open:=false; var close_available:=false
	for entry in tools:
		if entry.tool=="open" and "fridge" in entry.valid_targets:fridge_open=true
	_check(fridge_open, "closed fridge should expose open")
	room.objects.fridge.state=true; tools=PrimitiveToolCatalog.available(room,{"held_item_id":""})
	for entry in tools:
		if entry.tool=="close" and "fridge" in entry.valid_targets:close_available=true
	_check(close_available, "open fridge should expose close")
	var nearest:=InteractionResolver.nearest_cell(room,"trash_bin",resident.current_cell)
	_check(bool(nearest.get("ok",false)) and room.grid.is_inside(nearest.cell), "trash bin should have an in-grid reachable interaction cell")
	var invalid:=PrimitiveToolValidator.validate({"tool":"open","args":{"target":"bed"}},room,room.grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(not bool(invalid.get("ok",false)), "unsupported open target should be rejected")
	resident.current_cell=room.objects["pc"].interaction_cells[0]
	var pc_off:=PrimitiveToolValidator.validate({"tool":"use_pc","args":{"target":"pc"}},room,room.grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(not bool(pc_off.get("ok",false)), "PC off should reject use_pc")
	PrimitiveToolExecutor.execute({"tool":"turn_on","args":{"target":"pc"}},room,resident,ResidentNeeds.new())
	var pc_on:=PrimitiveToolValidator.validate({"tool":"use_pc","args":{"target":"pc"}},room,room.grid,{"current_cell":resident.current_cell,"held_item_id":""},room.items)
	_check(bool(pc_on.get("ok",false)), "PC on should allow use_pc")

func _test_harness_authoritative_snapshot() -> void:
	var room:=RoomState.new(); var resident:=ResidentState.new(); var needs:=ResidentNeeds.new(); resident.current_cell=room.objects["bookshelf"].interaction_cells[0]; resident.held_item_id="book_01"; resident.posture="sitting"; resident.posture_target_id="chair"; room.items["book_01"].location="held"; room.items["book_01"].held_by="resident"
	var harness:=ResidentHarness.new(); harness._room=room; harness._goals=[]; harness._resident_snapshot=resident.snapshot(); harness._needs_snapshot=needs.snapshot()
	var decision={"decision_type":"plan","reason":"read","plan":[{"tool":"read","args":{"target":"book_01"}}],"goal_updates":{"add":[],"complete":[],"abandon":[]}}
	var result:=harness._validate_semantic(decision)
	_check(bool(result.get("ok",false)), "Harness should accept a held-book plan from authoritative snapshot")
	_check(harness._resident_snapshot.get("held_item_id","")=="book_01" and harness._resident_snapshot.get("posture","")=="sitting", "Harness snapshot should preserve held item and posture")
	harness.free()

func _test_v11_life_loop() -> void:
	var habits:=HabitStore.new(); var event:={"activity":"read","target":"bed","time_hour":20,"result":{"success":true},"need_delta":{"boredom":-20.0,"stress":-4.0}}
	for i in 4: habits.record(event)
	_check(habits.habits.size()==1 and habits.summary().size()==1, "repeated successful context should form a habit")
	_check(habits.summary().size()==1, "habit must remain observation-only")
	var memory:=MemoryStore.new(); memory.add_life_event(event)
	_check(memory.entries.size()==1 and memory.entries[0].get("activity","")=="read" and memory.entries[0].has("need_effects"), "LifeEvent should create one structured memory")
	var valid_intent={"decision_type":"plan","reason":"read","intention":"I want to read.","plan":[{"tool":"wait","args":{}}],"goal_updates":{"add":[],"complete":[],"abandon":[]}}
	_check(bool(DecisionSchema.validate(valid_intent).get("ok",false)), "short intention should be accepted")
	var invalid_intent:=valid_intent.duplicate(true); invalid_intent["intention"]=123
	_check(not bool(DecisionSchema.validate(invalid_intent).get("ok",false)), "non-string intention should be rejected")
	var migrated:=SaveManager._migrate_versioned({"save_version":2},2)
	_check(migrated.has("habits") and migrated.has("recent_activity_history") and migrated.has("memory_store"), "v1.1 state should be added during migration")

func _test_timed_activity_lifecycle() -> void:
	var room:=RoomState.new(); var needs:=ResidentNeeds.new(); var resident:=ResidentState.new(); resident.current_cell=room.objects["bed"].interaction_cells[0]
	var plan:=PlanExecutor.new(); plan.begin([{"tool":"sleep","args":{"target":"bed"}}],"sleep")
	var executor:=ActivityExecutor.new(); var started:=executor.begin("sleep","bed","sleep",room,needs,resident)
	_check(bool(started.get("ok",false)), "sleep should begin through production ActivityExecutor")
	_check(executor.state_name()=="starting" and plan.current().get("tool","")=="sleep", "PlanExecutor must not advance a timed activity at begin")
	_check(not bool(executor.update(119.0).get("completed",false)), "sleep should remain active before duration")
	_check(bool(executor.update(1.0).get("completed",false)) and executor.state_name()=="completed", "sleep should reach completed after duration")
	var before:=needs.values.duplicate(true); var result:=executor.complete(room,needs,resident)
	_check(bool(result.get("ok",false)) and float(needs.values.sleepiness)<float(before.sleepiness), "sleep completion should apply authoritative effect")
	_check(plan.advance(result), "PlanExecutor should advance only after ActivityExecutor completion")
	var event:=LifeEvent.activity_completed("Day 1 10:00","sleep","bed",resident.current_cell,120.0,before,needs.values,{"posture":"lying"})
	var memories:=MemoryStore.new(); var prefs:=PreferenceStore.new(); var habits:=HabitStore.new(); memories.add_life_event(event); prefs.record_life_event(event); habits.record(event)
	_check(memories.entries.size()==1 and memories.entries[0].get("activity","")=="sleep", "completed sleep should create a LifeEvent memory")
	_check(prefs.counts.get("sleep",0)==1 and habits.habits.size()==1, "LifeEvent should reach preference and habit evidence")
	room.objects["pc"].state=false; resident.current_cell=room.objects["pc"].interaction_cells[0]
	var pc:=ActivityExecutor.new(); var off:=pc.begin("use_pc","pc","pc",room,needs,resident)
	_check(not bool(off.get("ok",false)), "PC use should fail while powered off")
	PrimitiveToolExecutor.execute({"tool":"turn_on","args":{"target":"pc"}},room,resident,needs)
	var pc_started:=pc.begin("use_pc","pc","pc",room,needs,resident)
	_check(bool(pc_started.get("ok",false)) and not bool(pc.update(59.0).get("completed",false)), "PC activity should remain running")
	_check(bool(pc.update(1.0).get("completed",false)) and bool(pc.complete(room,needs,resident).get("ok",false)), "PC activity should complete after duration")
	var interrupted:=ActivityExecutor.new(); interrupted.begin("wait","","wait",room,needs,resident); var stopped:=interrupted.interrupt("test interruption")
	_check(bool(stopped.get("ok",false)) and interrupted.state_name()=="interrupted" and not bool(interrupted.complete(room,needs,resident).get("ok",false)), "interrupted activity must not report success")

func _test_skill_production_path() -> void:
	var room:=RoomState.new(); var resident:=ResidentState.new(); var needs:=ResidentNeeds.new(); resident.current_cell=room.objects.bookshelf.interaction_cells[0]
	var store:=SkillStore.new(); store.skills.append({"id":"skill_read_book","name":"read_book","description":"Read","steps":[{"tool":"move_near","args":{"target_type":"bookshelf"}},{"tool":"pick_up","args":{"target_type":"book"}},{"tool":"read","args":{"target_type":"book"}}],"status":"active","offer_count":0,"times_used":0,"success_count":0,"failure_count":0})
	var offered:=store.relevant(room,resident.held_item_id,needs.values,resident)
	_check(offered.size()==1 and int(store.skills[0].offer_count)==1, "usable Skill should be offered exactly once")
	var expanded:=SkillExecutor.expand(store.skills[0],room); _check(not expanded.is_empty() and bool(PlanPreflight.validate(expanded,room,resident,needs).get("ok",false)), "offered Skill should expand and preflight")
	for step in expanded:
		if step.tool=="move_near": resident.current_cell=room.objects.bookshelf.interaction_cells[0]
		elif step.tool=="pick_up": PrimitiveToolExecutor.execute(step,room,resident,needs)
	store.mark_used("skill_read_book",true); _check(int(store.skills[0].success_count)==1 and int(store.skills[0].failure_count)==0, "Skill success telemetry should be recorded")
	var failure_store:=SkillStore.new(); failure_store.skills.append(store.skills[0].duplicate(true)); failure_store.mark_used("skill_read_book",false)
	_check(int(failure_store.skills[0].failure_count)==1 and int(failure_store.skills[0].success_count)==1, "Skill failure telemetry should be recorded safely")

func _test_multiday_world_dynamics() -> void:
	var clock:=WorldClock.new(); clock.advance(720.0,1.0)
	_check(clock.snapshot().day==2 and clock.snapshot().period=="morning", "WorldClock should expose consecutive days and period")
	var needs:=ResidentNeeds.new(); var start:=needs.snapshot(); needs.advance(1440.0)
	_check(float(needs.values.hunger)<=100.0 and float(needs.values.thirst)<=100.0 and float(needs.values.hunger)>float(start.hunger), "24h needs progression should be bounded")
	var room:=RoomState.new(); var resident:=ResidentState.new(); resident.current_cell=room.objects.fridge.interaction_cells[0]; room.objects.fridge.state=true
	var eater:=ActivityExecutor.new(); var eat_started:=eater.begin("eat","food_stack","eat",room,needs,resident); _check(bool(eat_started.ok), "eating should start with stock")
	eater.update(15.0); var food_before:=room.item_quantity("simple_food"); var eat_result:=eater.complete(room,needs,resident); _check(bool(eat_result.ok) and room.item_quantity("simple_food")==food_before-1 and int(room.resources.trash)==1, "eating should consume food and create trash")
	room.objects.pc.state=true; resident.current_cell=room.objects.pc.interaction_cells[0]
	var grocer:=ActivityExecutor.new(); grocer.begin("order_groceries","pc","order",room,needs,resident); grocer.update(10.0); grocer.complete(room,needs,resident); _check(room.item_quantity("simple_food")>food_before-1, "groceries should replenish stock")
	var dirty:=room.cleanliness; room.advance(1440.0); _check(room.cleanliness<dirty, "cleanliness should decline gradually")
	room.resources.trash=3; var cleaner:=ActivityExecutor.new(); resident.current_cell=room.objects.sink.interaction_cells[0]; cleaner.begin("clean","sink","clean",room,needs,resident); cleaner.update(30.0); cleaner.complete(room,needs,resident); _check(room.cleanliness>dirty-10.0, "cleaning should improve cleanliness")

func _test_save_round_trip_and_migration() -> void:
	var room:=RoomState.new(); room.objects.chair.state=true; room.move_object("chair",Vector2i(5,1),0); room.items.food_stack.quantity=2
	var loaded:=RoomState.new(); loaded.load_state(room.serialize())
	_check(loaded.objects.chair.origin_cell==Vector2i(5,1) and loaded.objects.chair.state==true, "object placement and state should round-trip")
	_check(int(loaded.items.food_stack.quantity)==2, "item quantity should round-trip")
	var resident:=ResidentState.new(); resident.held_item_id="book_01"; resident.posture="sitting"; var resident_loaded:=ResidentState.new(); resident_loaded.load_state(resident.serialize())
	_check(resident_loaded.held_item_id=="book_01" and resident_loaded.posture=="sitting", "resident state should round-trip")
	var migrated:=SaveManager._migrate_versioned({"save_version":2},2)
	_check(int(migrated.save_version)==SaveManager.SAVE_VERSION and migrated.has("plan_history") and migrated.has("skills"), "older save versions should migrate")
	var test_path:="user://one_room_test_roundtrip.json"
	var payload:={"sim_minutes":600.0,"room":room.serialize(),"resident_state":resident.serialize(),"needs":ResidentNeeds.new().snapshot(),"memory_store":{"entries":[]},"goal_store":{"goals":[]},"preferences":{},"diary":[],"decision_history":[],"plan_history":[],"skills":{"skills":[]}}
	_check(SaveManager.save_state(payload,test_path), "SaveManager should write test round-trip")
	var persisted:=SaveManager.load_state(test_path)
	_check(persisted.has("room") and persisted.has("resident_state") and int(persisted.room.items.food_stack.quantity)==2, "SaveManager should load authoritative state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
