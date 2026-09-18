extends SceneTree

class FakeLLMClient extends LLMClient:
	var request_count:=0
	func request_decision(_config:Dictionary,_prompt:String,_facts:Dictionary,_repair:String="")->bool:request_count+=1;return true
	func is_busy()->bool:return false

var failures:=0

func _initialize()->void:
	var harness:=ResidentAppraisalHarness.new();root.add_child(harness)
	var sink:=FakeLLMClient.new();harness.add_child(sink);harness.client=sink
	var state:={"repairs":0,"recovered":0,"ready":0,"failed":0}
	harness.repair_attempted.connect(func():state.repairs+=1)
	harness.repair_recovered.connect(func():state.recovered+=1)
	harness.appraisal_ready.connect(func(_mind,_latency):state.ready+=1)
	harness.appraisal_failed.connect(func(_error,_latency):state.failed+=1)
	harness._config={};harness._prompt="";harness._facts={}
	harness._on_completed(true,'{"mood":"only"}',"","",1)
	_check(state.repairs==1 and sink.request_count==1 and state.ready==0,"invalid appraisal should request one repair")
	harness._on_completed(true,JSON.stringify(_valid()),"","",2)
	_check(state.repairs==1 and state.recovered==1 and state.ready==1 and state.failed==0,"valid repair should recover once")
	var previous:=ResidentMindState.new();previous.load_state(_valid());var before:=previous.serialize()
	harness._on_completed(false,"","","transport",3)
	_check(previous.serialize()==before and state.failed==1,"appraisal failure must not mutate previous mind")
	var fallback:=ResidentMindState.new();_check(fallback.snapshot()==ResidentMindState.neutral(),"neutral fallback should be safe")
	print("ResidentAppraisalHarness tests: %s"%("PASS" if failures==0 else "FAIL"));quit(0 if failures==0 else 1)

func _valid()->Dictionary:return {"mood":"quiet","wants":[],"concerns":[],"avoidances":[],"short_term_intentions":[],"social_attitude":"neutral","energy_attitude":"ordinary"}
func _check(ok:bool,message:String)->void:if not ok:failures+=1;push_error(message)
