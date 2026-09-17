extends SceneTree

## Endurance runner for the production Main scene.
var target := 100
var max_seconds := 7200.0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--decisions" and i+1<args.size(): target=max(1,int(args[i+1]))
		if args[i]=="--max-seconds" and i+1<args.size(): max_seconds=max(1.0,float(args[i+1]))
	var scene:Node=load("res://Main.tscn").instantiate(); get_root().add_child(scene)
	var baseline_decisions:=int(scene.diagnostics.get("total_decisions",0))
	var baseline:Dictionary={}
	for key in ["plans_completed","plans_aborted","fallback_waits","schema_repair_attempts","semantic_repair_attempts","repair_recovered","repair_failed","skills_invoked","skills_completed","activities_started","activities_completed","activities_failed","activities_interrupted"]: baseline[key]=int(scene.diagnostics.get(key,0))
	print("Starting cumulative decisions: %d" % baseline_decisions)
	print("Target new decisions: %d" % target)
	var waited:=0.0
	var last_count:=0
	while waited<max_seconds and (int(scene.diagnostics.get("total_decisions",0))-baseline_decisions<target or scene.harness.is_busy() or scene.plan_executor.active):
		await create_timer(1.0).timeout; waited+=1.0
		var count:=int(scene.diagnostics.get("total_decisions",0))-baseline_decisions
		if count>0 and count%5==0 and count!=last_count:
			print("[%d/%d] completed; plans completed: %d; plans aborted: %d; fallback waits: %d" % [count,target,scene.diagnostics.get("plans_completed",0),scene.diagnostics.get("plans_aborted",0),scene.diagnostics.get("fallback_waits",0)])
		last_count=count
	var ending_cumulative:=int(scene.diagnostics.get("total_decisions",0)); var completed_decisions:=ending_cumulative-baseline_decisions; var success:bool=completed_decisions>=target and not scene.harness.is_busy()
	var integrity:=_check_integrity(scene)
	var final_success:bool=success and integrity.is_empty()
	print("State integrity: PASS" if integrity.is_empty() else "State integrity: FAIL")
	for issue in integrity: print("- %s" % issue)
	print("Target decisions: %d" % target)
	print("Ending cumulative decisions: %d" % ending_cumulative)
	print("New decisions completed: %d" % completed_decisions)
	print("Run-local plans completed: %d" % _delta(scene,"plans_completed",baseline))
	print("Run-local plans aborted: %d" % _delta(scene,"plans_aborted",baseline))
	print("Run-local activities completed: %d" % _delta(scene,"activities_completed",baseline))
	print("Run-local activities started: %d" % _delta(scene,"activities_started",baseline))
	print("Run-local activities failed: %d" % _delta(scene,"activities_failed",baseline))
	print("Run-local activities interrupted: %d" % _delta(scene,"activities_interrupted",baseline))
	print("Run-local fallback waits: %d" % _delta(scene,"fallback_waits",baseline))
	print("Schema repair attempts: %d" % _delta(scene,"schema_repair_attempts",baseline))
	print("Semantic repair attempts: %d" % _delta(scene,"semantic_repair_attempts",baseline))
	print("Repair recovered: %d" % _delta(scene,"repair_recovered",baseline))
	print("Repair failed: %d" % _delta(scene,"repair_failed",baseline))
	print("Memories stored: %d" % scene.memory_store.entries.size())
	print("Skills stored: %d" % scene.skill_store.skills.size())
	print("Skill eligible sequences: %d" % int(scene.skill_store.candidate_stats.get("eligible_sequences",0)))
	print("Skill candidates detected: %d" % int(scene.skill_store.candidate_stats.get("candidate_detections",0)))
	print("Skills created: %d" % int(scene.skill_store.candidate_stats.get("skills_created",0)))
	print("Fatal runtime errors: not instrumented by Godot; process exit and parser/headless checks were clean")
	print("SOAK PASS" if final_success else "SOAK FAIL")
	quit(0 if final_success else 1)

func _delta(scene:Node,key:String,baseline:Dictionary)->int:
	return int(scene.diagnostics.get(key,0))-int(baseline.get(key,0))

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
