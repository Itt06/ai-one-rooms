class_name LLMClient
extends Node

signal completed(success: bool, content: String, raw_response: String, error_message: String, latency_ms: int)

var _http: HTTPRequest
var _started_ms := 0
var _busy := false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func is_busy() -> bool:
	return _busy

func request_decision(config: Dictionary, system_prompt: String, observation: Dictionary, repair_message := "") -> bool:
	if _busy:
		return false
	var base_url := str(config.get("base_url", "http://127.0.0.1:8000/v1")).trim_suffix("/")
	_http.timeout = float(config.get("timeout_ms", 15000)) / 1000.0
	var messages: Array = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": JSON.stringify(observation)}
	]
	if repair_message != "":
		messages.append({"role": "user", "content": repair_message})
	var body := {
		"model": str(config.get("model", "Ornith-1.5-9B")),
		"temperature": float(config.get("temperature", 0.3)),
		"max_tokens": int(config.get("max_tokens", 256)),
		"response_format": {"type": "json_object"},
		"messages": messages
	}
	_started_ms = Time.get_ticks_msec()
	_busy = true
	var err := _http.request(base_url + "/chat/completions", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_busy = false
		completed.emit(false, "", "", "LLM request error %s" % err, 0)
		return false
	return true

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var latency_ms := Time.get_ticks_msec() - _started_ms
	var raw := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		completed.emit(false, "", raw, "timeout" if result == HTTPRequest.RESULT_TIMEOUT else "LLM transport error %s" % result, latency_ms)
		return
	if code < 200 or code >= 300:
		completed.emit(false, "", raw, "LLM HTTP %s" % code, latency_ms)
		return
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		completed.emit(false, "", raw, "Malformed OpenAI-compatible response", latency_ms)
		return
	var choices = parsed.get("choices", [])
	if not (choices is Array) or choices.is_empty():
		completed.emit(false, "", raw, "LLM response has no choices", latency_ms)
		return
	var message = choices[0].get("message", {}) if choices[0] is Dictionary else {}
	var content := str(message.get("content", "")) if message is Dictionary else ""
	if content.strip_edges() == "":
		completed.emit(false, "", raw, "LLM returned empty content", latency_ms)
		return
	completed.emit(true, content, raw, "", latency_ms)
