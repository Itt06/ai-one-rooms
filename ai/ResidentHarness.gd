class_name ResidentHarness
extends Node

signal decision_ready(decision: Dictionary, latency_ms: int, raw_response: String)
signal decision_failed(error_message: String, latency_ms: int, raw_response: String)
signal plan_ready(plan: Array, reason: String, goal_updates: Dictionary, latency_ms: int, raw_response: String)
signal skill_ready(skill_id: String, reason: String, goal_updates: Dictionary, latency_ms: int, raw_response: String)

var client: LLMClient
var _observation: Dictionary = {}
var _candidates: Array = []
var _room: RoomState
var _goals: Array = []
var _config: Dictionary = {}
var _system_prompt := ""
var _repair_attempted := false
var _last_raw_response := ""

func _ready() -> void:
	client = LLMClient.new()
	add_child(client)
	client.completed.connect(_on_client_completed)

func is_busy() -> bool:
	return client != null and client.is_busy()

func request_decision(observation: Dictionary, candidates: Array, room: RoomState, goals: Array, config: Dictionary, system_prompt: String) -> bool:
	if is_busy():
		return false
	_observation = observation.duplicate(true)
	_candidates = candidates.duplicate(true)
	_room = room
	_goals = goals.duplicate(true)
	_config = config.duplicate(true)
	_system_prompt = system_prompt
	_repair_attempted = false
	_last_raw_response = ""
	return client.request_decision(_config,_system_prompt,_observation)

func _on_client_completed(success: bool, content: String, raw_response: String, error_message: String, latency_ms: int) -> void:
	_last_raw_response = raw_response
	if not success:
		decision_failed.emit(error_message,latency_ms,raw_response)
		return
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary and parsed.has("skill") and parsed.has("plan"):
		decision_failed.emit("skill_and_plan_are_mutually_exclusive",latency_ms,raw_response); return
	if parsed is Dictionary and parsed.has("skill"):
		var skill=parsed.get("skill",{})
		if skill is Dictionary and skill.get("id","") is String and skill.get("args",{}) is Dictionary:
			skill_ready.emit(str(skill.id),str(parsed.get("reason","")),parsed.get("goal_updates",{}),latency_ms,raw_response); return
		decision_failed.emit("Invalid skill invocation",latency_ms,raw_response); return
	if parsed is Dictionary and parsed.has("plan"):
		var plan = parsed.get("plan",[])
		if plan is Array and plan.size() > 0 and plan.size() <= 6:
			var valid_plan:=true
			for step in plan:
				if not step is Dictionary or not step.has("tool") or step.has("action") or step.has("target") or not step.has("args") or not (step.args is Dictionary) or not PrimitiveToolCatalog.TOOLS.has(str(step.get("tool",""))): valid_plan=false
			if valid_plan:
				plan_ready.emit(plan,str(parsed.get("reason","")),parsed.get("goal_updates",{}),latency_ms,raw_response); return
			decision_failed.emit("Invalid short plan",latency_ms,raw_response); return
	var validation := ActionValidator.validate(parsed,_candidates,_room,_goals)
	if bool(validation.get("ok",false)):
		decision_ready.emit(validation.get("decision",{}),latency_ms,raw_response)
		return
	var validation_error := str(validation.get("error","invalid response"))
	if not _repair_attempted:
		_repair_attempted = true
		var repair := "Your previous output was invalid: %s. Return only valid JSON using exactly one currently available action and allowed target." % validation_error
		if client.request_decision(_config,_system_prompt,_observation,repair):
			return
	decision_failed.emit(validation_error,latency_ms,raw_response)
