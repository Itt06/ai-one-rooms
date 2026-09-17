class_name DecisionSchema
extends RefCounted

static func validate(raw) -> Dictionary:
	if not raw is Dictionary: return _fail("decision_must_be_object")
	var kind=raw.get("decision_type",null)
	if kind!="plan" and kind!="skill": return _fail("missing_or_unknown_decision_type")
	var required:Array=["decision_type","reason","plan","goal_updates"] if kind=="plan" else ["decision_type","reason","skill","goal_updates"]
	var forbidden:= "skill" if kind=="plan" else "plan"
	for key in required: if not raw.has(key): return _fail("missing_%s"%key)
	if raw.has(forbidden): return _fail("%s_not_allowed_for_%s"%[forbidden,kind])
	for key in raw: if key not in required and key!="intention": return _fail("unexpected_top_level_field_%s"%key)
	if not raw.reason is String or str(raw.reason).length()>200: return _fail("invalid_reason")
	if raw.has("intention") and (not raw.intention is String or str(raw.intention).length()>160): return _fail("invalid_intention")
	if not raw.goal_updates is Dictionary: return _fail("invalid_goal_updates")
	if kind=="plan":
		if not raw.plan is Array or raw.plan.is_empty() or raw.plan.size()>6: return _fail("plan_must_contain_1_to_6_steps")
		for step in raw.plan:
			if not step is Dictionary or step.keys().size()!=2 or not step.has("tool") or not step.has("args") or not step.args is Dictionary: return _fail("step_must_have_exactly_tool_and_args_object")
			if not PrimitiveToolCatalog.TOOLS.has(str(step.tool)): return _fail("unknown_tool")
	else:
		if not raw.skill is Dictionary or raw.skill.keys().size()!=2 or not raw.skill.has("id") or not raw.skill.has("args") or not raw.skill.id is String or not raw.skill.args is Dictionary: return _fail("skill_must_have_id_and_args_object")
	return {"ok":true,"error":""}

static func _fail(message:String)->Dictionary:return {"ok":false,"error":message}
