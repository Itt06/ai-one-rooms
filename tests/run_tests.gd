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
	var room:=RoomState.new(); var resident:=ResidentState.new()
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

func _test_save_round_trip_and_migration() -> void:
	var room:=RoomState.new(); room.objects.chair.state=true; room.move_object("chair",Vector2i(5,1),0); room.items.food_stack.quantity=2
	var loaded:=RoomState.new(); loaded.load_state(room.serialize())
	_check(loaded.objects.chair.origin_cell==Vector2i(5,1) and loaded.objects.chair.state==true, "object placement and state should round-trip")
	_check(int(loaded.items.food_stack.quantity)==2, "item quantity should round-trip")
	var resident:=ResidentState.new(); resident.held_item_id="book_01"; resident.posture="sitting"; var resident_loaded:=ResidentState.new(); resident_loaded.load_state(resident.serialize())
	_check(resident_loaded.held_item_id=="book_01" and resident_loaded.posture=="sitting", "resident state should round-trip")
	var migrated:=SaveManager._migrate_versioned({"save_version":2},2)
	_check(int(migrated.save_version)==SaveManager.SAVE_VERSION and migrated.has("plan_history") and migrated.has("skills"), "older save versions should migrate")
