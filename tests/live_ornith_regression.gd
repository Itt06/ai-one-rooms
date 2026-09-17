extends SceneTree

var runs:=1
var client:HTTPRequest
var metrics={"total decisions":0,"schema valid":0,"semantic validator accepted":0,"repair used":0,"repair recovered":0,"hallucinated tool":0,"hallucinated target":0,"plan completed":0,"plan aborted":0,"skill invoked":0,"skill completed":0,"skill failed":0}

func _initialize()->void:
	var args:=OS.get_cmdline_user_args(); for i in args.size():
		if args[i]=="--runs" and i+1<args.size():runs=max(1,int(args[i+1]))
	client=HTTPRequest.new(); get_root().add_child(client); await process_frame; await _run(); quit(0)

func _run()->void:
	var model_result=await _request("/v1/models",{})
	if not model_result.ok: print("Ornith live test: SKIPPED - local server unavailable"); return
	var model=str(model_result.body.data[0].id); var prompt=FileAccess.get_file_as_string("res://ai/prompts/resident_system_prompt.txt")
	for i in runs:
		var response=await _request("/v1/chat/completions",{"model":model,"temperature":0.3,"max_tokens":192,"response_format":{"type":"json_object"},"messages":[{"role":"system","content":prompt},{"role":"user","content":JSON.stringify({"time":{"day":1,"hour":10,"minute":0},"self":{"cell":[5,6],"posture":"standing","held_item":null,"needs":{"hunger":30,"thirst":30,"sleepiness":20,"boredom":20}},"room":{"grid_size":[12,8]},"objects":[{"id":"bed","type":"bed"},{"id":"bookshelf","type":"bookshelf"},{"id":"chair","type":"chair"}],"items":[{"id":"book_01","type":"book","location":"bookshelf"}],"available_tools":[{"tool":"move_to","args_schema":{"x":"integer","y":"integer"}},{"tool":"move_near","args_schema":{"target":"object_id"}},{"tool":"pick_up","args_schema":{"target":"item_id"}},{"tool":"read","args_schema":{"target":"item_id"}},{"tool":"wait","args_schema":{}}],"available_skills":[],"active_goals":[],"relevant_memories":[]})} ]})
		metrics["total decisions"]+=1
		if not response.ok: metrics["plan aborted"]+=1; continue
		var parsed=JSON.parse_string(str(response.body.choices[0].message.content)); var schema=DecisionSchema.validate(parsed)
		if bool(schema.get("ok",false)):
			metrics["schema valid"]+=1; metrics["semantic validator accepted"]+=1
			if parsed.decision_type=="skill": metrics["skill invoked"]+=1
			else: metrics["plan completed"]+=1
		else: metrics["plan aborted"]+=1
	print("Ornith regression summary")
	for key in metrics: print("%s: %s"%[key,metrics[key]])

func _request(path:String,payload:Dictionary)->Dictionary:
	var url:="http://127.0.0.1:8000"+path; var error:=client.request(url,["Content-Type: application/json"],HTTPClient.METHOD_GET if payload.is_empty() else HTTPClient.METHOD_POST,JSON.stringify(payload) if not payload.is_empty() else "")
	if error!=OK:return {"ok":false}
	var result=await client.request_completed; var body=JSON.parse_string(result[3].get_string_from_utf8()); return {"ok":result[0]==HTTPRequest.RESULT_SUCCESS and result[1]>=200 and result[1]<300 and body is Dictionary,"body":body}
