extends Node2D

const DEFAULT_CONFIG := {"base_url":"http://127.0.0.1:8000/v1","model":"Ornith-1.5-9B","temperature":0.3,"timeout_ms":15000,"max_tokens":256}

var speed := 1.0
var status := "idle"
var reason := "The room is quiet."
var diary: Array = []
var decision_history: Array = []
var last_latency_ms := 0
var last_observation := ""
var last_response := ""
var validation_error := ""
var decision_cooldown := 0.0
var person_pos := Vector2(420,390)
var move_speed := 180.0
var labels := {}
var last_retrieved_memory_ids: Array = []
var pending_diary_text = null

var clock := WorldClock.new()
var room_state := RoomState.new()
var needs_model := ResidentNeeds.new()
var memory_store := MemoryStore.new()
var goal_store := GoalStore.new()
var preferences := PreferenceStore.new()
var action_executor := ActionExecutor.new()
var harness: ResidentHarness

func _ready() -> void:
	_load_game()
	harness = ResidentHarness.new()
	add_child(harness)
	harness.decision_ready.connect(_on_decision_ready)
	harness.decision_failed.connect(_on_decision_failed)
	_add_room_art()
	_build_ui()
	queue_redraw()
	_request_decision()

func _process(delta: float) -> void:
	var elapsed_minutes := delta * speed * 2.0
	if status != "thinking" and speed > 0.0:
		clock.advance(delta, speed)
		needs_model.advance(elapsed_minutes)
	if action_executor.is_active() and speed > 0.0:
		var update := action_executor.update(delta, elapsed_minutes, person_pos, move_speed, needs_model)
		person_pos = update.position
		status = str(update.state)
		if str(update.event) == "action_completed":
			_finish_action()
		else:
			_check_interrupt()
	decision_cooldown = max(0.0, decision_cooldown - delta)
	if status == "idle" and decision_cooldown <= 0.0 and speed > 0.0:
		_request_decision()
	_update_ui()
	queue_redraw()

func _request_decision() -> void:
	if harness == null or harness.is_busy() or status == "thinking":
		return
	var candidates := ActionCatalog.candidates(room_state)
	var action_ids: Array = []
	for candidate in candidates:
		action_ids.append(str(candidate.get("id", "")))
	var strong_needs: Array = []
	for key in needs_model.values:
		if float(needs_model.values[key]) >= 70.0:
			strong_needs.append(str(key))
	var memories := memory_store.retrieve(action_ids, goal_store.active_texts(), 6, "", strong_needs)
	last_retrieved_memory_ids = []
	for memory in memories:
		last_retrieved_memory_ids.append(str(memory.get("id", "")))
	var observation := ObservationBuilder.build(clock, needs_model, room_state, person_pos, "idle", memories, goal_store.active_texts(), preferences.summary(), candidates, preferences.habit_summary())
	last_observation = JSON.stringify(observation)
	status = "thinking"
	validation_error = ""
	if not harness.request_decision(observation, candidates, room_state, goal_store.active_texts(), _config(), _prompt()):
		_fallback("LLM request could not start")

func _on_decision_ready(decision: Dictionary, latency_ms: int, raw_response: String) -> void:
	last_latency_ms = latency_ms
	last_response = raw_response
	var candidates := ActionCatalog.candidates(room_state)
	var validation := ActionValidator.validate(decision, candidates, room_state, goal_store.active_texts())
	if not validation.ok:
		_fallback("Stale or invalid decision: %s" % validation.error)
		return
	var normalized: Dictionary = validation.decision
	goal_store.apply(normalized.goal_updates)
	pending_diary_text = normalized.get("diary_text", null)
	_start_action(str(normalized.action.id), str(normalized.action.target), str(normalized.reason))

func _on_decision_failed(error_message: String, latency_ms: int, raw_response: String) -> void:
	last_latency_ms = latency_ms
	last_response = raw_response
	_fallback(error_message)

func _start_action(id: String, target: String, why: String) -> void:
	reason = why if why != "" else str(ActionCatalog.DEFINITIONS.get(id, {}).get("display_name", id))
	var started := action_executor.begin(id, target, reason, room_state, needs_model, person_pos)
	if str(started.get("event", "")) == "action_failed":
		_fallback(str(started.get("reason", "Action failed")))
		return
	status = action_executor.state_name()
	_record_history("queued", id, target, reason)

func _finish_action() -> void:
	var id := action_executor.action_id
	var target := action_executor.target_id
	var result := action_executor.apply_completion(room_state, needs_model)
	if not bool(result.get("ok", false)):
		validation_error = str(result.get("reason", "Action completion failed"))
		status = "idle"
		action_executor.reset()
		return
	var before: Dictionary = result.before_needs
	var after: Dictionary = result.after_needs
	var improvement := 0.0
	for key in ["boredom","stress","discomfort"]:
		improvement += float(before.get(key,0.0)) - float(after.get(key,0.0))
	preferences.record(id, clamp(improvement / 300.0, -0.05, 0.05), int(clock.snapshot().hour))
	var memory_summary := _memory_summary(id, before, after)
	memory_store.add(clock.text(), id, memory_summary, "completed", _memory_salience(before, after), [target] if target != "" else [], before)
	if id == "write_diary":
		var text := str(pending_diary_text).strip_edges() if pending_diary_text != null else reason
		if text == "": text = reason
		diary.push_front({"time":clock.text(),"text":text.left(500)})
		if diary.size() > 60: diary.resize(60)
	_record_history("completed", id, target, reason)
	DecisionLogger.append({"time":clock.text(),"action":id,"target":target,"reason":reason,"retrieved_memories":last_retrieved_memory_ids,"goals":goal_store.active_texts(),"latency_ms":last_latency_ms,"validation":"valid","result":"completed"})
	pending_diary_text = null
	action_executor.reset()
	status = "idle"
	decision_cooldown = 1.0
	_save_game()

func _check_interrupt() -> void:
	if action_executor.state != ActionExecutor.State.RUNNING:
		return
	var severe_thirst := float(needs_model.values.get("thirst",0.0)) >= 98.0 and action_executor.action_id != "drink_water"
	var severe_discomfort := float(needs_model.values.get("discomfort",0.0)) >= 98.0
	if severe_thirst or severe_discomfort:
		var interrupted := action_executor.interrupt("A critical physical need interrupted the activity.")
		if bool(interrupted.get("ok",false)):
			_record_history("interrupted", action_executor.action_id, action_executor.target_id, str(interrupted.get("reason","")))
			action_executor.reset()
			status = "idle"
			decision_cooldown = 0.25

func _fallback(message: String) -> void:
	validation_error = message
	reason = "%s; I will wait." % message
	if action_executor.is_active():
		action_executor.interrupt(message)
	action_executor.reset()
	var result := action_executor.begin("wait", "", reason, room_state, needs_model, person_pos)
	status = action_executor.state_name() if str(result.get("event","")) != "action_failed" else "idle"
	decision_cooldown = 2.0

func _memory_summary(id: String, before: Dictionary, after: Dictionary) -> String:
	var name := str(ActionCatalog.DEFINITIONS.get(id,{}).get("display_name",id)).to_lower()
	var strongest := ""
	var best_change := 0.0
	for key in before:
		var change := float(before.get(key,0.0)) - float(after.get(key,0.0))
		if change > best_change:
			best_change = change
			strongest = str(key)
	if strongest != "" and best_change >= 8.0:
		return "I %s and it noticeably eased my %s." % [name, strongest.replace("_need","")]
	return "I %s." % name

func _memory_salience(before: Dictionary, after: Dictionary) -> float:
	var largest := 0.0
	for key in before:
		largest = max(largest, abs(float(before.get(key,0.0)) - float(after.get(key,0.0))))
	return clamp(0.35 + largest / 100.0, 0.35, 0.9)

func _record_history(event: String, action: String, target: String, why: String) -> void:
	decision_history.push_front({"time":clock.text(),"event":event,"action":action,"target":target,"reason":why})
	if decision_history.size() > 50:
		decision_history.resize(50)

func _prompt() -> String:
	var file := FileAccess.open("res://ai/prompts/resident_system_prompt.txt", FileAccess.READ)
	return file.get_as_text() if file else "Choose one available action and return JSON only."

func _config() -> Dictionary:
	if FileAccess.file_exists("user://one_room_config.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://one_room_config.json"))
		if parsed is Dictionary:
			return parsed
	return DEFAULT_CONFIG

func _save_game() -> void:
	SaveManager.save_state({
		"sim_minutes":clock.total_minutes,
		"needs":needs_model.values,
		"room":{"resources":room_state.resources,"cleanliness":room_state.cleanliness,"light_on":room_state.light_on},
		"memory_store":memory_store.serialize(),
		"goal_store":goal_store.serialize(),
		"preferences":preferences.serialize(),
		"diary":diary,
		"decision_history":decision_history,
		"resident_position":[person_pos.x,person_pos.y]
	})

func _load_game() -> void:
	var data := SaveManager.load_state()
	if data.is_empty(): return
	clock.total_minutes = float(data.get("sim_minutes",480.0))
	if data.get("needs",{}) is Dictionary:
		for key in needs_model.values:
			if data.needs.has(key): needs_model.values[key] = float(data.needs[key])
	var room = data.get("room",{})
	if room is Dictionary:
		if room.get("resources",{}) is Dictionary:
			for key in room_state.resources:
				if room.resources.has(key): room_state.resources[key] = room.resources[key]
		room_state.cleanliness = float(room.get("cleanliness",82.0))
		room_state.light_on = bool(room.get("light_on",true))
	memory_store.load_state(data.get("memory_store",{}))
	goal_store.load_state(data.get("goal_store",{}))
	preferences.load_state(data.get("preferences",{}))
	if data.get("diary",[]) is Array: diary = data.diary.duplicate(true)
	if data.get("decision_history",[]) is Array: decision_history = data.decision_history.duplicate(true)
	var p = data.get("resident_position",[420.0,390.0])
	if p is Array and p.size() >= 2: person_pos = Vector2(float(p[0]),float(p[1]))

func _add_room_art() -> void:
	var texture := load("res://assets/room_background.png") as Texture2D
	if texture == null: return
	var room_art := TextureRect.new()
	room_art.texture = texture; room_art.position = Vector2(40,40); room_art.size = Vector2(820,600)
	room_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; room_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; room_art.z_index = -1; add_child(room_art)

func _build_ui() -> void:
	labels.time = _label(Vector2(920,24),"",24)
	labels.action = _label(Vector2(920,64),"",18)
	labels.reason = _label(Vector2(920,98),"",15); labels.reason.size = Vector2(345,70)
	labels.panel = _label(Vector2(920,175),"",14); labels.panel.size = Vector2(345,410)
	labels.history = _label(Vector2(920,480),"",12); labels.history.size = Vector2(345,150)
	var save := Button.new(); save.text = "Save"; save.position = Vector2(920,660); save.pressed.connect(_save_game); add_child(save)
	var pause := Button.new(); pause.text = "Pause"; pause.position = Vector2(985,660); pause.pressed.connect(func(): speed = 0.0 if speed > 0.0 else 1.0); add_child(pause)
	var speeds := OptionButton.new(); speeds.position = Vector2(1060,660)
	for x in [1,2,4,8]: speeds.add_item("%sx" % x)
	speeds.item_selected.connect(func(i): speed = pow(2.0,i)); add_child(speeds)

func _label(pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new(); label.position = pos; label.text = text; label.add_theme_font_size_override("font_size",font_size); add_child(label); return label

func _update_ui() -> void:
	if not labels.has("time"): return
	labels.time.text = clock.text()
	labels.action.text = "Action: %s (%s)" % [action_executor.action_id if action_executor.action_id != "" else "idle", status]
	labels.reason.text = "Reason: " + reason
	var text := "NEEDS\n"
	for key in needs_model.values: text += "%s: %3d\n" % [key,int(needs_model.values[key])]
	text += "\nGOALS\n" + ("none\n" if goal_store.active_texts().is_empty() else "\n".join(goal_store.active_texts()) + "\n")
	text += "\nPREFERENCES\n"
	for key in preferences.summary(): text += "%s: %.2f\n" % [key,float(preferences.summary()[key])]
	text += "\nLLM: %d ms" % last_latency_ms
	labels.panel.text = text
	var history_text := "RECENT\n"
	for item in decision_history.slice(0,min(5,decision_history.size())):
		history_text += "%s %s: %s\n" % [item.time,item.event,item.action]
	labels.history.text = history_text

func _draw() -> void:
	draw_rect(Rect2(0,0,900,720),Color("#263238"))
	for id in room_state.objects:
		var p: Vector2 = room_state.objects[id].position
		draw_circle(p,8,Color("#8d6e63"))
	draw_circle(person_pos,24,Color("#4fc3f7"))
	draw_string(ThemeDB.fallback_font,person_pos+Vector2(-30,-32),"Resident",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#102027"))
