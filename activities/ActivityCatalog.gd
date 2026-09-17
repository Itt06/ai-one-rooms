class_name ActivityCatalog
extends RefCounted

const DEFINITIONS := {
	"read":{"duration_minutes":30.0,"required_tool":"read","target_kind":"item","target_type":"book","effects":{"boredom":-30.0,"stress":-5.0},"activity_label":"reading"},
	"eat":{"duration_minutes":15.0,"required_tool":"eat","target_kind":"item","target_type":"simple_food","effects":{"hunger":-45.0},"consumes_item":true,"activity_label":"eating"},
	"drink":{"duration_minutes":10.0,"required_tool":"drink","target_kind":"object","effects":{"thirst":-50.0},"resource_effect":{"water":-1},"activity_label":"drinking"},
	"sleep":{"duration_minutes":120.0,"required_tool":"sleep","target_kind":"object","target_type":"bed","effects":{"sleepiness":-65.0,"stress":-5.0},"activity_label":"sleeping"},
	"take_shower":{"duration_minutes":30.0,"required_tool":"take_shower","target_kind":"object","target_type":"shower","effects":{"hygiene_need":-55.0,"discomfort":-15.0},"activity_label":"showering"},
	"use_toilet":{"duration_minutes":10.0,"required_tool":"use_toilet","target_kind":"object","target_type":"toilet","effects":{"toilet_need":-80.0,"discomfort":-16.0},"activity_label":"using the toilet"},
	"use_pc":{"duration_minutes":60.0,"required_tool":"use_pc","target_kind":"object","target_type":"pc","effects":{"boredom":-25.0,"stress":3.0},"activity_label":"using the PC"},
	"watch_tv":{"duration_minutes":45.0,"required_tool":"watch_tv","target_kind":"object","target_type":"tv","effects":{"boredom":-30.0},"activity_label":"watching TV"},
	"clean":{"duration_minutes":30.0,"required_tool":"clean","target_kind":"object","target_type":"sink","effects":{"discomfort":-20.0},"activity_label":"cleaning"},
	"look_out_window":{"duration_minutes":15.0,"required_tool":"look_out_window","target_kind":"object","target_type":"window","effects":{"boredom":-8.0,"stress":-2.0},"activity_label":"looking out the window"},
	"write_diary":{"duration_minutes":20.0,"required_tool":"write_diary","target_kind":"object","target_type":"desk","effects":{"stress":-4.0},"activity_label":"writing in the diary"},
	"call_friend":{"duration_minutes":20.0,"required_tool":"call_friend","target_kind":"object","target_type":"phone","effects":{"loneliness":-50.0,"stress":-5.0,"boredom":-8.0},"activity_label":"calling a friend"},
	"order_groceries":{"duration_minutes":10.0,"required_tool":"order_groceries","target_kind":"object","target_type":"pc","effects":{},"resource_effect":{"simple_food":6},"activity_label":"ordering groceries"},
	"take_out_trash":{"duration_minutes":15.0,"required_tool":"take_out_trash","target_kind":"object","target_type":"trash_bin","effects":{"discomfort":-10.0},"activity_label":"taking out the trash"},
	"wait":{"duration_minutes":10.0,"required_tool":"wait","target_kind":"none","effects":{},"activity_label":"waiting"}
}

static func get_definition(id:String)->Dictionary: return DEFINITIONS.get(id,{})
