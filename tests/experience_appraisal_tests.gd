extends SceneTree

class FakeLLMClient extends LLMClient:
	var request_count:=0
	func request_decision(_config:Dictionary,_prompt:String,_facts:Dictionary,_repair:String="")->bool:request_count+=1;return true
	func is_busy()->bool:return false

var failures:=0

func _initialize()->void:
	var valid_a:=_valid("It took the edge off.","relieved","high","low","Solitude felt right.","I might do this again.")
	var valid_b:=_valid("The tension eased but I still felt lonely.","mixed","mixed","low","Physical relief was not closeness.","")
	_check(bool(ExperienceAppraisalHarness.validate(valid_a).ok),"valid experience schema")
	_check(not bool(ExperienceAppraisalHarness.validate({"felt_result":"x"}).ok),"incomplete experience schema rejected")
	_check(bool(ExperienceAppraisalHarness.validate(valid_a).ok) and bool(ExperienceAppraisalHarness.validate(valid_b).ok),"same activity can accept different subjective results")
	var memory:=MemoryStore.new();var event:=LifeEvent.activity_completed("Day 1 22:00","masturbate","",Vector2i(1,1),20.0,{"sexual_desire":90.0,"stress":70.0},{"sexual_desire":25.0,"stress":60.0},{},"completed");memory.add_life_event(event)
	var objective_before:Dictionary=memory.entries[0].duplicate(true);_check(memory.enrich_latest_experience(valid_a),"subjective experience should be stored");_check(memory.entries[0].get("objective_result",{} )==objective_before.get("objective_result",{}),"objective result must remain unchanged");_check(memory.entries[0].subjective_experience==valid_a.felt_result and memory.entries[0].need_effects==objective_before.need_effects,"subjective and objective fields remain separate")
	var restored:=MemoryStore.new();restored.load_state(memory.serialize());_check(restored.entries[0].subjective_experience==valid_a.felt_result,"subjective episodic memory should save/load")
	var harness:=ExperienceAppraisalHarness.new();root.add_child(harness);var fake:=FakeLLMClient.new();harness.add_child(fake);harness.client=fake
	var state:={"repairs":0,"recovered":0,"ready":0,"failed":0};harness.repair_attempted.connect(func():state.repairs+=1);harness.repair_recovered.connect(func():state.recovered+=1);harness.appraisal_ready.connect(func(_result,_latency):state.ready+=1);harness.appraisal_failed.connect(func(_error,_latency):state.failed+=1)
	harness._on_completed(true,"{bad","","",1);harness._on_completed(true,JSON.stringify(valid_a),"","",2)
	_check(state.repairs==1 and state.recovered==1 and state.ready==1 and state.failed==0,"experience appraisal should allow one repair")
	var previous:Dictionary=memory.entries[0].duplicate(true);harness._on_completed(false,"","","transport",3);_check(memory.entries[0]==previous,"failed appraisal must preserve objective memory")
	_check(not _meaningful("move_to") and not _meaningful("sit") and _meaningful("masturbate") and _meaningful("meet_contact"),"primitive tools should not trigger experience appraisal")
	print("Experience appraisal tests: %s"%("PASS" if failures==0 else "FAIL"));quit(0 if failures==0 else 1)

func _valid(felt:String,tone:String,satisfaction:String,surprise:String,meaning:String,future:String)->Dictionary:return {"felt_result":felt,"emotional_tone":tone,"satisfaction":satisfaction,"surprise":surprise,"meaning":meaning,"future_inclination":future}
func _meaningful(activity:String)->bool:return activity in ["sleep","eat","drink","read","watch_tv","use_pc","clean","remote_work","meet_contact","sex","masturbate","message_contact","call_contact"]
func _check(ok:bool,message:String)->void:if not ok:failures+=1;push_error(message)
