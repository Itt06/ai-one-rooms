extends Node2D

const ACTIONS := ["wait", "eat_food", "drink_water", "sleep", "use_toilet", "take_shower", "sit", "read_book", "use_pc", "watch_tv", "look_out_window", "clean_room", "take_out_trash", "write_diary", "inspect_object"]
const ACTION_NAMES := {"wait":"Wait", "eat_food":"Eat food", "drink_water":"Drink water", "sleep":"Sleep", "use_toilet":"Use toilet", "take_shower":"Take shower", "sit":"Sit", "read_book":"Read book", "use_pc":"Use PC", "watch_tv":"Watch TV", "look_out_window":"Look out window", "clean_room":"Clean room", "take_out_trash":"Take out trash", "write_diary":"Write diary", "inspect_object":"Inspect object"}
const DEFAULT_CONFIG := {"base_url":"http://127.0.0.1:8000/v1", "model":"Ornith-1.5-9B", "temperature":0.3, "timeout_ms":15000}
const NEED_RATES := {"hunger":0.10, "thirst":0.16, "sleepiness":0.08, "hygiene_need":0.04, "boredom":0.05, "loneliness":0.015, "stress":0.01, "discomfort":0.02}
const EFFECTS := {"eat_food":{"hunger":-45}, "drink_water":{"thirst":-50}, "sleep":{"sleepiness":-65, "stress":-5}, "take_shower":{"hygiene_need":-55, "discomfort":-15}, "read_book":{"boredom":-35, "stress":-5}, "watch_tv":{"boredom":-30}, "use_pc":{"boredom":-25, "stress":3}, "clean_room":{"discomfort":-20}, "take_out_trash":{"discomfort":-10}, "write_diary":{"stress":-4}, "look_out_window":{"boredom":-8}, "sit":{}, "use_toilet":{"discomfort":-12}, "inspect_object":{"boredom":-4}, "wait":{}}

var sim_minutes := 480.0
var speed := 1.0
var needs := {"hunger":28.0,"thirst":32.0,"sleepiness":20.0,"hygiene_need":22.0,"boredom":38.0,"loneliness":18.0,"stress":12.0,"discomfort":8.0}
var inventory := {"water":6,"simple_food":5,"book":1,"trash":0}
var room_cleanliness := 82.0
var current_action := "idle"
var action_remaining := 0.0
var reason := "The room is quiet."
var status := "idle"
var memories: Array = []
var diary: Array = []
var goals: Array = []
var http: HTTPRequest
var last_latency := 0.0
var last_observation := ""
var last_response := ""
var validation_error := ""
var decision_cooldown := 0.0
var person_pos := Vector2(420, 390)
var labels := {}

func _ready() -> void:
	_load_game()
	http = HTTPRequest.new(); http.timeout = 15.0; add_child(http); http.request_completed.connect(_on_llm_response)
	_add_room_art()
	_build_ui(); queue_redraw(); _request_decision()

func _add_room_art() -> void:
	var texture := load("res://assets/room_background.png") as Texture2D
	if texture == null: return
	var room_art := TextureRect.new()
	room_art.texture = texture
	room_art.position = Vector2(40, 40)
	room_art.size = Vector2(820, 600)
	room_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_art.z_index = -1
	add_child(room_art)

func _process(delta: float) -> void:
	var minutes := delta * speed * 2.0
	if status != "thinking": sim_minutes += minutes; _tick_needs(minutes)
	if action_remaining > 0: action_remaining -= minutes; _move_visual(delta)
	if action_remaining <= 0 and current_action != "idle" and status == "acting": _finish_action()
	decision_cooldown = max(0.0, decision_cooldown - delta)
	if status == "idle" and decision_cooldown <= 0: _request_decision()
	_update_ui(); queue_redraw()

func _tick_needs(minutes: float) -> void:
	for key in NEED_RATES: needs[key] = clamp(needs[key] + NEED_RATES[key] * minutes, 0.0, 100.0)
	if needs.hunger > 85: needs.stress = min(100.0, needs.stress + minutes * 0.03)
	if needs.thirst > 85: needs.stress = min(100.0, needs.stress + minutes * 0.06)
	if needs.sleepiness > 90: needs.discomfort = min(100.0, needs.discomfort + minutes * 0.05)
	if needs.hygiene_need > 85: needs.discomfort = min(100.0, needs.discomfort + minutes * 0.04)

func _request_decision() -> void:
	if status == "thinking": return
	status = "thinking"; _update_ui()
	var obs := _observation(); last_observation = JSON.stringify(obs)
	var cfg := _config(); var body := {"model":cfg.model,"temperature":cfg.temperature,"max_tokens":256,"response_format":{"type":"json_object"},"messages":[{"role":"system","content":_prompt()},{"role":"user","content":JSON.stringify(obs)}]}
	var started := Time.get_ticks_msec(); var err := http.request(str(cfg.base_url).trim_suffix("/") + "/chat/completions", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK: _fallback("LLM request error"); return
	last_latency = (Time.get_ticks_msec() - started) / 1000.0

func _on_llm_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300: _fallback("LLM unavailable (%s)" % code); return
	last_response = body.get_string_from_utf8(); var parsed = JSON.parse_string(last_response)
	var content := ""; if parsed is Dictionary: content = str(parsed.get("choices", [{}])[0].get("message", {}).get("content", ""))
	var decision = JSON.parse_string(content)
	if not _validate_decision(decision): _fallback(validation_error); return
	_apply_goals(decision.get("goal_updates", {})); _start_action(decision.action.id, str(decision.action.get("target", "")), str(decision.get("reason", "")))

func _validate_decision(d) -> bool:
	validation_error = ""
	if not (d is Dictionary and d.has("action") and d.action is Dictionary): validation_error="Malformed JSON"; return false
	var id := str(d.action.get("id", "")); if id not in ACTIONS: validation_error="Unknown action"; return false
	if id == "eat_food" and inventory.simple_food <= 0: validation_error="No food"; return false
	if id == "drink_water" and inventory.water <= 0: validation_error="No water"; return false
	return true

func _fallback(message: String) -> void:
	status="error"; reason="%s; I will wait." % message; validation_error=message; decision_cooldown=3.0; _start_action("wait", "", reason)

func _start_action(id: String, _target: String, why: String) -> void:
	current_action=id; reason=why if why else ACTION_NAMES.get(id,id); status="acting"; action_remaining=10.0 if id in ["wait","sit","inspect_object"] else 30.0
	if id == "sleep": action_remaining=120.0

func _finish_action() -> void:
	var id:=current_action
	if id == "eat_food" and inventory.simple_food > 0: inventory.simple_food -= 1
	if id == "drink_water" and inventory.water > 0: inventory.water -= 1
	for key in EFFECTS.get(id, {}): needs[key]=clamp(needs[key]+EFFECTS[id][key],0.0,100.0)
	if id == "clean_room": room_cleanliness=min(100.0,room_cleanliness+20)
	if id == "take_out_trash": inventory.trash=0
	if id == "write_diary": diary.push_front({"time":_time_text(),"text":reason})
	memories.push_front({"time":_time_text(),"type":"episode","summary":"I %s." % ACTION_NAMES.get(id,id).to_lower(),"salience":0.5})
	memories=memories.slice(0,20); _log_decision(id); current_action="idle"; status="idle"; decision_cooldown=1.0; _save_game()

func _observation() -> Dictionary:
	return {"time":_time_text(),"self":{"needs":needs,"current_action":current_action,"location":"room"},"room":{"cleanliness":room_cleanliness,"trash_level":inventory.trash,"light_on":true},"objects":["bed","desk","fridge","sink","shower","toilet","bookshelf","pc","tv","window"],"inventory_and_resources":{"fridge":{"water":inventory.water,"simple_food":inventory.simple_food},"bookshelf":{"book":inventory.book}},"active_goals":goals,"recent_memories":memories.slice(0,6),"available_actions":ACTIONS}

func _prompt() -> String:
	var f:=FileAccess.open("res://ai/prompts/resident_system_prompt.txt",FileAccess.READ); return f.get_as_text() if f else "Choose an available action and return JSON."

func _config() -> Dictionary:
	if FileAccess.file_exists("user://one_room_config.json"): var d=JSON.parse_string(FileAccess.get_file_as_string("user://one_room_config.json")); if d is Dictionary: return d
	return DEFAULT_CONFIG

func _apply_goals(u: Dictionary) -> void:
	for g in u.get("add",[]): if goals.size()<5 and str(g).length()>0: goals.append(str(g))
	for g in u.get("complete",[]): goals.erase(str(g))

func _time_text() -> String: return "Day %d %02d:%02d" % [int(sim_minutes/1440)+1,int(fmod(sim_minutes,1440)/60),int(fmod(sim_minutes,60))]
func _move_visual(delta:float)->void: person_pos.x=380+sin(sim_minutes/90.0)*120
func _log_decision(id:String)->void: var f=FileAccess.open("user://decision_log.jsonl",FileAccess.READ_WRITE); if f: f.seek_end(); f.store_line(JSON.stringify({"time":_time_text(),"action":id,"reason":reason,"latency":last_latency,"validation":"valid"}))
func _save_game()->void: var f=FileAccess.open("user://one_room_save.json",FileAccess.WRITE); if f: f.store_string(JSON.stringify({"sim_minutes":sim_minutes,"needs":needs,"inventory":inventory,"room_cleanliness":room_cleanliness,"memories":memories,"diary":diary,"goals":goals}))
func _load_game()->void: if FileAccess.file_exists("user://one_room_save.json"): var d=JSON.parse_string(FileAccess.get_file_as_string("user://one_room_save.json")); if d is Dictionary: sim_minutes=d.get("sim_minutes",480); needs=d.get("needs",needs); inventory=d.get("inventory",inventory); room_cleanliness=d.get("room_cleanliness",82); memories=d.get("memories",[]); diary=d.get("diary",[]); goals=d.get("goals",[])

func _build_ui()->void:
	labels.time=_label(Vector2(930,30),"",24); labels.action=_label(Vector2(930,75),"",20); labels.reason=_label(Vector2(930,115),"",16); labels.reason.size=Vector2(320,70); labels.panel=_label(Vector2(930,205),"",15); labels.panel.size=Vector2(320,430)
	for i in range(ACTIONS.size()): pass
	var save:=Button.new(); save.text="Save"; save.position=Vector2(930,650); save.pressed.connect(_save_game); add_child(save)
	var speeds:=OptionButton.new(); speeds.position=Vector2(1010,650)
	for x in [1,2,4,8]:
		speeds.add_item("%sx"%x)
	speeds.item_selected.connect(func(i): speed=pow(2,i))
	add_child(speeds)
func _label(pos:Vector2,text:String,size:int)->Label: var l:=Label.new(); l.position=pos; l.text=text; l.add_theme_font_size_override("font_size",size); add_child(l); return l
func _update_ui()->void:
	if not labels.has("time"): return
	labels.time.text=_time_text(); labels.action.text="Action: %s (%s)"%[ACTION_NAMES.get(current_action,current_action),status]; labels.reason.text="Reason: "+reason
	var s="NEEDS\n"; for k in needs: s += "%s: %3d\n"%[k,int(needs[k])]
	s+="\nGOALS\n"+("none\n" if goals.is_empty() else "\n".join(goals)+"\n"); s+="\nMEMORIES\n"; for m in memories.slice(0,5): s+=str(m.summary)+"\n"; s+="\nDiary: %d entries\nLLM latency: %.2fs"%[diary.size(),last_latency]; labels.panel.text=s

func _draw()->void:
	draw_rect(Rect2(0,0,900,720),Color("#263238")); draw_rect(Rect2(40,40,820,600),Color("#d7b98e")); draw_rect(Rect2(40,560,820,80),Color("#9a7653"));
	var furniture={"BED":Rect2(80,390,180,100),"DESK":Rect2(330,400,180,70),"FRIDGE":Rect2(700,150,80,170),"SHOWER":Rect2(560,100,100,90),"TOILET":Rect2(700,370,80,70),"BOOKS":Rect2(90,120,150,100),"TV":Rect2(350,150,170,30),"WINDOW":Rect2(300,55,230,45)}
	for n in furniture: draw_rect(furniture[n],Color("#795548")); draw_string(ThemeDB.fallback_font,furniture[n].position+Vector2(8,25),n,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	draw_circle(person_pos,24,Color("#4fc3f7")); draw_string(ThemeDB.fallback_font,person_pos+Vector2(-30,-32),"Resident",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#102027"))
