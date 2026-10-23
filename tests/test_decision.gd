extends RefCounted

const DecisionLib = preload("res://src/core/decision.gd")


static func collect() -> Array:
	var out: Array = []
	out.append(_tie_break())
	return out


static func _ok(name: String) -> Dictionary:
	return {"ok": true, "name": name, "expected": "", "actual": ""}


static func _bad(name: String, expected: String, actual: String) -> Dictionary:
	return {"ok": false, "name": name, "expected": expected, "actual": actual}


static func _tie_break() -> Dictionary:
	var name: String = "22 平局打破优先级为 bite > approach > flank > hold > retreat"
	var order: Array = ["bite", "approach", "flank", "hold", "retreat"]
	var all_even: Dictionary = {"bite": 0, "approach": 0, "flank": 0, "hold": 0, "retreat": 0}
	if DecisionLib.pick_action(order, all_even) != "bite":
		return _bad(name, "bite", DecisionLib.pick_action(order, all_even))
	var approach_higher: Dictionary = {"bite": 1, "approach": 5, "flank": 5, "hold": 5, "retreat": 5}
	if DecisionLib.pick_action(order, approach_higher) != "approach":
		return _bad(name, "approach", DecisionLib.pick_action(order, approach_higher))
	var flank_tie: Dictionary = {"bite": 0, "approach": 0, "flank": 4, "hold": 4, "retreat": 4}
	if DecisionLib.pick_action(order, flank_tie) != "flank":
		return _bad(name, "flank", DecisionLib.pick_action(order, flank_tie))
	var hold_tie: Dictionary = {"bite": 0, "approach": 0, "flank": 0, "hold": 2, "retreat": 2}
	if DecisionLib.pick_action(order, hold_tie) != "hold":
		return _bad(name, "hold", DecisionLib.pick_action(order, hold_tie))
	var retreat_only: Dictionary = {"bite": 0, "approach": 0, "flank": 0, "hold": 0, "retreat": 3}
	if DecisionLib.pick_action(order, retreat_only) != "retreat":
		return _bad(name, "retreat", DecisionLib.pick_action(order, retreat_only))
	return _ok(name)
