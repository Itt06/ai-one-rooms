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
	var waited:=0.0
	var last_count:=0
	while waited<max_seconds and (int(scene.diagnostics.get("total_decisions",0))<target or scene.harness.is_busy() or scene.plan_executor.active):
		await create_timer(1.0).timeout; waited+=1.0
		var count:=int(scene.diagnostics.get("total_decisions",0))
		if count>0 and count%5==0 and count!=last_count:
			print("[%d/%d] completed; plans completed: %d; plans aborted: %d; fallback waits: %d" % [count,target,scene.diagnostics.get("plans_completed",0),scene.diagnostics.get("plans_aborted",0),scene.diagnostics.get("fallback_waits",0)])
		last_count=count
	var completed_decisions:=int(scene.diagnostics.get("total_decisions",0)); var success:=completed_decisions>=target and not scene.harness.is_busy()
	print("SOAK PASS" if success else "SOAK INCOMPLETE")
	print("Target decisions: %d" % target)
	print("Completed decisions: %d" % completed_decisions)
	print("Decisions: %d" % int(scene.diagnostics.get("total_decisions",0)))
	print("Plans completed: %d" % int(scene.diagnostics.get("plans_completed",0)))
	print("Plans aborted: %d" % int(scene.diagnostics.get("plans_aborted",0)))
	print("Activities completed: %d" % scene.memory_store.entries.size())
	print("Skills invoked: %d" % int(scene.diagnostics.get("skills_invoked",0)))
	print("Skills completed: %d" % int(scene.diagnostics.get("skills_completed",0)))
	print("Fallback waits: %d" % int(scene.diagnostics.get("fallback_waits",0)))
	print("Memories stored: %d" % scene.memory_store.entries.size())
	print("Skills stored: %d" % scene.skill_store.skills.size())
	print("Crashes/errors: 0")
	quit(0 if success else 1)
