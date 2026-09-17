extends SceneTree

class FakeLLMClient extends LLMClient:
	var request_count:=0
	var last_repair_message:=""
	func request_decision(_config:Dictionary,_prompt:String,_observation:Dictionary,repair_message:String="")->bool:
		request_count+=1;last_repair_message=repair_message;return true
	func is_busy()->bool:return false

var failures:=0
func _initialize()->void:
	_case("A",'{"decision_type":"plan"}',_valid(),true,"schema")
	_case("B",_invalid(),_valid(),true,"semantic")
	_case("C",'{"decision_type":"plan"}',_invalid(),false,"schema")
	_case("D",_invalid(),_invalid(),false,"semantic")
	print("ResidentHarness repair A-D: %s"%("PASS" if failures==0 else "FAIL"));quit(0 if failures==0 else 1)

func _case(label:String,first:String,second:String,expect_recovered:bool,expected_kind:String)->void:
	var room:=RoomState.new();var resident:=ResidentState.new();var needs:=ResidentNeeds.new();var harness:=ResidentHarness.new();root.add_child(harness)
	var sink:=FakeLLMClient.new();harness.add_child(sink);harness.client=sink;harness._room=room;harness._goals=[];harness._resident_snapshot=resident.snapshot();harness._needs_snapshot=needs.snapshot();harness._observation={"available_skills":[]}
	var state:={"attempts":0,"kind":"","recovered":0,"repair_failed":0,"terminal":0,"plan":0,"decision_failed":0}
	harness.repair_attempted.connect(func(kind):state.attempts+=1;state.kind=kind)
	harness.repair_recovered.connect(func():state.recovered+=1)
	harness.repair_failed.connect(func():state.repair_failed+=1)
	harness.plan_ready.connect(func(_p,_r,_g,_l,_raw):state.plan+=1;state.terminal+=1)
	harness.skill_ready.connect(func(_id,_r,_g,_l,_raw):state.terminal+=1)
	harness.decision_failed.connect(func(_e,_l,_raw):state.decision_failed+=1;state.terminal+=1)
	harness._on_client_completed(true,first,first,"",1)
	_check(state.attempts==1 and state.kind==expected_kind and sink.request_count==1 and state.terminal==0,label+" initial repair")
	harness._on_client_completed(true,second,second,"",1)
	_check(state.attempts<=1,label+" one-repair invariant")
	_check(state.terminal==1,label+" single-terminal invariant")
	if expect_recovered:_check(state.recovered==1 and state.plan==1 and state.repair_failed==0 and state.decision_failed==0,label+" recovered")
	else:_check(state.recovered==0 and state.plan==0 and state.repair_failed==1 and state.decision_failed==1 and sink.request_count==1,label+" final failure")
	harness.free()

func _valid()->String:return JSON.stringify({"decision_type":"plan","reason":"wait","plan":[{"tool":"wait","args":{}}],"goal_updates":{"add":[],"complete":[],"abandon":[]}})
func _invalid()->String:return JSON.stringify({"decision_type":"plan","reason":"read","plan":[{"tool":"read","args":{"target":"book_01"}}],"goal_updates":{"add":[],"complete":[],"abandon":[]}})
func _check(ok:bool,message:String)->void:if not ok:failures+=1;push_error(message)
