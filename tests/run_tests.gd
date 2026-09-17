extends SceneTree

var failures := 0

func _initialize() -> void:
	_test_needs()
	_test_candidates_and_validation()
	_test_action_executor()
	_test_memory_and_goals()
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
	var before := float(needs.values.hunger)
	needs.advance(10.0)
	_check(float(needs.values.hunger) > before, "hunger should increase with time")
	needs.apply({"hunger": -999.0})
	_check(float(needs.values.hunger) == 0.0, "needs should clamp at zero")

func _test_candidates_and_validation() -> void:
	var room := RoomState.new()
	var candidates := ActionCatalog.candidates(room)
	var valid := ActionValidator.validate({"action":{"id":"eat_food","target":"fridge"},"reason":"Hungry.","goal_updates":{"add":[],"complete":[],"abandon":[]}}, candidates, room, [])
	_check(bool(valid.ok), "eat_food should validate while food exists")
	room.resources.simple_food = 0
	candidates = ActionCatalog.candidates(room)
	var invalid := ActionValidator.validate({"action":{"id":"eat_food","target":"fridge"},"reason":"Hungry.","goal_updates":{"add":[],"complete":[],"abandon":[]}}, candidates, room, [])
	_check(not bool(invalid.ok), "eat_food should be rejected when food is unavailable")
	var invented := ActionValidator.validate({"action":{"id":"teleport","target":"bed"},"reason":"", "goal_updates":{"add":[],"complete":[],"abandon":[]}}, candidates, room, [])
	_check(not bool(invented.ok), "invented actions must be rejected")

func _test_action_executor() -> void:
	var room := RoomState.new()
	var needs := ResidentNeeds.new()
	var executor := ActionExecutor.new()
	var start_pos: Vector2 = room.objects.fridge.interaction_point
	var started := executor.begin("eat_food", "fridge", "I am hungry.", room, needs, start_pos)
	_check(str(started.event) == "action_queued", "action should queue")
	var update := executor.update(0.0, 20.0, start_pos, 180.0, needs)
	_check(str(update.event) == "action_completed", "action should complete after duration")
	var food_before := int(room.resources.simple_food)
	var hunger_before := float(needs.values.hunger)
	var result := executor.apply_completion(room, needs)
	_check(bool(result.ok), "completed action effects should apply")
	_check(int(room.resources.simple_food) == food_before - 1, "food should be consumed")
	_check(float(needs.values.hunger) < hunger_before, "eating should reduce hunger")

func _test_memory_and_goals() -> void:
	var memory := MemoryStore.new()
	memory.add("Day 1 09:00", "use_pc", "I stayed on the computer and felt tired.", "completed", 0.8, ["pc"], {"sleepiness":80})
	memory.add("Day 1 10:00", "read_book", "Reading was calming.", "completed", 0.6, ["bookshelf"], {"stress":50})
	var retrieved := memory.retrieve(["use_pc"], [], 1, "pc", ["sleepiness"])
	_check(retrieved.size() == 1 and str(retrieved[0].related_action) == "use_pc", "memory retrieval should prefer relevant episodes")
	var goals := GoalStore.new()
	goals.apply({"add":["Finish the book"],"complete":[],"abandon":[]})
	_check("Finish the book" in goals.active_texts(), "goal should be active after add")
	goals.apply({"add":[],"complete":["Finish the book"],"abandon":[]})
	_check(not ("Finish the book" in goals.active_texts()), "completed goal should leave active set")
