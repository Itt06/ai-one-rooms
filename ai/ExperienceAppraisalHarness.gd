class_name ExperienceAppraisalHarness
extends Node

signal appraisal_ready(result:Dictionary,latency_ms:int)
signal appraisal_failed(error:String,latency_ms:int)
signal repair_attempted()
signal repair_recovered()

var client:LLMClient
var _config:Dictionary={}
var _prompt:=""
var _facts:Dictionary={}
var _repairing:=false

func _ready()->void:
	client=LLMClient.new();add_child(client);client.completed.connect(_on_completed)
func is_busy()->bool:return client!=null and client.is_busy()
func request_appraisal(config:Dictionary,prompt:String,facts:Dictionary)->bool:
	if is_busy():return false
	_config=config.duplicate(true);_prompt=prompt;_facts=facts.duplicate(true);_repairing=false
	return client.request_decision(_config,_prompt,_facts)

func _on_completed(success:bool,content:String,_raw:String,error:String,latency_ms:int)->void:
	if not success:appraisal_failed.emit(error,latency_ms);return
	var parser:=JSON.new();var parse_error:=parser.parse(content);var parsed=parser.data if parse_error==OK else null
	var checked:=validate(parsed)
	if bool(checked.get("ok",false)):
		if _repairing:repair_recovered.emit()
		appraisal_ready.emit(parsed,latency_ms);return
	if not _repairing:
		_repairing=true;repair_attempted.emit()
		var repair:="Your experience appraisal failed schema validation: %s. Return only the required JSON object. Do not alter the objective result."%str(checked.get("error","invalid"))
		if client.request_decision(_config,_prompt,_facts,repair):return
	appraisal_failed.emit(str(checked.get("error","invalid_experience_appraisal")),latency_ms)

static func validate(data)->Dictionary:
	if not data is Dictionary:return {"ok":false,"error":"experience_not_object"}
	var required:= ["felt_result","emotional_tone","satisfaction","surprise","meaning","future_inclination"]
	for key in required:
		if not data.has(key) or not data[key] is String:return {"ok":false,"error":"missing_%s"%key}
		if str(data[key]).length()>220:return {"ok":false,"error":"long_%s"%key}
	if str(data.satisfaction) not in ["low","mixed","moderate","high"]:return {"ok":false,"error":"invalid_satisfaction"}
	if str(data.surprise) not in ["none","low","moderate","high"]:return {"ok":false,"error":"invalid_surprise"}
	return {"ok":true}
