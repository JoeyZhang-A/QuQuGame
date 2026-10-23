extends RefCounted

const ConfigLib = preload("res://src/core/config.gd")
const CricketLib = preload("res://src/core/cricket.gd")
const DecisionLib = preload("res://src/core/decision.gd")


static func collect() -> Array:
	var out: Array = []
	out.append(_tie_break())
	out.append(_stable())
	out.append(_rage())
	out.append(_shrink())
	out.append(_hold_chain())
	out.append(_six_cap())
	out.append(_pure())
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


static func _weights() -> Dictionary:
	var loaded: Dictionary = ConfigLib.load_project()
	var config: Config = loaded["config"]
	return config.weights()


static func _pair() -> Array:
	var actor: Cricket = CricketLib.new()
	actor.x = 1
	actor.y = 1
	actor.facing_x = 1
	actor.facing_y = 0
	actor.stamina = 80
	actor.pressure = 10
	actor.param_a = 20
	actor.param_r = 15
	actor.param_e = 90
	actor.param_s = 0
	actor.param_p = 25
	var opp: Cricket = CricketLib.new()
	opp.x = 3
	opp.y = 1
	return [actor, opp]


static func _stable() -> Dictionary:
	var name: String = "23 同一状态连续调用 decide 10 次，结果一致"
	var pair: Array = _pair()
	var actor: Cricket = pair[0]
	var opp: Cricket = pair[1]
	var weights: Dictionary = _weights()
	var features: Dictionary = DecisionLib.compute_features(actor, opp)
	var expected: Dictionary = {"hold": 25510, "retreat": -4180, "approach": -1925, "flank": 8175, "bite": -10000}
	for action_name in expected.keys():
		var actual: int = DecisionLib.score_action(str(action_name), features, actor, weights, 30)
		if actual != int(expected[action_name]):
			return _bad(name, "%s=%s" % [str(action_name), str(expected[action_name])], str(actual))
	var first: Dictionary = DecisionLib.evaluate(actor, opp, weights, 30)
	for _i in 9:
		var again: Dictionary = DecisionLib.evaluate(actor, opp, weights, 30)
		if str(again["action"]) != str(first["action"]):
			return _bad(name, str(first["action"]), str(again["action"]))
		if str(again["scores"]) != str(first["scores"]):
			return _bad(name, str(first["scores"]), str(again["scores"]))
	return _ok(name)


static func _rage() -> Dictionary:
	var name: String = "24 S > 0 的虫在压力跨 60 时，bite 分数上升"
	var pair: Array = _pair()
	var actor: Cricket = pair[0]
	var opp: Cricket = pair[1]
	actor.param_s = 40
	actor.pressure = 60
	var weights: Dictionary = _weights()
	var before: Dictionary = DecisionLib.compute_features(actor, opp)
	var low: int = DecisionLib.score_action("bite", before, actor, weights, 30)
	actor.pressure = 61
	var after: Dictionary = DecisionLib.compute_features(actor, opp)
	var high: int = DecisionLib.score_action("bite", after, actor, weights, 30)
	if high - low != 400:
		return _bad(name, "上升 400", str(high - low))
	return _ok(name)


static func _shrink() -> Dictionary:
	var name: String = "25 S < 0 的虫在压力跨 60 时，retreat 分数上升"
	var pair: Array = _pair()
	var actor: Cricket = pair[0]
	var opp: Cricket = pair[1]
	actor.param_s = -40
	actor.pressure = 60
	var weights: Dictionary = _weights()
	var before: Dictionary = DecisionLib.compute_features(actor, opp)
	var low: int = DecisionLib.score_action("retreat", before, actor, weights, 30)
	actor.pressure = 61
	var after: Dictionary = DecisionLib.compute_features(actor, opp)
	var high: int = DecisionLib.score_action("retreat", after, actor, weights, 30)
	if high - low != 350:
		return _bad(name, "上升 350", str(high - low))
	return _ok(name)


static func _hold_chain() -> Dictionary:
	var name: String = "26 连续 3 拍 hold 后第 4 拍 hold 分数被扣 120"
	var pair: Array = _pair()
	var actor: Cricket = pair[0]
	var opp: Cricket = pair[1]
	actor.last_action = "hold"
	actor.consec_hold = 2
	var weights: Dictionary = _weights()
	var features: Dictionary = DecisionLib.compute_features(actor, opp)
	var before: int = DecisionLib.score_action("hold", features, actor, weights, 30)
	actor.consec_hold = 3
	var after: int = DecisionLib.score_action("hold", features, actor, weights, 30)
	if before - after != 120:
		return _bad(name, "扣 120", str(before - after))
	return _ok(name)


static func _six_cap() -> Dictionary:
	var name: String = "27 同一动作连续 6 拍后该动作分数为 -999999"
	var pair: Array = _pair()
	var actor: Cricket = pair[0]
	var opp: Cricket = pair[1]
	actor.chain_action = "bite"
	actor.chain_count = 6
	var weights: Dictionary = _weights()
	var features: Dictionary = DecisionLib.compute_features(actor, opp)
	var value: int = DecisionLib.score_action("bite", features, actor, weights, 30)
	if value != -999999:
		return _bad(name, "-999999", str(value))
	return _ok(name)


static func _pure() -> Dictionary:
	var name: String = "28 特征计算为纯函数：调用前后 state 完全不变"
	var pair: Array = _pair()
	var actor: Cricket = pair[0]
	var opp: Cricket = pair[1]
	var before: String = _stamp(actor)
	var features: Dictionary = DecisionLib.compute_features(actor, opp)
	DecisionLib.score_action("hold", features, actor, _weights(), 30)
	var after: String = _stamp(actor)
	if before != after:
		return _bad(name, before, after)
	return _ok(name)


static func _stamp(actor: Cricket) -> String:
	return "%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d" % [actor.x, actor.y, actor.facing_x, actor.facing_y, actor.stamina, actor.pressure, actor.consec_hold, actor.retreat_chain, actor.last_action, actor.chain_count, actor.param_s]
