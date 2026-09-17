extends Node2D

const DEFAULT_CONFIG := {"base_url":"http://127.0.0.1:8000/v1","model":"Ornith-1.5-9B","temperature":0.3,"timeout_ms":30000,"max_tokens":256}

var speed := 1.0
var status := "idle"
var reason := "The room is quiet."
var intention := ""
var diary: Array = []
var decision_history: Array = []
var last_latency_ms := 0
var last_observation := ""
var last_response := ""
var validation_error := ""
var decision_cooldown := 0.0
var move_speed := 180.0
var labels := {}
var last_retrieved_memory_ids: Array = []
var debug_panel: Panel
var debug_label: Label
var progress_bar: ProgressBar
var config_data: Dictionary = DEFAULT_CONFIG.duplicate(true)
var save_status := "Auto-save on"
var llm_status := "Ornith: Offline"

var clock := WorldClock.new()
var room_state := RoomState.new()
var needs_model := ResidentNeeds.new()
var memory_store := MemoryStore.new()
var goal_store := GoalStore.new()
var preferences := PreferenceStore.new()
var habit_store := HabitStore.new()
var recent_activity_history:Array=[]
var activity_executor := ActivityExecutor.new()
var harness: ResidentHarness
var resident_state := ResidentState.new()
var resident_movement := ResidentMovement.new()
var plan_executor := PlanExecutor.new()
var plan_moving := false
var plan_history := PlanHistory.new()
var skill_store := SkillStore.new()
var current_skill_id := ""
var diagnostics:Dictionary={"total_decisions":0,"plans_started":0,"plans_completed":0,"plans_aborted":0,"activities_started":0,"activities_completed":0,"activities_failed":0,"activities_interrupted":0,"activity_types_requested":{},"primitive_only_plans":0,"plans_with_activity":0,"activity_interruption_reasons":{},"skills_invoked":0,"skills_completed":0,"skills_failed":0,"fallback_waits":0,"semantic_rejections":0,"schema_repair_attempts":0,"semantic_repair_attempts":0,"repair_recovered":0,"repair_failed":0,"tool_frequency":{}}
var decision_revision := 0

func _ready() -> void:
	config_data = _config()
	_load_game()
	harness = ResidentHarness.new()
	add_child(harness)
	harness.decision_failed.connect(_on_decision_failed)
	harness.repair_attempted.connect(func(kind): diagnostics["%s_repair_attempts"%kind]=int(diagnostics.get("%s_repair_attempts"%kind,0))+1)
	harness.repair_recovered.connect(func(): diagnostics["repair_recovered"]+=1)
	harness.repair_failed.connect(func(): diagnostics["repair_failed"]+=1)
	harness.plan_ready.connect(_on_plan_ready)
	harness.skill_ready.connect(_on_skill_ready)
	resident_state.render_position = _cell_to_position(resident_state.current_cell)
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
	if activity_executor.is_active() and speed > 0.0:
		var activity_update:=activity_executor.update(elapsed_minutes)
		status=str(activity_update.get("state",status))
		if bool(activity_update.get("completed",false)):_finish_activity()
		else:_check_interrupt()
	if plan_executor.active and plan_moving and speed > 0.0:
		if resident_movement.update(resident_state,delta,move_speed):
			plan_moving = false
			_complete_plan_step()
	elif plan_executor.active and not plan_moving and not activity_executor.is_active():
		_run_plan_step()
	decision_cooldown = max(0.0,decision_cooldown - delta)
	if status == "idle" and decision_cooldown <= 0.0 and speed > 0.0:
		_request_decision()
	_update_ui()
	queue_redraw()

func _request_decision() -> void:
	if harness == null or harness.is_busy() or status == "thinking":
		return
	var candidates:Array=[]
	diagnostics.total_decisions+=1
	var action_ids: Array = []
	for candidate in PrimitiveToolCatalog.available(room_state,{"current_cell":resident_state.current_cell,"held_item_id":resident_state.held_item_id}): action_ids.append(str(candidate.get("tool","")))
	var strong_needs: Array = []
	for key in needs_model.values:
		if float(needs_model.values.get(key,0.0)) >= 70.0:
			strong_needs.append(str(key))
	var memories := memory_store.retrieve(action_ids,goal_store.active_texts(),6,"",strong_needs)
	last_retrieved_memory_ids = []
	for memory in memories:
		last_retrieved_memory_ids.append(str(memory.get("id","")))
	var available_skills:=skill_store.relevant(room_state,resident_state.held_item_id,needs_model.values,resident_state)
	var observation := ObservationBuilder.build(clock,needs_model,room_state,resident_state.render_position,"idle",memories,goal_store.active_texts(),preferences.summary(),candidates,{"habits":habit_store.summary()},{"cell":resident_state.current_cell,"posture":resident_state.posture,"held_item_id":resident_state.held_item_id},available_skills,_recent_behavior())
	last_observation = JSON.stringify(observation)
	status = "thinking"
	validation_error = ""
	decision_revision=_state_revision()
	if not harness.request_decision(observation,candidates,room_state,goal_store.active_texts(),_config(),_prompt(),resident_state.snapshot(),needs_model.snapshot()):
		_fallback("LLM request could not start")

func _on_plan_ready(plan:Array, why:String, updates:Dictionary, latency_ms:int, raw_response:String)->void:
	last_latency_ms=latency_ms; last_response=raw_response; llm_status="Ornith: Connected"; intention=why.left(160); _accept_plan(plan,why,updates,"")

func _on_skill_ready(skill_id:String, why:String, updates:Dictionary, latency_ms:int, raw_response:String)->void:
	last_latency_ms=latency_ms; last_response=raw_response; intention=why.left(160)
	var skill:=skill_store.get_skill(skill_id)
	if skill.is_empty() or skill.status!="active": _fallback("Unknown or inactive skill"); return
	var expanded:=SkillExecutor.expand(skill,room_state)
	if expanded.is_empty(): skill_store.mark_used(skill_id,false); diagnostics.skills_failed+=1; _fallback("Skill target resolution failed"); return
	_accept_plan(expanded,why if why!="" else skill.description,updates,skill_id)

func _accept_plan(plan:Array, why:String, updates:Dictionary, skill_id:String)->void:
	if _state_revision()!=decision_revision: _fallback("State changed while deciding"); return
	var goal_result:=ActionValidator.validate_goal_updates(updates,goal_store.active_texts())
	if not bool(goal_result.get("ok",false)): _fallback("Invalid goal updates"); return
	var preflight:=PlanPreflight.validate(plan,room_state,resident_state,needs_model)
	if not bool(preflight.get("ok",false)):
		diagnostics.semantic_rejections+=1; _fallback("Plan preflight failed: %s"%str(preflight.get("error","unknown"))); return
	goal_store.apply(goal_result.get("updates",{}),clock.text()); current_skill_id=skill_id; if skill_id!="":diagnostics.skills_invoked+=1
	if skill_id=="":
		var has_activity:=false
		for plan_step in plan:
			if ActivityCatalog.DEFINITIONS.has(str(plan_step.get("tool",""))): has_activity=true; break
		diagnostics["plans_with_activity" if has_activity else "primitive_only_plans"]+=1
	reason=why if why!="" else "I am deciding what to do."; plan_executor.begin(plan,reason); diagnostics.plans_started+=1; status="acting"; _record_history("plan_started",plan_executor.plan_id,"",reason); _run_plan_step()

func _run_plan_step()->void:
	if not plan_executor.active:return
	var step:=plan_executor.current(); var resident_data={"current_cell":resident_state.current_cell,"held_item_id":resident_state.held_item_id}
	var checked:=PrimitiveToolValidator.validate(step,room_state,room_state.grid,resident_data,room_state.items)
	if not bool(checked.get("ok",false)):
		diagnostics.semantic_rejections+=1; _abort_plan(str(checked.get("error","tool rejected"))); return
	var tool:=str(step.get("tool","")); var step_args:Dictionary=step.get("args",{}); var target:=str(step_args.get("target",""))
	var frequency:Dictionary=diagnostics.get("tool_frequency",{}); frequency[tool]=int(frequency.get(tool,0))+1; diagnostics["tool_frequency"]=frequency
	if tool=="move_near":
		if not _begin_plan_move(target): _abort_plan("target_unreachable")
		return
	if tool=="move_to":
		var args:Dictionary=step.get("args",{}); if not _begin_plan_move_cell(Vector2i(int(args.x),int(args.y))): _abort_plan("destination_unreachable")
		return
	if ActivityCatalog.DEFINITIONS.has(tool):
		var requested:Dictionary=diagnostics.get("activity_types_requested",{}); requested[tool]=int(requested.get(tool,0))+1; diagnostics["activity_types_requested"]=requested
		var started:=activity_executor.begin(tool,target,reason,room_state,needs_model,resident_state,_recent_activity_count(tool),float(preferences.values.get(tool,0.0)))
		if not bool(started.get("ok",false)): diagnostics.activities_failed+=1; _abort_plan(str(started.get("error","activity_failed"))); return
		diagnostics.activities_started+=1
		status=activity_executor.state_name(); return
	var result:=PrimitiveToolExecutor.execute(step,room_state,resident_state,needs_model)
	if not bool(result.get("ok",false)):_abort_plan(str(result.get("error","primitive_failed"))); return
	_complete_plan_step(result)

func _begin_plan_move(object_id:String)->bool:
	var resolved:=InteractionResolver.nearest_cell(room_state,object_id,resident_state.current_cell)
	if not bool(resolved.get("ok",false)):return false
	return _begin_plan_move_cell(resolved.cell)

func _begin_plan_move_cell(destination:Vector2i)->bool:
	if not resident_movement.begin(room_state.grid,resident_state.current_cell,destination,room_state.blocked_cells()):return false
	resident_state.next_cell=destination; plan_moving=true; status="moving"; return true

func _complete_plan_step(result:Dictionary={"ok":true,"result":"completed"})->void:
	var done:=plan_executor.advance(result)
	if done:
		diagnostics.plans_completed+=1
		plan_history.add(plan_executor.plan_id,plan_executor.reason,plan_executor.plan,plan_executor.results,true,clock.text(),clock.text())
		if current_skill_id!="": skill_store.mark_used(current_skill_id,true); diagnostics.skills_completed+=1
		skill_store.learn(plan_history.entries,room_state)
		_record_history("plan_completed",plan_executor.plan_id,"",reason); status="idle"; decision_cooldown=0.5; _save_game()
	else:
		status="acting"; _run_plan_step()

func _finish_activity()->void:
	var id:=activity_executor.activity_id; var target:=activity_executor.target_id
	var diary_text:=reason if id=="write_diary" else ""
	var result:=activity_executor.complete(room_state,needs_model,resident_state,diary_text)
	if not bool(result.get("ok",false)): diagnostics.activities_failed+=1; _abort_plan(str(result.get("error","activity_failed"))); return
	var before:Dictionary=result.get("before_needs",{}); var after:Dictionary=result.get("after_needs",{}); var improvement:=0.0
	for key in ["boredom","stress","discomfort","loneliness"]:improvement+=float(before.get(key,0.0))-float(after.get(key,0.0))
	var event:=LifeEvent.activity_completed(clock.text(),id,target,activity_executor.started_cell,float(result.get("duration_minutes",0.0)),before,after,{"posture":resident_state.posture,"posture_target":resident_state.posture_target_id,"held_item":resident_state.held_item_id,"time_of_day":clock.snapshot().get("hour",0)},str(result.get("result","completed")))
	event["time_hour"]=int(clock.snapshot().get("hour",0)); event["salience"]=clamp(0.35+abs(improvement)/100.0,0.35,0.9)
	preferences.record_life_event(event)
	recent_activity_history.push_front(id)
	if recent_activity_history.size()>16: recent_activity_history.resize(16)
	habit_store.record(event)
	memory_store.add_life_event(event)
	if id=="write_diary":
		diary.push_front({"time":clock.text(),"text":str(result.get("diary_text",diary_text)).left(500)})
		if diary.size()>60:diary.resize(60)
	diagnostics.activities_completed=int(diagnostics.get("activities_completed",0))+1
	_record_history("activity_completed",id,target,reason)
	DecisionLogger.append({"time":clock.text(),"action":id,"activity":id,"target":target,"reason":reason,"retrieved_memories":last_retrieved_memory_ids,"goals":goal_store.active_texts(),"latency_ms":last_latency_ms,"validation":"valid","result":"completed"})
	_complete_plan_step(result)

func _abort_plan(failure_reason:String)->void:
	if activity_executor.is_active():activity_executor.interrupt(failure_reason); activity_executor.reset()
	plan_executor.abort({"ok":false,"error":failure_reason})
	diagnostics.plans_aborted+=1
	plan_history.add(plan_executor.plan_id,plan_executor.reason,plan_executor.plan,plan_executor.results,false,clock.text(),clock.text(),"aborted",failure_reason)
	if current_skill_id!="": skill_store.mark_used(current_skill_id,false); diagnostics.skills_failed+=1
	current_skill_id=""; validation_error=failure_reason; status="idle"; decision_cooldown=0.5; _save_game()

func _on_decision_failed(error_message: String, latency_ms: int, raw_response: String) -> void:
	last_latency_ms = latency_ms
	last_response = raw_response
	var lower_error:=error_message.to_lower()
	if "timeout" in lower_error: llm_status="Ornith: Timeout"
	elif "transport" in lower_error or "request error" in lower_error: llm_status="Ornith: Offline"
	else: llm_status="Ornith: Connected - invalid response"
	reason = "Resident is waiting for the local AI server."
	_fallback(error_message)

func _check_interrupt() -> void:
	if not activity_executor.is_active():
		return
	var severe_thirst := float(needs_model.values.get("thirst",0.0)) >= 98.0 and activity_executor.activity_id != "drink"
	var severe_toilet := float(needs_model.values.get("toilet_need",0.0)) >= 98.0 and activity_executor.activity_id != "use_toilet"
	var severe_sleep := float(needs_model.values.get("sleepiness",0.0)) >= 99.0 and activity_executor.activity_id != "sleep"
	var severe_discomfort := float(needs_model.values.get("discomfort",0.0)) >= 98.0
	if severe_thirst or severe_toilet or severe_sleep or severe_discomfort:
		var interruption_reason:="severe_need"
		var reasons:Dictionary=diagnostics.get("activity_interruption_reasons",{}); reasons[interruption_reason]=int(reasons.get(interruption_reason,0))+1; diagnostics["activity_interruption_reasons"]=reasons
		var interrupted := activity_executor.interrupt("A critical physical need interrupted the activity.")
		if bool(interrupted.get("ok",false)):
			diagnostics.activities_interrupted+=1
			_record_history("interrupted",activity_executor.activity_id,activity_executor.target_id,str(interrupted.get("reason",""))); _abort_plan("activity_interrupted")

func _fallback(message: String) -> void:
	diagnostics.fallback_waits+=1
	var category:="fallback_other"; var lower:=message.to_lower()
	if "schema" in lower or "json" in lower: category="fallback_schema"
	elif "semantic" in lower or "preflight" in lower or "target" in lower or "tool" in lower: category="fallback_semantic"
	elif "repair" in lower: category="fallback_repair_failed"
	elif "transport" in lower or "request" in lower or "offline" in lower: category="fallback_transport"
	diagnostics[category]=int(diagnostics.get(category,0))+1
	validation_error = message
	reason = "%s; I will wait." % message
	if plan_executor.active:_abort_plan(message)
	plan_executor.begin([{"tool":"wait","args":{}}],reason); status="acting"; decision_cooldown=2.0; _run_plan_step()

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
	decision_history.push_front({"time":clock.text(),"event":event,"action":action,"target":target,"reason":why,"text":_life_feed_text(event,action,target)})
	if decision_history.size() > 50: decision_history.resize(50)

func _life_feed_text(event:String,action:String,target:String)->String:
	if event=="activity_completed": return "%s completed%s."%[ActivityCatalog.get_definition(action).get("activity_label",action),"" if target=="" else " near "+target]
	if event=="plan_completed": return "Finished deciding what to do."
	if event=="plan_started": return "Started moving or acting."
	if event=="interrupted": return "Stopped %s."%action
	return action

func _recent_activity_count(activity:String)->int:
	var count:=0
	for item in recent_activity_history:
		if str(item)==activity: count+=1
		else: break
	return count

func _prompt() -> String:
	var file := FileAccess.open("res://ai/prompts/resident_system_prompt.txt",FileAccess.READ)
	return file.get_as_text() if file else "Choose one available action and return JSON only."

func _config() -> Dictionary:
	if FileAccess.file_exists("user://one_room_config.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://one_room_config.json"))
		if parsed is Dictionary: return parsed
	return DEFAULT_CONFIG

func _save_game() -> void:
	var saved:=SaveManager.save_state({
		"sim_minutes":clock.total_minutes,
		"needs":needs_model.values,
		"room":room_state.serialize(),
		"memory_store":memory_store.serialize(),
		"goal_store":goal_store.serialize(),
		"preferences":preferences.serialize(),
		"habits":habit_store.serialize(),
		"recent_activity_history":recent_activity_history.duplicate(),
		"diary":diary,
		"decision_history":decision_history,
		"resident_state":resident_state.serialize(),
		"plan_history":plan_history.serialize(),
		"skills":skill_store.serialize(),
		"diagnostics":diagnostics,
		"resident_position":[resident_state.render_position.x,resident_state.render_position.y]
	})
	save_status = "Saved" if saved else "Save failed"

func _load_game() -> void:
	var data := SaveManager.load_state()
	if data.is_empty(): return
	clock.total_minutes = float(data.get("sim_minutes",480.0))
	var loaded_needs = data.get("needs",{})
	if loaded_needs is Dictionary:
		for key in needs_model.values:
			if loaded_needs.has(key): needs_model.values[key] = float(loaded_needs[key])
	var room = data.get("room",{})
	if room is Dictionary: room_state.load_state(room)
	memory_store.load_state(data.get("memory_store",{}))
	goal_store.load_state(data.get("goal_store",{}))
	preferences.load_state(data.get("preferences",{}))
	habit_store.load_state(data.get("habits",{}))
	recent_activity_history=data.get("recent_activity_history",[]) if data.get("recent_activity_history",[]) is Array else []
	if recent_activity_history.size()>16:recent_activity_history.resize(16)
	var loaded_diary = data.get("diary",[])
	if loaded_diary is Array: diary = loaded_diary.duplicate(true)
	var loaded_history = data.get("decision_history",[])
	if loaded_history is Array: decision_history = loaded_history.duplicate(true)
	resident_state.load_state(data.get("resident_state",{})); resident_state.render_position=_cell_to_position(resident_state.current_cell)
	plan_history.load_state(data.get("plan_history",[]))
	skill_store.load_state(data.get("skills",{}))
	room_state.repair_integrity(resident_state)
	var loaded_diagnostics=data.get("diagnostics",{})
	if loaded_diagnostics is Dictionary:
		for key in loaded_diagnostics: diagnostics[key]=loaded_diagnostics[key]

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
	labels["connection"] = _label(Vector2(920,130),"",13)
	progress_bar = ProgressBar.new(); progress_bar.position=Vector2(920,430); progress_bar.size=Vector2(345,22); progress_bar.visible=false; add_child(progress_bar)
	var save := Button.new(); save.text = "Save"; save.position = Vector2(920,660); save.pressed.connect(_save_game); add_child(save)
	var pause := Button.new(); pause.text = "Pause"; pause.position = Vector2(985,660); pause.pressed.connect(func(): speed = 0.0 if speed > 0.0 else 1.0); add_child(pause)
	var speeds := OptionButton.new(); speeds.position = Vector2(1060,660)
	for x in [1,2,4,8]: speeds.add_item("%sx" % x)
	speeds.item_selected.connect(func(i): speed = pow(2.0,i)); add_child(speeds)
	var debug_button := Button.new(); debug_button.text = "Debug"; debug_button.position = Vector2(1160,660); debug_button.pressed.connect(_toggle_debug); add_child(debug_button)
	var diary_button := Button.new(); diary_button.text = "Diary"; diary_button.position = Vector2(920,690); diary_button.pressed.connect(_show_diary); add_child(diary_button)
	var settings_button := Button.new(); settings_button.text = "Settings"; settings_button.position = Vector2(985,690); settings_button.pressed.connect(_show_settings); add_child(settings_button)
	var reset_button := Button.new(); reset_button.text = "New Life"; reset_button.position = Vector2(1070,690); reset_button.pressed.connect(_confirm_reset); add_child(reset_button)
	debug_panel = Panel.new(); debug_panel.position = Vector2(35,35); debug_panel.size = Vector2(835,610); debug_panel.visible = false; debug_panel.z_index = 20; add_child(debug_panel)
	debug_label = Label.new(); debug_label.position = Vector2(14,14); debug_label.size = Vector2(805,575); debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; debug_label.add_theme_font_size_override("font_size",12); debug_panel.add_child(debug_label)

func _toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible

func _label(pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new(); label.position = pos; label.text = text; label.add_theme_font_size_override("font_size",font_size); add_child(label); return label

func _update_ui() -> void:
	if not labels.has("time"): return
	labels["time"].text = clock.text()
	labels["action"].text = "Activity: %s (%s)" % [activity_executor.activity_id if activity_executor.activity_id != "" else "idle",status]
	labels["reason"].text = "Intention: " + (intention if intention!="" else reason)
	labels["connection"].text = llm_status + "   " + save_status
	if progress_bar != null:
		progress_bar.visible = activity_executor.is_active()
		var definition:=ActivityCatalog.get_definition(activity_executor.activity_id)
		progress_bar.max_value=float(definition.get("duration_minutes",1)); progress_bar.value=progress_bar.max_value-activity_executor.remaining_minutes
	var text := "NEEDS\n"
	for key in needs_model.values: text += "%s: %3d\n" % [key,int(needs_model.values[key])]
	text += "\nROOM  clean:%d  food:%d  water:%d  trash:%d\n" % [int(room_state.cleanliness),room_state.item_quantity("simple_food"),int(room_state.resources.get("water",0)),int(room_state.resources.get("trash",0))]
	text += "\nGOALS\n" + ("none\n" if goal_store.active_texts().is_empty() else "\n".join(goal_store.active_texts()) + "\n")
	text += "\nPREFERENCES\n"
	var pref_summary := preferences.summary()
	for key in pref_summary: text += "%s: %.2f\n" % [key,float(pref_summary[key])]
	text += "\nACTIVITY: %s\nCELL: [%d,%d]  POSTURE: %s\nHELD: %s\nLLM: %d ms" % [_activity_text(),resident_state.current_cell.x,resident_state.current_cell.y,resident_state.posture,resident_state.held_item_id if resident_state.held_item_id!="" else "none",last_latency_ms]
	labels["panel"].text = text
	var history_text := "RECENT\n"
	for item in decision_history.slice(0,min(5,decision_history.size())):
		history_text += "%s %s\n" % [str(item.get("time","")),str(item.get("text",item.get("action","")))]
	labels["history"].text = history_text
	if debug_panel != null and debug_panel.visible:
		var debug_text := "STATUS: %s\nVALIDATION: %s\nRETRIEVED: %s\nDIAGNOSTICS: %s\nMEMORIES: %d  PLAN HISTORY: %d\n\nLAST OBSERVATION\n%s\n\nRAW RESPONSE\n%s" % [status,validation_error,JSON.stringify(last_retrieved_memory_ids),JSON.stringify(diagnostics),memory_store.entries.size(),plan_history.entries.size(),last_observation.left(4500),last_response.left(2500)]
		debug_label.text = debug_text

func _draw() -> void:
	draw_rect(Rect2(0,0,900,720),Color("#263238"))
	for id in room_state.objects:
		var object:Dictionary=room_state.objects[id]; var p:Vector2=object.position
		if object.has("origin_cell"): p=RoomVisualAdapter.cell_to_position(object.origin_cell)
		if bool(object.get("movable",false)): draw_rect(Rect2(p-Vector2(18,18),Vector2(36,36)),Color("#bcaaa4")); draw_string(ThemeDB.fallback_font,p-Vector2(14,24),str(id),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
		else: draw_circle(p,8,Color("#8d6e63"))
	var resident_color := Color("#90caf9") if status == "thinking" else Color("#4fc3f7")
	var render_position:=resident_state.render_position
	if resident_state.posture=="lying": draw_rect(Rect2(render_position-Vector2(30,12),Vector2(60,24)),resident_color)
	else: draw_circle(render_position,24,resident_color)
	if resident_state.held_item_id!="": draw_circle(render_position+Vector2(30,0),7,Color("#ffcc80")); draw_string(ThemeDB.fallback_font,render_position+Vector2(38,5),resident_state.held_item_id,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
	if resident_state.posture=="sitting": draw_line(render_position+Vector2(-15,20),render_position+Vector2(15,20),Color("#37474f"),5)
	if status in ["acting","moving"]: draw_circle(render_position+Vector2(0,-34),6,Color("#fff176"))
	draw_string(ThemeDB.fallback_font,render_position+Vector2(-30,-32),"Resident",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#102027"))

func _activity_text()->String:
	if status=="moving":return "walking"
	if resident_state.posture=="lying":return "lying / sleeping"
	if resident_state.posture=="sitting":return "sitting"
	if activity_executor.activity_id!="":return str(ActivityCatalog.get_definition(activity_executor.activity_id).get("activity_label",activity_executor.activity_id))
	if plan_executor.active:return "performing primitive"
	return "waiting" if status=="idle" else status

func _cell_to_position(cell:Vector2i)->Vector2:
	return RoomVisualAdapter.cell_to_position(cell)

func _show_diary()->void:
	var dialog:=AcceptDialog.new(); dialog.title="Diary"; var text:=""
	for entry in diary.slice(0,min(8,diary.size())): text += "%s\n%s\n\n" % [entry.get("time",""),entry.get("text","")]
	if text=="": text="No diary entries yet."
	dialog.dialog_text=text; add_child(dialog); dialog.popup_centered(Vector2(460,360)); dialog.confirmed.connect(dialog.queue_free)

func _show_settings()->void:
	var dialog:=AcceptDialog.new(); dialog.title="Settings"; var box:=VBoxContainer.new(); var url:=LineEdit.new(); url.text=str(config_data.get("base_url",DEFAULT_CONFIG.base_url)); url.placeholder_text="LLM base URL"
	var model:=LineEdit.new(); model.text=str(config_data.get("model",DEFAULT_CONFIG.model)); model.placeholder_text="Model name"
	var auto:=CheckButton.new(); auto.text="Auto-save"; auto.button_pressed=bool(config_data.get("auto_save",true)); box.add_child(url);box.add_child(model);box.add_child(auto);dialog.add_child(box);add_child(dialog);dialog.confirmed.connect(func(): config_data["base_url"]=url.text;config_data["model"]=model.text;config_data["auto_save"]=auto.button_pressed;var f:=FileAccess.open("user://one_room_config.json",FileAccess.WRITE);if f:f.store_string(JSON.stringify(config_data));save_status="Auto-save on" if auto.button_pressed else "Auto-save off");dialog.popup_centered()

func _confirm_reset()->void:
	var dialog:=ConfirmationDialog.new(); dialog.title="Start a new life?";dialog.dialog_text="This will delete the current save.";add_child(dialog);dialog.confirmed.connect(func():DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH));get_tree().reload_current_scene());dialog.popup_centered()

func _state_revision()->int:
	return room_state.revision+resident_state.revision

func _recent_behavior()->Dictionary:
	if decision_history.size()<2:return {}
	var last:=str(decision_history[0].get("action","")); var count:=0
	for row in decision_history:
		if str(row.get("action",""))==last:count+=1
		else:break
	return {"repeated_pattern":last,"repeat_count":count} if count>=3 else {}
