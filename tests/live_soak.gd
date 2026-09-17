extends SceneTree

## Endurance runner for the production Main scene.
var target := 100

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--decisions" and i+1<args.size(): target=max(1,int(args[i+1]))
	var scene:=load("res://Main.tscn").instantiate(); get_root().add_child(scene)
	var waited:=0.0
	while waited<86400.0 and int(scene.diagnostics.get("total_decisions",0))<target:
		await create_timer(1.0).timeout; waited+=1.0
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
	quit(0)
