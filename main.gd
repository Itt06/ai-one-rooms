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
var furniture_atlas: Texture2D
var resident_atlas: Texture2D
var resident_supplemental_atlas: Texture2D
var progress_bar: ProgressBar
var life_feed_label: Label
var personality_label: Label
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
var diagnostics:Dictionary={"total_decisions":0,"plans_started":0,"plans_completed":0,"plans_aborted":0,"activities_started":0,"activities_completed":0,"activities_failed":0,"activities_interrupted":0,"activity_types_requested":{},"activity_interruption_reasons":{},"activity_interruption_records":[],"primitive_only_plans":0,"plans_with_activity":0,"skills_invoked":0,"skills_completed":0,"skills_failed":0,"fallback_waits":0,"semantic_rejections":0,"critical_preflight_rejections":0,"schema_repair_attempts":0,"semantic_repair_attempts":0,"repair_recovered":0,"repair_failed":0,"food_consumed":0,"groceries_ordered":0,"trash_generated":0,"trash_removed":0,"cleaning_activities":0,"sleep_completed":0,"drink_completed":0,"toilet_completed":0,"last_drink_result":{},"last_successful_drink_time":"","tool_frequency":{}}
var decision_revision := 0

func _ready() -> void:
	furniture_atlas = load(RoomVisualAdapter.ATLAS_PATH) as Texture2D
	resident_atlas = load(ResidentVisualAdapter.ATLAS_PATH) as Texture2D
	resident_supplemental_atlas = load(ResidentVisualAdapter.SUPPLEMENTAL_PATH) as Texture2D
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
	_build_ui()
	queue_redraw()
	_request_decision()

func _process(delta: float) -> void:
	var elapsed_minutes := delta * speed * 2.0
	if status != "thinking" and speed > 0.0:
		clock.advance(delta,speed)
		var suppressed:Array=[]
		if activity_executor.is_active():
			var suppress_by_activity={"drink":["thirst"],"eat":["hunger"],"sleep":["sleepiness"],"take_shower":["hygiene_need"],"use_toilet":["toilet_need"],"clean":["discomfort"]}
			suppressed=suppress_by_activity.get(activity_executor.activity_id,[])
		needs_model.advance(elapsed_minutes,suppressed)
		room_state.advance(elapsed_minutes)
		if room_state.cleanliness < 40.0:
			needs_model.apply({"discomfort":elapsed_minutes * 0.001})
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
	var memories := memory_store.retrieve(action_ids,goal_store.active_texts(),6,"",strong_needs,_memory_topics(strong_needs))
	last_retrieved_memory_ids = []
	for memory in memories:
		last_retrieved_memory_ids.append(str(memory.get("id","")))
	var available_skills:=skill_store.relevant(room_state,resident_state.held_item_id,needs_model.values,resident_state,{"topics":_memory_topics(strong_needs),"strong_needs":strong_needs,"recent_actions":recent_activity_history.slice(0,6)})
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
		diagnostics.semantic_rejections+=1; var preflight_error:=str(preflight.get("error","unknown")); if preflight_error.begins_with("critical_"): diagnostics.critical_preflight_rejections=int(diagnostics.get("critical_preflight_rejections",0))+1; _fallback("Plan preflight failed: %s"%preflight_error); return
	goal_store.apply(goal_result.get("updates",{}),clock.text()); current_skill_id=skill_id; if skill_id!="":diagnostics.skills_invoked+=1
	if skill_id=="":
		var has_activity:=false
		for plan_step in plan:
			if ActivityCatalog.DEFINITIONS.has(str(plan_step.get("tool",""))): has_activity=true; break
		diagnostics["plans_with_activity" if has_activity else "primitive_only_plans"]+=1
	var public_reason:=why if why!="" else "I am deciding what to do."
	if not last_retrieved_memory_ids.is_empty():
		for memory in memory_store.entries:
			if str(memory.get("id",""))==str(last_retrieved_memory_ids[0]): public_reason += " %s" % ObserverContext.relevant_memory_note(memory); break
	reason=public_reason; plan_executor.begin(plan,reason); diagnostics.plans_started+=1; status="acting"; _record_history("plan_started",plan_executor.plan_id,"",reason); _run_plan_step()

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
	ResidentMovement.prepare_posture(resident_state)
	resident_state.next_cell=destination; plan_moving=true; status="moving"; return true

func _complete_plan_step(result:Dictionary={"ok":true,"result":"completed"})->void:
	var done:=plan_executor.advance(result)
	if done:
		diagnostics.plans_completed+=1
		plan_history.add(plan_executor.plan_id,plan_executor.reason,plan_executor.plan,plan_executor.results,true,clock.text(),clock.text())
		if current_skill_id!="": skill_store.mark_used(current_skill_id,true); diagnostics.skills_completed+=1
		var learned:=skill_store.learn(plan_history.entries,room_state)
		for skill_id in learned: _record_history("skill_learned",skill_id,"","Learned a reusable routine.")
		_record_history("plan_completed",plan_executor.plan_id,"",reason); status="idle"; decision_cooldown=0.5; _save_game()
	else:
		status="acting"; _run_plan_step()

func _finish_activity()->void:
	var id:=activity_executor.activity_id; var target:=activity_executor.target_id
	var diary_text:=DiaryComposer.compose(ObserverText.time_label(clock.text(),str(clock.snapshot().get("period",""))),id,activity_executor.before_needs,needs_model.values,str(recent_activity_history[0]) if not recent_activity_history.is_empty() else "",str(memory_store.entries[0].get("summary","")) if not memory_store.entries.is_empty() else "") if id=="write_diary" else ""
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
	if preferences.last_transition!="": _record_history("preference_transition","","",preferences.last_transition); preferences.last_transition=""
	if habit_store.last_transition!="": _record_history("habit_transition","","",habit_store.last_transition); habit_store.last_transition=""
	if id=="write_diary":
		diary.push_front({"time":clock.text(),"text":str(result.get("diary_text",diary_text)).left(500)})
		if diary.size()>60:diary.resize(60)
	diagnostics.activities_completed=int(diagnostics.get("activities_completed",0))+1
	if id=="eat": diagnostics.food_consumed=int(diagnostics.get("food_consumed",0))+1
	if id=="order_groceries": diagnostics.groceries_ordered=int(diagnostics.get("groceries_ordered",0))+1
	if id in ["eat","order_groceries"]: diagnostics.trash_generated=int(diagnostics.get("trash_generated",0))+1
	if id=="take_out_trash": diagnostics.trash_removed=int(diagnostics.get("trash_removed",0))+1
	if id=="clean": diagnostics.cleaning_activities=int(diagnostics.get("cleaning_activities",0))+1
	if id=="sleep": diagnostics.sleep_completed=int(diagnostics.get("sleep_completed",0))+1
	if id=="drink":
		diagnostics.drink_completed=int(diagnostics.get("drink_completed",0))+1; diagnostics.last_drink_result={"before_thirst":before.get("thirst",0.0),"after_thirst":after.get("thirst",0.0),"target":target}; diagnostics.last_successful_drink_time=clock.text()
	if id=="use_toilet": diagnostics.toilet_completed=int(diagnostics.get("toilet_completed",0))+1
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
	var critical_error:=ActivityExecutor.critical_need_error(activity_executor.activity_id,needs_model)
	if critical_error!="":
		var interruption_reason:="severe_%s" % critical_error.trim_prefix("critical_").trim_suffix("_blocks_activity")
		var records:Array=diagnostics.get("activity_interruption_records",[]); records.append({"activity":activity_executor.activity_id,"target":activity_executor.target_id,"reason":interruption_reason,"start_needs":activity_executor.before_needs.duplicate(true),"interruption_needs":needs_model.values.duplicate(true),"elapsed_minutes":float(ActivityCatalog.get_definition(activity_executor.activity_id).get("duration_minutes",0.0))-activity_executor.remaining_minutes}); if records.size()>100:records.pop_front(); diagnostics["activity_interruption_records"]=records
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
	decision_history.push_front({"time":clock.text(),"event":event,"action":action,"target":target,"reason":why,"text":_life_feed_text(event,action,target),"observer_text":_observer_feed_text(event,action,target,why)})
	if decision_history.size() > 50: decision_history.resize(50)

func _life_feed_text(event:String,action:String,target:String)->String:
	if event=="activity_completed": return "%s completed%s."%[ActivityCatalog.get_definition(action).get("activity_label",action),"" if target=="" else " near "+target]
	if event=="plan_completed": return "Finished deciding what to do."
	if event=="plan_started": return "Started moving or acting."
	if event=="interrupted": return "Stopped %s."%action
	return action

func _observer_feed_text(event:String,action:String,target:String,why:String)->String:
	var time_text:=ObserverText.time_label(clock.text(),str(clock.snapshot().get("period",""))).replace("　朝","").replace("　昼","").replace("　夕方","").replace("　夜","")
	if action.begins_with("plan_") or action=="": return "%s　次にすることを考えた" % time_text
	if event in ["preference_transition","habit_transition","skill_learned"]: return "%s　暮らし方に小さな変化があった" % time_text
	if event=="activity_completed":
		return "%s　%s" % [time_text,ObserverText.activity_completed_label(action)]
	if event=="interrupted": return "%s　%sを途中でやめた" % [time_text,ObserverText.activity_noun(action)]
	if event=="plan_started": return "%s　%sを始めようとしている" % [time_text,ObserverText.activity_noun(action)]
	return "%s　%s" % [time_text,ObserverText.activity_label(action)]

func _memory_topics(strong_needs:Array)->Array:
	var topics:Array=[]
	for id in room_state.objects:
		if resident_state.current_cell in room_state.objects[id].get("interaction_cells",[]):
			topics.append(str(id)); topics.append(str(room_state.objects[id].get("type",id)))
	if resident_state.held_item_id!="": topics.append(resident_state.held_item_id)
	for need in strong_needs: topics.append(str(need))
	topics.append(str(clock.snapshot().get("period","")))
	for goal in goal_store.active_texts():
		for token in str(goal).to_lower().replace(","," ").split(" "):
			if token.length()>=4: topics.append(token)
	for recent in recent_activity_history.slice(0,2): topics.append(str(recent))
	return topics.slice(0,min(10,topics.size()))

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
	labels["action"] = _label(Vector2(920,58),"",18)
	labels["reason"] = _label(Vector2(920,90),"",14); labels["reason"].size = Vector2(345,54); labels["reason"].autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	labels["connection"] = _label(Vector2(920,150),"",13)
	labels["panel"] = _label(Vector2(920,180),"",12); labels["panel"].size = Vector2(345,285); labels["panel"].clip_text=true
	progress_bar = ProgressBar.new(); progress_bar.position=Vector2(920,485); progress_bar.size=Vector2(345,18); progress_bar.visible=false; add_child(progress_bar)
	life_feed_label=_label(Vector2(40,548),"",12); life_feed_label.size=Vector2(830,105); life_feed_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	personality_label=_label(Vector2(895,548),"",12); personality_label.size=Vector2(360,105); personality_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var save := Button.new(); save.text = "保存"; save.position = Vector2(900,658); save.pressed.connect(_save_game); add_child(save)
	var pause := Button.new(); pause.text = "一時停止"; pause.position = Vector2(955,658); pause.pressed.connect(func(): speed = 0.0 if speed > 0.0 else 1.0); add_child(pause)
	var speeds := OptionButton.new(); speeds.position = Vector2(1035,658)
	for x in [1,2,4,8]: speeds.add_item("%sx" % x)
	speeds.item_selected.connect(func(i): speed = pow(2.0,i)); add_child(speeds)
	var debug_button := Button.new(); debug_button.text = "デバッグ"; debug_button.position = Vector2(1140,658); debug_button.pressed.connect(_toggle_debug); add_child(debug_button)
	var diary_button := Button.new(); diary_button.text = "日記"; diary_button.position = Vector2(900,690); diary_button.pressed.connect(_show_diary); add_child(diary_button)
	var settings_button := Button.new(); settings_button.text = "設定"; settings_button.position = Vector2(955,690); settings_button.pressed.connect(_show_settings); add_child(settings_button)
	var reset_button := Button.new(); reset_button.text = "新しい生活"; reset_button.position = Vector2(1010,690); reset_button.pressed.connect(_confirm_reset); add_child(reset_button)
	debug_panel = Panel.new(); debug_panel.position = Vector2(35,35); debug_panel.size = Vector2(835,610); debug_panel.visible = false; debug_panel.z_index = 20; add_child(debug_panel)
	debug_label = Label.new(); debug_label.position = Vector2(14,14); debug_label.size = Vector2(805,575); debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; debug_label.add_theme_font_size_override("font_size",12); debug_panel.add_child(debug_label)

func _toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible

func _label(pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new(); label.position = pos; label.text = text; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",Color("#382f2a")); add_child(label); return label

func _update_ui() -> void:
	if not labels.has("time"): return
	labels["time"].text = ObserverText.time_label(clock.text(),str(clock.snapshot().get("period","")))
	labels["action"].text = "現在：%s（%s）" % [ObserverText.activity_label(activity_executor.activity_id if activity_executor.activity_id != "" else "wait"),ObserverText.status_label(status)]
	labels["reason"].text = "公開された理由：" + ObserverText.public_reason(intention if intention!="" else reason)
	labels["connection"].text = ObserverText.connection_label(llm_status) + "　" + ("自動保存" if save_status.to_lower().contains("auto-save") else "保存済み")
	if progress_bar != null:
		progress_bar.visible = activity_executor.is_active()
		var definition:=ActivityCatalog.get_definition(activity_executor.activity_id)
		progress_bar.max_value=float(definition.get("duration_minutes",1)); progress_bar.value=progress_bar.max_value-activity_executor.remaining_minutes
	var text := "今の状態\n"
	for key in needs_model.values: text += "%s：%s\n" % [ObserverText.need_label(key),ObserverText.need_state(float(needs_model.values[key]))]
	text += "\n部屋\n清潔さ：%s\n食料：%s\nゴミ：%s\n" % ["きれい" if room_state.cleanliness>=60 else "少し散らかっている",ObserverText.resource_quality(room_state.item_quantity("simple_food")),ObserverText.trash_quality(int(room_state.resources.get("trash",0)))]
	var pref_summary := preferences.summary()
	var habit_lines:Array=[]
	for habit in habit_store.summary(): habit_lines.append(ObserverText.habit_label(str(habit)))
	var skill_names:Array=[]
	for skill in skill_store.skills.slice(0,min(5,skill_store.skills.size())): skill_names.append(ObserverText.skill_label(skill))
	labels["panel"].text = text
	var history_text := "最近の出来事\n"
	for item in decision_history.slice(0,min(5,decision_history.size())):
		history_text += "%s\n" % _observer_feed_text(str(item.get("event",item.get("action",""))),str(item.get("action","")),str(item.get("target","")),str(item.get("reason",item.get("text",""))))
	if life_feed_label != null: life_feed_label.text=history_text.left(1050)
	var personality:="この人らしさ\n"
	var shown_preferences:=0
	for key in pref_summary:
		if abs(float(pref_summary[key]))<0.15: continue
		personality += "・%sを%s\n" % [ObserverText.PREFS.get(key,"ある行動"),"少し好む" if float(pref_summary[key])>0.0 else "少し避ける"]
		shown_preferences+=1
		if shown_preferences>=2: break
	for line in habit_lines.slice(0,2): personality += "・%s\n" % line
	for line in skill_names.slice(0,1): personality += "・%s\n" % line
	if habit_lines.is_empty() and skill_names.is_empty(): personality += "・暮らしの傾向を観察中"
	if personality_label != null: personality_label.text=personality
	if debug_panel != null and debug_panel.visible:
		var debug_text := "STATUS: %s\nVALIDATION: %s\nRETRIEVED: %s\nDIAGNOSTICS: %s\nMEMORIES: %d  PLAN HISTORY: %d\n\nLAST OBSERVATION\n%s\n\nRAW RESPONSE\n%s" % [status,validation_error,JSON.stringify(last_retrieved_memory_ids),JSON.stringify(diagnostics),memory_store.entries.size(),plan_history.entries.size(),last_observation.left(4500),last_response.left(2500)]
		debug_label.text = debug_text

func _draw() -> void:
	var period:=str(clock.snapshot().get("period","day")); var base:=Color("#d8c3a5") if period!="night" else Color("#46516b")
	draw_rect(Rect2(0,0,900,530),base)
	draw_rect(Rect2(32,28,836,484),Color("#efe1c7") if period!="night" else Color("#303a55"))
	draw_rect(Rect2(900,8,375,512),Color("#fbf6eb"),true)
	draw_rect(Rect2(28,530,850,132),Color("#f4ead7"),true)
	draw_rect(Rect2(880,530,395,132),Color("#f4ead7"),true)
	draw_line(Vector2(900,8),Vector2(900,720),Color("#8c7968"),2)
	for x in range(50,850,52): draw_line(Vector2(x,48),Vector2(x,505),Color(0.2,0.15,0.1,0.06),1)
	for y in range(48,506,52): draw_line(Vector2(50,y),Vector2(850,y),Color(0.2,0.15,0.1,0.06),1)
	for id in room_state.objects:
		var object:Dictionary=room_state.objects[id]; var p:Vector2=object.position
		if object.has("origin_cell"): p=RoomVisualAdapter.cell_to_position(object.origin_cell)
		_draw_furniture(str(id),p)
	var render_position:=resident_state.render_position
	var activity:=activity_executor.activity_id
	var frame:=int(Time.get_ticks_msec()/350)%2
	var resident_region:=ResidentVisualAdapter.region_for(activity,status,resident_state.posture,frame)
	var active_resident_texture:=resident_supplemental_atlas if ResidentVisualAdapter.uses_supplemental(activity) else resident_atlas
	if ResidentVisualAdapter.uses_supplemental(activity): resident_region=ResidentVisualAdapter.supplemental_region(activity)
	if active_resident_texture != null:
		var bob:=Vector2(0,sin(float(Time.get_ticks_msec())/450.0)*1.5) if activity=="" and status=="idle" else Vector2.ZERO
		draw_texture_rect_region(active_resident_texture,Rect2(render_position-Vector2(34,48)+ResidentVisualAdapter.offset_for(activity)+bob,Vector2(68,86)),resident_region)
	else:
		draw_circle(render_position,24,Color("#4fc3f7"))
	if status in ["acting","moving"]: draw_circle(render_position+Vector2(0,-54),5,Color("#fff176"))

func _draw_furniture(id:String,p:Vector2)->void:
	var wood:=Color("#8b5e45"); var light:=Color("#d7b98e"); var metal:=Color("#a9b0ad"); var dark:=Color("#374247")
	match id:
		"bed":
			draw_rect(Rect2(p-Vector2(44,22),Vector2(88,44)),wood); draw_rect(Rect2(p-Vector2(38,17),Vector2(76,31)),Color("#9fb0a2")); draw_rect(Rect2(p-Vector2(34,15),Vector2(24,12)),Color("#eee7d8"))
		"desk":
			draw_rect(Rect2(p-Vector2(42,18),Vector2(84,12)),wood); draw_line(p+Vector2(-34,-6),p+Vector2(-34,24),wood,6); draw_line(p+Vector2(34,-6),p+Vector2(34,24),wood,6)
		"chair":
			draw_rect(Rect2(p-Vector2(18,8),Vector2(36,20)),light); draw_rect(Rect2(p-Vector2(18,27),Vector2(36,19)),light); draw_line(p+Vector2(-14,12),p+Vector2(-14,27),wood,4); draw_line(p+Vector2(14,12),p+Vector2(14,27),wood,4)
		"bookshelf":
			draw_rect(Rect2(p-Vector2(28,34),Vector2(56,68)),wood); for y in [-15,5,25]: draw_line(p+Vector2(-23,y),p+Vector2(23,y),light,3)
		"fridge":
			draw_rect(Rect2(p-Vector2(25,35),Vector2(50,70)),Color("#d9d8cf")); draw_line(p+Vector2(-25,0),p+Vector2(25,0),metal,2); draw_line(p+Vector2(15,-25),p+Vector2(15,-8),dark,3)
		"sink":
			draw_rect(Rect2(p-Vector2(32,18),Vector2(64,42)),Color("#c7b9a5")); draw_rect(Rect2(p-Vector2(22,13),Vector2(44,15)),metal); draw_arc(p+Vector2(0,-12),10,PI,TAU,12,dark,3)
		"pc":
			draw_rect(Rect2(p-Vector2(27,25),Vector2(54,35)),dark); draw_rect(Rect2(p-Vector2(22,20),Vector2(44,25)),Color("#476a73")); draw_line(p+Vector2(0,10),p+Vector2(0,22),dark,4)
		"tv":
			draw_rect(Rect2(p-Vector2(38,27),Vector2(76,48)),dark); draw_rect(Rect2(p-Vector2(32,21),Vector2(64,36)),Color("#607d8b")); draw_line(p+Vector2(-12,23),p+Vector2(12,23),dark,5)
		"window":
			draw_rect(Rect2(p-Vector2(38,30),Vector2(76,60)),Color("#8eb7c7")); draw_line(p+Vector2(0,-30),p+Vector2(0,30),Color.WHITE,3); draw_line(p+Vector2(-38,0),p+Vector2(38,0),Color.WHITE,3)
		"trash_bin":
			draw_colored_polygon(PackedVector2Array([p+Vector2(-20,-18),p+Vector2(20,-18),p+Vector2(15,24),p+Vector2(-15,24)]),Color("#777a72")); draw_line(p+Vector2(-22,-20),p+Vector2(22,-20),dark,4)
		"shower":
			draw_rect(Rect2(p-Vector2(29,38),Vector2(58,76)),Color(0.65,0.82,0.86,0.45)); draw_line(p+Vector2(-29,-38),p+Vector2(-29,38),metal,3); draw_line(p+Vector2(29,-38),p+Vector2(29,38),metal,3); draw_arc(p+Vector2(12,-19),12,PI,TAU,12,dark,3)
		"toilet":
			draw_rect(Rect2(p-Vector2(18,30),Vector2(36,27)),Color("#e6e2d7")); draw_ellipse_fallback(p+Vector2(0,10),Vector2(27,18),Color("#eeeae0"))
		_:
			draw_rect(Rect2(p-Vector2(24,18),Vector2(48,36)),wood)

func draw_ellipse_fallback(center:Vector2,radius:Vector2,color:Color)->void:
	var points:=PackedVector2Array()
	for i in 24:
		var angle:=TAU*float(i)/24.0; points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	draw_colored_polygon(points,color)

func _activity_text()->String:
	if status=="moving":return "移動中"
	if resident_state.posture=="lying":return "横になっている"
	if resident_state.posture=="sitting":return "座っている"
	if activity_executor.activity_id!="":return ObserverText.activity_label(activity_executor.activity_id)
	if plan_executor.active:return "行動を準備中"
	return "ぼんやりしている" if status=="idle" else status

func _activity_icon()->String:
	match activity_executor.activity_id:
		"read": return "本"
		"sleep": return "Zzz"
		"use_pc": return "PC"
		"watch_tv": return "TV"
		"eat": return "食"
		"drink": return "水"
		"take_shower": return "湯"
		"use_toilet": return "休"
		"clean": return "掃"
		"write_diary": return "日記"
		"call_friend": return "電話"
		"wait": return "..."
	return ""

func _cell_to_position(cell:Vector2i)->Vector2:
	return RoomVisualAdapter.cell_to_position(cell)

func _show_diary()->void:
	var dialog:=AcceptDialog.new(); dialog.title="日記"; var text:=""
	for entry in diary.slice(0,min(8,diary.size())): text += "%s\n%s\n\n" % [entry.get("time",""),entry.get("text","")]
	if text=="": text="まだ日記はありません。"
	dialog.dialog_text=text; add_child(dialog); dialog.popup_centered(Vector2(460,360)); dialog.confirmed.connect(dialog.queue_free)

func _show_settings()->void:
	var dialog:=AcceptDialog.new(); dialog.title="設定"; var box:=VBoxContainer.new(); var url:=LineEdit.new(); url.text=str(config_data.get("base_url",DEFAULT_CONFIG.base_url)); url.placeholder_text="LLM接続先"
	var model:=LineEdit.new(); model.text=str(config_data.get("model",DEFAULT_CONFIG.model)); model.placeholder_text="Model name"
	var auto:=CheckButton.new(); auto.text="自動保存"; auto.button_pressed=bool(config_data.get("auto_save",true)); box.add_child(url);box.add_child(model);box.add_child(auto);dialog.add_child(box);add_child(dialog);dialog.confirmed.connect(func(): config_data["base_url"]=url.text;config_data["model"]=model.text;config_data["auto_save"]=auto.button_pressed;var f:=FileAccess.open("user://one_room_config.json",FileAccess.WRITE);if f:f.store_string(JSON.stringify(config_data));save_status="Auto-save on" if auto.button_pressed else "Auto-save off");dialog.popup_centered()

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
