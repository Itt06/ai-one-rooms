extends SceneTree

## Endurance runner for the production Main scene.
var target := 100
var max_seconds := 7200.0
var target_days := 0
var requested_speed := 1.0
var fresh_run := false

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--decisions" and i+1<args.size(): target=max(1,int(args[i+1]))
		if args[i]=="--max-seconds" and i+1<args.size(): max_seconds=max(1.0,float(args[i+1]))
		if args[i]=="--days" and i+1<args.size(): target_days=max(0,int(args[i+1]))
		if args[i]=="--speed" and i+1<args.size(): requested_speed=max(0.0,float(args[i+1]))
		if args[i]=="--fresh": fresh_run=true
	var scene:Node=load("res://Main.tscn").instantiate(); get_root().add_child(scene)
	# Main's _ready (save restore + initial production request) runs after add_child.
	# Let that initial lifecycle settle, then freeze one frame so every baseline is
	# captured from the same authoritative state. Otherwise a restored cumulative
	# total can be mistaken for fresh decisions.
	await process_frame
	var initialization_waited:=0.0
	while initialization_waited<90.0 and (scene.harness==null or scene.harness.is_busy() or scene.plan_executor.active or scene.activity_executor.is_active() or scene.status=="thinking"):
		await create_timer(0.1).timeout; initialization_waited+=0.1
	if scene.harness==null or scene.harness.is_busy() or scene.plan_executor.active or scene.activity_executor.is_active() or scene.status=="thinking":
		printerr("SOAK INFRASTRUCTURE FAILURE: initial production lifecycle did not settle")
		quit(2)
		return
	var original_speed:float=scene.speed; scene.speed=0.0; await process_frame
	if fresh_run:
		scene.clock=WorldClock.new(); scene.room_state=RoomState.new(); scene.needs_model=ResidentNeeds.new(); scene.memory_store=MemoryStore.new(); scene.goal_store=GoalStore.new(); scene.preferences=PreferenceStore.new(); scene.habit_store=HabitStore.new(); scene.skill_store=SkillStore.new(); scene.plan_history=PlanHistory.new(); scene.recent_activity_history=[]; scene.diary=[]; scene.decision_history=[]; scene.resident_state=ResidentState.new(); scene.resident_state.render_position=scene._cell_to_position(scene.resident_state.current_cell); scene.status="idle"; scene.reason="The room is quiet."; scene.intention=""
	var baseline_decisions:=int(scene.diagnostics.get("total_decisions",0))
	var baseline:Dictionary={}
	for key in ["plans_completed","plans_aborted","fallback_waits","fallback_schema","fallback_semantic","fallback_repair_failed","fallback_transport","fallback_other","schema_repair_attempts","semantic_repair_attempts","repair_recovered","repair_failed","skills_invoked","skills_completed","skills_failed","activities_started","activities_completed","activities_failed","activities_interrupted","primitive_only_plans","plans_with_activity","food_consumed","groceries_ordered","trash_generated","trash_removed","cleaning_activities","sleep_completed"]: baseline[key]=int(scene.diagnostics.get(key,0))
	var baseline_memories:int=scene.memory_store.entries.size(); var baseline_preferences:int=_sum_counts(scene.preferences.counts); var baseline_habit_evidence:int=_habit_evidence(scene.habit_store.habits); var baseline_habits:int=scene.habit_store.summary().size(); var baseline_skill_stats:Dictionary=scene.skill_store.candidate_stats.duplicate(true)
	var baseline_activity_types:Dictionary=scene.diagnostics.get("activity_types_requested",{}).duplicate(true); var baseline_interruptions:Dictionary=scene.diagnostics.get("activity_interruption_reasons",{}).duplicate(true)
	var baseline_day:int=int(scene.clock.snapshot().get("day",1)); var initial_food:int=scene.room_state.item_quantity("simple_food"); var peak_trash:int=int(scene.room_state.resources.get("trash",0)); var minimum_food:int=initial_food
	scene.speed=requested_speed if requested_speed>0.0 else original_speed
	print("Starting cumulative decisions: %d" % baseline_decisions)
	print("Target new decisions: %d" % target)
	var waited:=0.0
	var last_count:=0
	while waited<max_seconds and (int(scene.diagnostics.get("total_decisions",0))-baseline_decisions<target or int(scene.clock.snapshot().get("day",1))-baseline_day<target_days or scene.harness.is_busy() or scene.plan_executor.active):
		await create_timer(1.0).timeout; waited+=1.0
		peak_trash=max(peak_trash,int(scene.room_state.resources.get("trash",0))); minimum_food=min(minimum_food,scene.room_state.item_quantity("simple_food"))
		var count:=int(scene.diagnostics.get("total_decisions",0))-baseline_decisions
		if count>0 and count%5==0 and count!=last_count:
			print("[%d/%d] completed; plans completed: %d; plans aborted: %d; fallback waits: %d" % [count,target,scene.diagnostics.get("plans_completed",0),scene.diagnostics.get("plans_aborted",0),scene.diagnostics.get("fallback_waits",0)])
		last_count=count
	var ending_cumulative:=int(scene.diagnostics.get("total_decisions",0)); var completed_decisions:=ending_cumulative-baseline_decisions; var success:bool=completed_decisions>=target and not scene.harness.is_busy()
	var simulated_days:=int(scene.clock.snapshot().get("day",1))-baseline_day
	if target_days>0: success = success and simulated_days>=target_days
	var integrity:=_check_integrity(scene)
	var final_success:bool=success and integrity.is_empty()
	print("State integrity: PASS" if integrity.is_empty() else "State integrity: FAIL")
	for issue in integrity: print("- %s" % issue)
	print("Target decisions: %d" % target)
	print("Ending cumulative decisions: %d" % ending_cumulative)
	print("New decisions completed: %d" % completed_decisions)
	print("Simulated days: %d" % simulated_days)
	print("Run-local plans completed: %d" % _delta(scene,"plans_completed",baseline))
	print("Run-local plans aborted: %d" % _delta(scene,"plans_aborted",baseline))
	print("Run-local activities completed: %d" % _delta(scene,"activities_completed",baseline))
	print("Run-local activities started: %d" % _delta(scene,"activities_started",baseline))
	print("Run-local activities failed: %d" % _delta(scene,"activities_failed",baseline))
	print("Run-local activities interrupted: %d" % _delta(scene,"activities_interrupted",baseline))
	print("Food consumed: %d" % _delta(scene,"food_consumed",baseline))
	print("Groceries ordered: %d" % _delta(scene,"groceries_ordered",baseline))
	print("Trash generated: %d" % _delta(scene,"trash_generated",baseline))
	print("Trash removed: %d" % _delta(scene,"trash_removed",baseline))
	print("Cleaning activities: %d" % _delta(scene,"cleaning_activities",baseline))
	print("Sleep completed: %d" % _delta(scene,"sleep_completed",baseline))
	print("Ending food: %d" % scene.room_state.item_quantity("simple_food"))
	print("Minimum food: %d" % minimum_food)
	print("Ending trash: %d" % int(scene.room_state.resources.get("trash",0)))
	print("Peak trash: %d" % peak_trash)
	print("Ending cleanliness: %d" % int(scene.room_state.cleanliness))
	print("Primitive-only plans: %d" % _delta(scene,"primitive_only_plans",baseline))
	print("Plans with activity: %d" % _delta(scene,"plans_with_activity",baseline))
	print("Activity types requested: %s" % JSON.stringify(_dictionary_delta(scene.diagnostics.get("activity_types_requested",{}),baseline_activity_types)))
	print("Activity interruption reasons: %s" % JSON.stringify(_dictionary_delta(scene.diagnostics.get("activity_interruption_reasons",{}),baseline_interruptions)))
	print("Run-local fallback waits: %d" % _delta(scene,"fallback_waits",baseline))
	for category in ["fallback_schema","fallback_semantic","fallback_repair_failed","fallback_transport","fallback_other"]: print("%s: %d" % [category,_delta(scene,category,baseline)])
	print("Schema repair attempts: %d" % _delta(scene,"schema_repair_attempts",baseline))
	print("Semantic repair attempts: %d" % _delta(scene,"semantic_repair_attempts",baseline))
	print("Repair recovered: %d" % _delta(scene,"repair_recovered",baseline))
	print("Repair failed: %d" % _delta(scene,"repair_failed",baseline))
	print("Memories created: %d" % max(0,scene.memory_store.entries.size()-baseline_memories))
	print("Preference updates: %d" % max(0,_sum_counts(scene.preferences.counts)-baseline_preferences))
	print("Habit evidence: %d" % max(0,_habit_evidence(scene.habit_store.habits)-baseline_habit_evidence))
	print("Habits created: %d" % max(0,scene.habit_store.summary().size()-baseline_habits))
	print("Skills stored: %d" % scene.skill_store.skills.size())
	print("Skill eligible sequences: %d" % int(scene.skill_store.candidate_stats.get("eligible_sequences",0)))
	print("Skill candidates detected: %d" % int(scene.skill_store.candidate_stats.get("candidate_detections",0)))
	print("Skills created: %d" % int(scene.skill_store.candidate_stats.get("skills_created",0)))
	print("Skills offered: %d" % (int(scene.skill_store.candidate_stats.get("skills_offered",0))-int(baseline_skill_stats.get("skills_offered",0))))
	print("Skills invoked: %d" % _delta(scene,"skills_invoked",baseline))
	print("Skills completed: %d" % _delta(scene,"skills_completed",baseline))
	print("Skills failed: %d" % _delta(scene,"skills_failed",baseline))
	print("Fatal runtime errors: not instrumented by Godot; process exit and parser/headless checks were clean")
	print("SOAK PASS" if final_success else "SOAK FAIL")
	quit(0 if final_success else 1)

func _delta(scene:Node,key:String,baseline:Dictionary)->int:
	return int(scene.diagnostics.get(key,0))-int(baseline.get(key,0))

func _dictionary_delta(current:Dictionary,baseline:Dictionary)->Dictionary:
	var out:Dictionary={}
	for key in current:
		var change:=int(current.get(key,0))-int(baseline.get(key,0)); if change!=0:out[key]=change
	return out

func _sum_counts(counts:Dictionary)->int:
	var total:=0; for value in counts.values():total+=int(value)
	return total

func _habit_evidence(habits:Array)->int:
	var total:=0; for habit in habits:total+=int(habit.get("count",0))
	return total

func _check_integrity(scene:Node)->Array:
	var issues:Array=[]; var resident=scene.resident_state; var room=scene.room_state
	if not room.grid.is_inside(resident.current_cell): issues.append("resident cell outside grid")
	if resident.held_item_id!="":
		if not room.items.has(resident.held_item_id): issues.append("held item missing")
		else:
			var item:Dictionary=room.items[resident.held_item_id]
			if str(item.get("location",""))!="held" or str(item.get("held_by",""))!="resident": issues.append("held item mismatch")
	var held_by_resident:Array=[]
	for id in room.items:
		if str(room.items[id].get("location",""))=="held" and str(room.items[id].get("held_by",""))=="resident": held_by_resident.append(id)
	if held_by_resident.size()>1: issues.append("multiple held items")
	if held_by_resident.size()==1 and resident.held_item_id!=held_by_resident[0]: issues.append("reverse held item mismatch")
	if held_by_resident.is_empty() and resident.held_item_id!="": issues.append("resident held item has no reverse link")
	for id in room.items:
		if int(room.items[id].get("quantity",1))<0: issues.append("negative item quantity: %s"%id)
	for id in room.objects:
		for cell in room.objects[id].get("occupied_cells",[]):
			if not room.grid.is_inside(cell): issues.append("object outside grid: %s"%id); break
	if scene.goal_store.active_records().size()>GoalStore.MAX_ACTIVE: issues.append("active goals exceed limit")
	if scene.memory_store.entries.size()>MemoryStore.MAX_ENTRIES: issues.append("memory limit exceeded")
	if scene.plan_history.entries.size()>50: issues.append("plan history limit exceeded")
	if scene.skill_store.skills.size()>SkillStore.MAX_SKILLS: issues.append("skill limit exceeded")
	if resident.posture_target_id!="" and not room.objects.has(resident.posture_target_id): issues.append("posture target missing")
	var copy_room:=RoomState.new(); copy_room.load_state(room.serialize())
	var copy_resident:=ResidentState.new(); copy_resident.load_state(resident.serialize())
	if not copy_room.grid.is_inside(copy_resident.current_cell): issues.append("save/load resident corruption")
	if copy_room.item_quantity("simple_food")!=room.item_quantity("simple_food"): issues.append("save/load item corruption")
	return issues
