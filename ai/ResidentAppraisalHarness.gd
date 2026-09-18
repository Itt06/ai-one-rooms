class_name ResidentAppraisalHarness
extends Node

signal appraisal_ready(mind:Dictionary, latency_ms:int)
signal appraisal_failed(error:String, latency_ms:int)
signal repair_attempted()
signal repair_recovered()

var client:LLMClient
var _config:Dictionary={}
var _prompt:=""
var _facts:Dictionary={}
var _repairing:=false

func _ready()->void:
	client=LLMClient.new(); add_child(client); client.completed.connect(_on_completed)

func is_busy()->bool:return client!=null and client.is_busy()

func request_appraisal(config:Dictionary,prompt:String,facts:Dictionary)->bool:
	if is_busy():return false
	_config=config.duplicate(true);_prompt=prompt;_facts=facts.duplicate(true);_repairing=false
	return client.request_decision(_config,_prompt,_facts)

func _on_completed(success:bool,content:String,_raw:String,error:String,latency_ms:int)->void:
	if not success:appraisal_failed.emit(error,latency_ms);return
	var parser:=JSON.new();var parse_error:=parser.parse(content);var parsed=parser.data if parse_error==OK else null
	var checked:=ResidentMindState.validate(parsed)
	if bool(checked.get("ok",false)):
		if _repairing:repair_recovered.emit()
		appraisal_ready.emit(parsed,latency_ms);return
	if not _repairing:
		_repairing=true;repair_attempted.emit()
		var repair:="Your appraisal JSON failed schema validation: %s. Return only the required appraisal object. Do not name actions or tools."%str(checked.get("error","invalid"))
		if client.request_decision(_config,_prompt,_facts,repair):return
	appraisal_failed.emit(str(checked.get("error","invalid_appraisal")),latency_ms)
