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
var debug_panel: Panel
var debug_label: Label

var clock := WorldClock.new()
var room_state := RoomState.new()
var needs_model := ResidentNeeds.new()
var memory_store := MemoryStore.new()
var goal_store := GoalStore.new()
var preferences := PreferenceStore.new()
var action_executor := ActionExecutor.new()
var harness: ResidentHarness
var resident_state := ResidentState.new()
var resident_movement := ResidentMovement.new()
var plan_executor := PlanExecutor.new()
var plan_moving := false
var plan_history := PlanHistory.new()
var skill_store := SkillStore.new()
var current_skill_id := ""

func _ready() -> void:
	_load_game()
	harness = ResidentHarness.new()
	add_child(harness)
	harness.decision_ready.connect(_on_decision_ready)
	harness.decision_failed.connect(_on_decision_failed)
	harness.plan_ready.connect(_on_plan_ready)
	harness.skill_ready.connect(_on_skill_ready)
	resident_state.render_position = person_pos
	_add_room_art()
	_build_ui()
	queue_redraw()
	_request_decision()

func _process(delta: float) -> void:
	var elapsed_minutes := delta * speed * 2.0
	if status != "thinking" and speed > 0.0:
		clock.advance(delta,speed)
		needs_model.advance(elapsed_minutes)
		room_state.advance(elapsed_minutes)
		if room_state.cleanliness < 40.0:
			needs_model.apply({"discomfort":elapsed_minutes * 0.01})
	if action_executor.is_active() and speed > 0.0:
		var update := action_executor.update(delta,elapsed_minutes,person_pos,move_speed,needs_model)
		person_pos = update.get("position",person_pos)
		status = str(update.get("state",status))
		if str(update.get("event","")) == "action_completed":
			_finish_action()
		else:
			_check_interrupt()
	if plan_executor.active and plan_moving and speed > 0.0:
		if resident_movement.update(resident_state,delta,move_speed):
			person_pos = resident_state.render_position
			plan_moving = false
			_complete_plan_step()
	elif plan_executor.active and not plan_moving and not action_executor.is_active():
		_run_plan_step()
	decision_cooldown = max(0.0,decision_cooldown - delta)
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
		action_ids.append(str(candidate.get("id","")))
	var strong_needs: Array = []
	for key in needs_model.values:
		if float(needs_model.values.get(key,0.0)) >= 70.0:
			strong_needs.append(str(key))
	var memories := memory_store.retrieve(action_ids,goal_store.active_texts(),6,"",strong_needs)
	last_retrieved_memory_ids = []
	for memory in memories:
		last_retrieved_memory_ids.append(str(memory.get("id","")))
	var observation := ObservationBuilder.build(clock,needs_model,room_state,person_pos,"idle",memories,goal_store.active_texts(),preferences.summary(),candidates,preferences.habit_summary(),{"cell":resident_state.current_cell,"posture":resident_state.posture,"held_item_id":resident_state.held_item_id},skill_store.relevant(room_state,resident_state.held_item_id,needs_model.values))
	last_observation = JSON.stringify(observation)
	status = "thinking"
	validation_error = ""
	if not harness.request_decision(observation,candidates,room_state,goal_store.active_texts(),_config(),_prompt()):
		_fallback("LLM request could not start")

func _on_decision_ready(decision: Dictionary, latency_ms: int, raw_response: String) -> void:
	last_latency_ms = latency_ms
	last_response = raw_response
	var candidates := ActionCatalog.candidates(room_state)
	var validation := ActionValidator.validate(decision,candidates,room_state,goal_store.active_texts())
	if not bool(validation.get("ok",false)):
		_fallback("Stale or invalid decision: %s" % str(validation.get("error","unknown error")))
		return
	var normalized: Dictionary = validation.get("decision",{})
	goal_store.apply(normalized.get("goal_updates",{}))
	pending_diary_text = normalized.get("diary_text",null)
	var action: Dictionary = normalized.get("action",{})
	_start_action(str(action.get("id","wait")),str(action.get("target","")),str(normalized.get("reason","")))

func _on_plan_ready(plan:Array, why:String, updates:Dictionary, latency_ms:int, raw_response:String)->void:
	last_latency_ms=latency_ms; last_response=raw_response; current_skill_id=""; goal_store.apply(updates); reason=why if why!="" else "I am deciding what to do."; plan_executor.begin(plan,reason); status="acting"; _record_history("plan_started",plan_executor.plan_id,"",reason); _run_plan_step()

func _on_skill_ready(skill_id:String, why:String, updates:Dictionary, latency_ms:int, raw_response:String)->void:
	last_latency_ms=latency_ms; last_response=raw_response
	var skill:=skill_store.get_skill(skill_id)
	if skill.is_empty() or skill.status!="active": _fallback("Unknown or inactive skill"); return
	var expanded:=SkillExecutor.expand(skill,room_state)
	if expanded.is_empty(): skill_store.mark_used(skill_id,false); _fallback("Skill target resolution failed"); return
	goal_store.apply(updates); current_skill_id=skill_id; reason=why if why!="" else skill.description; plan_executor.begin(expanded,reason); status="acting"; _run_plan_step()

func _run_plan_step()->void:
	if not plan_executor.active:return
	var step:=plan_executor.current(); var resident_data={"current_cell":resident_state.current_cell,"held_item_id":resident_state.held_item_id}
	var checked:=PrimitiveToolValidator.validate(step,room_state,room_state.grid,resident_data,room_state.items)
	if not bool(checked.get("ok",false)):
		_abort_plan(str(checked.get("error","tool rejected"))); return
	var tool:=str(step.get("tool","")); var step_args:Dictionary=step.get("args",{}); var target:=str(step_args.get("target",""))
	if tool=="move_near":
		if not _begin_plan_move(target): _abort_plan("target_unreachable")
		return
	if tool=="move_to":
		var args:Dictionary=step.get("args",{}); if not _begin_plan_move_cell(Vector2i(int(args.x),int(args.y))): _abort_plan("destination_unreachable")
		return
	var result:=PrimitiveToolExecutor.execute(step,room_state,resident_state,needs_model); _complete_plan_step(result)

func _begin_plan_move(object_id:String)->bool:
	if not room_state.objects.has(object_id):return false
	var cells:Array=room_state.objects[object_id].get("interaction_cells",[]); if cells.is_empty():return false
	return _begin_plan_move_cell(cells[0])

func _begin_plan_move_cell(destination:Vector2i)->bool:
	if not resident_movement.begin(room_state.grid,resident_state.current_cell,destination,room_state.blocked_cells()):return false
	plan_moving=true; status="moving"; return true

func _complete_plan_step(result:Dictionary={"ok":true,"result":"completed"})->void:
	var done:=plan_executor.advance(result)
	if done:
		plan_history.add(plan_executor.plan_id,plan_executor.reason,plan_executor.plan,plan_executor.results,true,clock.text(),clock.text())
		if current_skill_id!="": skill_store.mark_used(current_skill_id,true)
		skill_store.learn(plan_history.entries,room_state)
		memory_store.add(clock.text(),"plan", "I followed a plan: %s." % ", ".join(plan_executor.plan.map(func(step): return str(step.get("tool","")))),"completed",0.55,[],needs_model.values)
		_record_history("plan_completed",plan_executor.plan_id,"",reason); status="idle"; decision_cooldown=0.5; _save_game()
	else:
		status="acting"; _run_plan_step()

func _abort_plan(failure_reason:String)->void:
	plan_executor.abort({"ok":false,"error":failure_reason})
	plan_history.add(plan_executor.plan_id,plan_executor.reason,plan_executor.plan,plan_executor.results,false,clock.text(),clock.text(),"aborted",failure_reason)
	if current_skill_id!="": skill_store.mark_used(current_skill_id,false)
	current_skill_id=""; validation_error=failure_reason; status="idle"; decision_cooldown=0.5; _save_game()

func _on_decision_failed(error_message: String, latency_ms: int, raw_response: String) -> void:
	last_latency_ms = latency_ms
	last_response = raw_response
	_fallback(error_message)

func _start_action(id: String, target: String, why: String) -> void:
	reason = why if why != "" else str(ActionCatalog.DEFINITIONS.get(id,{}).get("display_name",id))
	var started := action_executor.begin(id,target,reason,room_state,needs_model,person_pos)
	if str(started.get("event","")) == "action_failed":
		_fallback(str(started.get("reason","Action failed")))
		return
	status = action_executor.state_name()
	_record_history("queued",id,target,reason)

func _finish_action() -> void:
	var id := action_executor.action_id
	var target := action_executor.target_id
	var result := action_executor.apply_completion(room_state,needs_model)
	if not bool(result.get("ok",false)):
		validation_error = str(result.get("reason","Action completion failed"))
		status = "idle"
		action_executor.reset()
		return
	var before: Dictionary = result.get("before_needs",{})
	var after: Dictionary = result.get("after_needs",{})
	var improvement := 0.0
	for key in ["boredom","stress","discomfort","loneliness"]:
		improvement += float(before.get(key,0.0)) - float(after.get(key,0.0))
	preferences.record(id,clamp(improvement / 350.0,-0.05,0.05),int(clock.snapshot().get("hour",0)))
	var memory_summary := _memory_summary(id,before,after)
	memory_store.add(clock.text(),id,memory_summary,"completed",_memory_salience(before,after),[target] if target != "" else [],before)
	if id == "write_diary":
		var text := str(pending_diary_text).strip_edges() if pending_diary_text != null else reason
		if text == "": text = reason
		diary.push_front({"time":clock.text(),"text":text.left(500)})
		if diary.size() > 60: diary.resize(60)
	_record_history("completed",id,target,reason)
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
	var severe_toilet := float(needs_model.values.get("toilet_need",0.0)) >= 98.0 and action_executor.action_id != "use_toilet"
	var severe_discomfort := float(needs_model.values.get("discomfort",0.0)) >= 98.0
	if severe_thirst or severe_toilet or severe_discomfort:
		var interrupted := action_executor.interrupt("A critical physical need interrupted the activity.")
		if bool(interrupted.get("ok",false)):
			_record_history("interrupted",action_executor.action_id,action_executor.target_id,str(interrupted.get("reason","")))
			action_executor.reset()
			status = "idle"
			decision_cooldown = 0.25

func _fallback(message: String) -> void:
	validation_error = message
	reason = "%s; I will wait." % message
	if action_executor.is_active():
		action_executor.interrupt(message)
	action_executor.reset()
	var result := action_executor.begin("wait","",reason,room_state,needs_model,person_pos)
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
		return "I %s and it noticeably eased my %s." % [name,strongest.replace("_need","")]
	return "I %s." % name

func _memory_salience(before: Dictionary, after: Dictionary) -> float:
	var largest := 0.0
	for key in before:
		largest = max(largest,abs(float(before.get(key,0.0)) - float(after.get(key,0.0))))
	return clamp(0.35 + largest / 100.0,0.35,0.9)

func _record_history(event: String, action: String, target: String, why: String) -> void:
	decision_history.push_front({"time":clock.text(),"event":event,"action":action,"target":target,"reason":why})
	if decision_history.size() > 50: decision_history.resize(50)

func _prompt() -> String:
	var file := FileAccess.open("res://ai/prompts/resident_system_prompt.txt",FileAccess.READ)
	return file.get_as_text() if file else "Choose one available action and return JSON only."

func _config() -> Dictionary:
	if FileAccess.file_exists("user://one_room_config.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://one_room_config.json"))
		if parsed is Dictionary: return parsed
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
		"resident_state":resident_state.serialize(),
		"plan_history":plan_history.serialize(),
		"skills":skill_store.serialize(),
		"resident_position":[person_pos.x,person_pos.y]
	})

func _load_game() -> void:
	var data := SaveManager.load_state()
	if data.is_empty(): return
	clock.total_minutes = float(data.get("sim_minutes",480.0))
	var loaded_needs = data.get("needs",{})
	if loaded_needs is Dictionary:
		for key in needs_model.values:
			if loaded_needs.has(key): needs_model.values[key] = float(loaded_needs[key])
	var room = data.get("room",{})
	if room is Dictionary:
		var loaded_resources = room.get("resources",{})
		if loaded_resources is Dictionary:
			for key in room_state.resources:
				if loaded_resources.has(key): room_state.resources[key] = loaded_resources[key]
		room_state.cleanliness = float(room.get("cleanliness",82.0))
		room_state.light_on = bool(room.get("light_on",true))
	memory_store.load_state(data.get("memory_store",{}))
	goal_store.load_state(data.get("goal_store",{}))
	preferences.load_state(data.get("preferences",{}))
	var loaded_diary = data.get("diary",[])
	if loaded_diary is Array: diary = loaded_diary.duplicate(true)
	var loaded_history = data.get("decision_history",[])
	if loaded_history is Array: decision_history = loaded_history.duplicate(true)
	var p = data.get("resident_position",[420.0,390.0])
	if p is Array and p.size() >= 2: person_pos = Vector2(float(p[0]),float(p[1]))
	resident_state.load_state(data.get("resident_state",{})); resident_state.render_position=person_pos
	plan_history.load_state(data.get("plan_history",[]))
	skill_store.load_state(data.get("skills",{}))

func _add_room_art() -> void:
	var texture := load("res://assets/room_background.png") as Texture2D
	if texture == null: return
	var room_art := TextureRect.new()
	room_art.texture = texture
	room_art.position = Vector2(40,40)
	room_art.size = Vector2(820,600)
	room_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_art.z_index = -1
	add_child(room_art)

func _build_ui() -> void:
	labels["time"] = _label(Vector2(920,20),"",23)
	labels["action"] = _label(Vector2(920,56),"",18)
	labels["reason"] = _label(Vector2(920,88),"",14); labels["reason"].size = Vector2(345,62)
	labels["panel"] = _label(Vector2(920,155),"",13); labels["panel"].size = Vector2(345,345)
	labels["history"] = _label(Vector2(920,505),"",12); labels["history"].size = Vector2(345,125)
	var save := Button.new(); save.text = "Save"; save.position = Vector2(920,660); save.pressed.connect(_save_game); add_child(save)
	var pause := Button.new(); pause.text = "Pause"; pause.position = Vector2(985,660); pause.pressed.connect(func(): speed = 0.0 if speed > 0.0 else 1.0); add_child(pause)
	var speeds := OptionButton.new(); speeds.position = Vector2(1060,660)
	for x in [1,2,4,8]: speeds.add_item("%sx" % x)
	speeds.item_selected.connect(func(i): speed = pow(2.0,i)); add_child(speeds)
	var debug_button := Button.new(); debug_button.text = "Debug"; debug_button.position = Vector2(1160,660); debug_button.pressed.connect(_toggle_debug); add_child(debug_button)
	debug_panel = Panel.new(); debug_panel.position = Vector2(35,35); debug_panel.size = Vector2(835,610); debug_panel.visible = false; debug_panel.z_index = 20; add_child(debug_panel)
	debug_label = Label.new(); debug_label.position = Vector2(14,14); debug_label.size = Vector2(805,575); debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; debug_label.add_theme_font_size_override("font_size",12); debug_panel.add_child(debug_label)

func _toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible

func _label(pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new(); label.position = pos; label.text = text; label.add_theme_font_size_override("font_size",font_size); add_child(label); return label

func _update_ui() -> void:
	if not labels.has("time"): return
	labels["time"].text = clock.text()
	labels["action"].text = "Action: %s (%s)" % [action_executor.action_id if action_executor.action_id != "" else "idle",status]
	labels["reason"].text = "Reason: " + reason
	var text := "NEEDS\n"
	for key in needs_model.values: text += "%s: %3d\n" % [key,int(needs_model.values[key])]
	text += "\nROOM  clean:%d  food:%d  water:%d  trash:%d\n" % [int(room_state.cleanliness),int(room_state.resources.get("simple_food",0)),int(room_state.resources.get("water",0)),int(room_state.resources.get("trash",0))]
	text += "\nGOALS\n" + ("none\n" if goal_store.active_texts().is_empty() else "\n".join(goal_store.active_texts()) + "\n")
	text += "\nPREFERENCES\n"
	var pref_summary := preferences.summary()
	for key in pref_summary: text += "%s: %.2f\n" % [key,float(pref_summary[key])]
	text += "\nLLM: %d ms" % last_latency_ms
	labels["panel"].text = text
	var history_text := "RECENT\n"
	for item in decision_history.slice(0,min(5,decision_history.size())):
		history_text += "%s %s: %s\n" % [str(item.get("time","")),str(item.get("event","")),str(item.get("action",""))]
	labels["history"].text = history_text
	if debug_panel != null and debug_panel.visible:
		var debug_text := "STATUS: %s\nVALIDATION: %s\nRETRIEVED: %s\n\nLAST OBSERVATION\n%s\n\nRAW RESPONSE\n%s" % [status,validation_error,JSON.stringify(last_retrieved_memory_ids),last_observation.left(4500),last_response.left(2500)]
		debug_label.text = debug_text

func _draw() -> void:
	draw_rect(Rect2(0,0,900,720),Color("#263238"))
	for id in room_state.objects:
		var p: Vector2 = room_state.objects[id].position
		draw_circle(p,8,Color("#8d6e63"))
	var resident_color := Color("#90caf9") if status == "thinking" else Color("#4fc3f7")
	draw_circle(person_pos,24,resident_color)
	if status == "acting": draw_circle(person_pos+Vector2(0,-34),6,Color("#fff176"))
	draw_string(ThemeDB.fallback_font,person_pos+Vector2(-30,-32),"Resident",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#102027"))
