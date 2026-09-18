class_name ObserverContext
extends RefCounted

static func relevant_memory_note(memory:Dictionary)->String:
	var summary:=str(memory.get("summary","" )).strip_edges()
	return "Relevant memory: %s" % summary if summary!="" else "Relevant memory was available."
