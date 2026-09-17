extends SceneTree

## Low-cost local benchmark. Run with: godot --headless --path . --script res://tests/live_ornith_regression.gd -- --runs 1
## This exercises the production prompt, DecisionSchema, PrimitiveToolValidator,
## PrimitiveToolExecutor, and SkillExecutor without mutating the real save.

var runs := 1
var only_scenarios := ""
var client: HTTPRequest
var metrics := {
	"decisions": 0, "json_valid": 0, "schema_valid": 0, "semantic_valid": 0,
	"harness_accepted": 0, "execution_success": 0, "execution_abort": 0,
	"repair_used": 0, "repair_recovered": 0, "parse_failures": 0,
	"hallucinated_tools": 0, "hallucinated_targets": 0, "harness_rejected_plans": 0,
	"skill_invoked": 0, "skill_completed": 0, "skill_failed": 0
}
var failure_reasons := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--runs" and i + 1 < args.size():
			runs = max(1, int(args[i + 1]))
		if args[i] == "--scenario" and i + 1 < args.size():
			only_scenarios = str(args[i + 1])
	client = HTTPRequest.new()
	get_root().add_child(client)
	await process_frame
	await _run()
	quit(0)

func _run() -> void:
	var model_result := await _request("/v1/models", {})
	if not bool(model_result.get("ok", false)):
		print("Ornith live test: SKIPPED - local server unavailable")
		return
	var model_body: Dictionary = model_result.get("body", {})
	var model := str(model_body.get("data", [{}])[0].get("id", ""))
	if model == "":
		print("Ornith live test: SKIPPED - model id unavailable")
		return
	var prompt := FileAccess.get_file_as_string("res://ai/prompts/resident_system_prompt.txt")
	var scenarios := ["free_movement", "read_book", "eat_drink", "invalid_proximity", "sit", "skill", "furniture", "no_useful_action"]
	if only_scenarios != "":
		scenarios = only_scenarios.split(",")
	for run_index in runs:
		for scenario in scenarios:
			var context := _scenario_context(str(scenario))
			var response := await _request("/v1/chat/completions", {
				"model": model, "temperature": 0.3, "max_tokens": 192,
				"response_format": {"type": "json_object"},
				"messages": [{"role": "system", "content": prompt}, {"role": "user", "content": JSON.stringify(context)}]
			})
			metrics["decisions"] += 1
			if not bool(response.get("ok", false)):
				metrics["execution_abort"] += 1
				_fail("server_error")
				continue
			var body: Dictionary = response.get("body", {})
			var choices: Array = body.get("choices", [])
			if choices.is_empty():
				metrics["execution_abort"] += 1
				_fail("missing_choice")
				continue
			var content := str(choices[0].get("message", {}).get("content", ""))
			var parsed = JSON.parse_string(content)
			if not parsed is Dictionary:
				metrics["parse_failures"] += 1
				metrics["execution_abort"] += 1
				_fail("malformed_json")
				continue
			metrics["json_valid"] += 1
			var schema := DecisionSchema.validate(parsed)
			if not bool(schema.get("ok", false)):
				metrics["execution_abort"] += 1
				_fail("schema:%s" % str(schema.get("error", "invalid")))
				continue
			metrics["schema_valid"] += 1
			_evaluate_semantics(parsed, str(scenario))

	print("Ornith regression summary (%d scenarios x %d runs)" % [scenarios.size(), runs])
	for key in metrics:
		print("%s: %s" % [key, metrics[key]])
	print("failure_reasons_top10: %s" % JSON.stringify(_top_failures(10)))

func _evaluate_semantics(decision: Dictionary, scenario: String) -> void:
	if str(decision.get("decision_type", "")) == "skill":
		metrics["skill_invoked"] += 1
		var skill: Dictionary = decision.get("skill", {})
		if scenario != "skill" or str(skill.get("id", "")) != "skill_read_book":
			metrics["skill_failed"] += 1
			metrics["harness_rejected_plans"] += 1
			metrics["execution_abort"] += 1
			_fail("unknown_or_unavailable_skill")
			return
		var room := RoomState.new()
		var expanded := SkillExecutor.expand({"id":"skill_read_book", "steps":[
			{"tool":"move_near","args":{"target_type":"bookshelf"}},
			{"tool":"pick_up","args":{"target_type":"book"}},
			{"tool":"read","args":{"target_type":"book"}}
		]}, room)
		if _execute_plan(expanded, room, ResidentState.new()):
			metrics["semantic_valid"] += 1; metrics["harness_accepted"] += 1; metrics["skill_completed"] += 1; metrics["execution_success"] += 1
		else:
			metrics["skill_failed"] += 1; metrics["harness_rejected_plans"] += 1; metrics["execution_abort"] += 1; _fail("skill_expansion_not_executable")
		return
	var room := RoomState.new()
	var resident := ResidentState.new()
	_configure_scenario(room, resident, scenario)
	var plan: Array = decision.get("plan", [])
	for step in plan:
		if not step is Dictionary: continue
		var tool := str(step.get("tool", ""))
		if not PrimitiveToolCatalog.TOOLS.has(tool): metrics["hallucinated_tools"] += 1
		var args: Dictionary = step.get("args", {})
		var definition: Dictionary = PrimitiveToolCatalog.TOOLS.get(tool, {})
		var target := str(args.get("target", ""))
		if target != "" and definition.get("target", "") == "object" and not room.objects.has(target): metrics["hallucinated_targets"] += 1
		if target != "" and definition.get("target", "") == "item" and not room.items.has(target): metrics["hallucinated_targets"] += 1
	if _execute_plan(plan, room, resident):
		metrics["semantic_valid"] += 1; metrics["harness_accepted"] += 1; metrics["execution_success"] += 1
	else:
		metrics["harness_rejected_plans"] += 1; metrics["execution_abort"] += 1; _fail("plan_rejected_or_not_executable")

func _execute_plan(plan: Array, room: RoomState, resident: ResidentState) -> bool:
	if plan.is_empty() or plan.size() > 6: _fail("plan_length"); return false
	for step in plan:
		var checked := PrimitiveToolValidator.validate(step, room, room.grid, {"current_cell":resident.current_cell,"held_item_id":resident.held_item_id}, room.items)
		if not bool(checked.get("ok", false)):
			_fail("validator:%s" % str(checked.get("error", "rejected")))
			return false
		var tool := str(step.get("tool", "")); var args: Dictionary = step.get("args", {})
		if tool == "move_near":
			var target := str(args.get("target", "")); var cells: Array = room.objects[target].get("interaction_cells", [])
			if cells.is_empty() or room.grid.find_path(resident.current_cell, cells[0], room.blocked_cells()).is_empty(): _fail("target_unreachable"); return false
			resident.current_cell = cells[0]
		elif tool == "move_to":
			var destination := Vector2i(int(args.get("x", -1)), int(args.get("y", -1)))
			if room.grid.find_path(resident.current_cell, destination, room.blocked_cells()).is_empty(): _fail("destination_unreachable"); return false
			resident.current_cell = destination
		else:
			var result := PrimitiveToolExecutor.execute(step, room, resident, ResidentNeeds.new())
			if not bool(result.get("ok", false)): _fail("executor_rejected"); return false
	return true

func _scenario_context(scenario: String) -> Dictionary:
	var room := RoomState.new(); var resident := ResidentState.new(); _configure_scenario(room, resident, scenario)
	var resident_data := {"cell":[resident.current_cell.x,resident.current_cell.y],"posture":resident.posture,"held_item_id":resident.held_item_id}
	var available_skills: Array = []
	if scenario == "skill": available_skills = [{"id":"skill_read_book","name":"read_in_bed","description":"Move to the shelf, pick up a book, and read it.","success_rate":1.0}]
	var item_observation:Array=[]
	for id in room.items: item_observation.append({"id":id,"type":room.items[id].get("type",""),"location":room.items[id].get("location","")})
	return {"time":{"day":1,"hour":10,"minute":0},"self":{"cell":resident_data.cell,"posture":resident.posture,"held_item":null,"needs":{"hunger":30,"thirst":30,"sleepiness":20,"boredom":20}},"room":{"grid_size":[RoomGrid.WIDTH,RoomGrid.HEIGHT],"cleanliness":room.cleanliness,"light_on":room.light_on},"objects":room.visible_objects(),"items":item_observation,"available_tools":PrimitiveToolCatalog.available(room,{"held_item_id":resident.held_item_id}),"available_skills":available_skills,"active_goals":[],"relevant_memories":[],"recent_behavior": {"note":"No action is required; choose naturally."} if scenario == "no_useful_action" else {}}

func _configure_scenario(room: RoomState, resident: ResidentState, scenario: String) -> void:
	if scenario in ["read_book", "invalid_proximity"]: resident.current_cell = Vector2i(10, 6)
	elif scenario == "eat_drink": resident.current_cell = Vector2i(2, 7)
	elif scenario in ["sit", "furniture"]: resident.current_cell = room.objects["chair"].interaction_cells[0]
	else: resident.current_cell = Vector2i(5, 6)

func _fail(reason: String) -> void:
	failure_reasons[reason] = int(failure_reasons.get(reason, 0)) + 1

func _top_failures(limit: int) -> Dictionary:
	var rows: Array = []
	for key in failure_reasons: rows.append({"reason":key,"count":failure_reasons[key]})
	rows.sort_custom(func(a,b): return int(a.count) > int(b.count))
	var out := {}; for i in min(limit, rows.size()): out[rows[i].reason] = rows[i].count
	return out

func _request(path: String, payload: Dictionary) -> Dictionary:
	var url := "http://127.0.0.1:8000" + path
	var method := HTTPClient.METHOD_GET if payload.is_empty() else HTTPClient.METHOD_POST
	var body := "" if payload.is_empty() else JSON.stringify(payload)
	var error := client.request(url, ["Content-Type: application/json"], method, body)
	if error != OK: return {"ok":false}
	var result = await client.request_completed
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	return {"ok":result[0] == HTTPRequest.RESULT_SUCCESS and result[1] >= 200 and result[1] < 300 and parsed is Dictionary,"body":parsed}
