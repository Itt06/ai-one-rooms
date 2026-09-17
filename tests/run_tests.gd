extends SceneTree

var failures := 0

func _initialize() -> void:
	_test_needs()
	_test_candidates_and_validation()
	_test_action_executor()
	_test_memory_and_goals()
	_test_grid_and_primitives()
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
	room.resources["simple_food"] = 0
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
	var executor := ActionExecutor.new()
	var start_pos: Vector2 = room.objects["fridge"].interaction_point
	var started := executor.begin("eat_food","fridge","I am hungry.",room,needs,start_pos)
	_check(str(started.get("event","")) == "action_queued", "action should queue")
	var update := executor.update(0.0,20.0,start_pos,180.0,needs)
	_check(str(update.get("event","")) == "action_completed", "action should complete after duration")
	var food_before := int(room.resources.get("simple_food",0))
	var hunger_before := float(needs.values.get("hunger",0.0))
	var result := executor.apply_completion(room,needs)
	_check(bool(result.get("ok",false)), "completed action effects should apply")
	_check(int(room.resources.get("simple_food",0)) == food_before - 1, "food should be consumed")
	_check(float(needs.values.get("hunger",0.0)) < hunger_before, "eating should reduce hunger")
	var sink_executor := ActionExecutor.new()
	var sink_pos: Vector2 = room.objects["sink"].interaction_point
	var water_before := int(room.resources.get("water",0))
	sink_executor.begin("drink_water","sink","I am thirsty.",room,needs,sink_pos)
	sink_executor.update(0.0,20.0,sink_pos,180.0,needs)
	sink_executor.apply_completion(room,needs)
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
