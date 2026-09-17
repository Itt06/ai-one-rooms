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
	if observation.get("available_skills",[]) is Array and observation.available_skills.is_empty():
		_system_prompt += "\nNo learned skills are available in this observation. Use decision_type plan; do not output skill."
	_repair_attempted = false
	_last_raw_response = ""
	return client.request_decision(_config,_system_prompt,_observation)

func _on_client_completed(success: bool, content: String, raw_response: String, error_message: String, latency_ms: int) -> void:
	_last_raw_response = raw_response
	if not success:
		decision_failed.emit(error_message,latency_ms,raw_response)
		return
	var parsed = JSON.parse_string(content)
	var schema:=DecisionSchema.validate(parsed)
	if bool(schema.get("ok",false)):
		if parsed.decision_type=="plan": plan_ready.emit(parsed.plan,str(parsed.reason),parsed.goal_updates,latency_ms,raw_response)
		else: skill_ready.emit(str(parsed.skill.id),str(parsed.reason),parsed.goal_updates,latency_ms,raw_response)
		return
	var validation_error := str(schema.get("error","invalid response"))
	if not _repair_attempted:
		_repair_attempted = true
		var repair := "Invalid schema. Choose exactly one: {\"decision_type\":\"plan\",\"reason\":\"...\",\"plan\":[{\"tool\":\"wait\",\"args\":{}}],\"goal_updates\":{\"add\":[],\"complete\":[],\"abandon\":[]}} OR {\"decision_type\":\"skill\",\"reason\":\"...\",\"skill\":{\"id\":\"KNOWN_SKILL_ID\",\"args\":{}} ,\"goal_updates\":{\"add\":[],\"complete\":[],\"abandon\":[]}}. Do not mix, emit null placeholders, or use array args. JSON only."
		if client.request_decision(_config,_system_prompt,_observation,repair):
			return
	decision_failed.emit(validation_error,latency_ms,raw_response)
