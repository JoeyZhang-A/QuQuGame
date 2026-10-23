extends RefCounted

const ConfigLib = preload("res://src/core/config.gd")
const RulesLib = preload("res://src/core/rules.gd")
const MatchLib = preload("res://src/core/match.gd")


static func collect() -> Array:
	var out: Array = []
	out.append(_phases())
	out.append(_timeout())
	out.append(_out_of_bounds())
	out.append(_occupied())
	out.append(_one_slot())
	out.append(_approach_retreat())
	return out


static func _ok(name: String) -> Dictionary:
	return {"ok": true, "name": name, "expected": "", "actual": ""}


static func _bad(name: String, expected: String, actual: String) -> Dictionary:
	return {"ok": false, "name": name, "expected": expected, "actual": actual}


static func _phases() -> Dictionary:
	var name: String = "1 动作三阶段之和恒等于 450"
	var loaded: Dictionary = ConfigLib.load_project()
	if not bool(loaded["ok"]):
		return _bad(name, "配置可加载", str(loaded["error"]))
	var config: Config = loaded["config"]
	var actions: Dictionary = config.actions()
	if actions.size() != 5:
		return _bad(name, "5 个动作", str(actions.size()))
	for action_name in ConfigLib.ACTION_NAMES:
		if not actions.has(action_name):
			return _bad(name, action_name, "缺失")
		var spec: Dictionary = actions[action_name]
		var total: int = int(spec["windup"]) + int(spec["active"]) + int(spec["recover"])
		if total != 450:
			return _bad(name, "450", "%s=%d" % [action_name, total])
	return _ok(name)


static func _timeout() -> Dictionary:
	var name: String = "2 单局到 tick == 133 必停"
	var loaded: Dictionary = ConfigLib.load_project()
	if not bool(loaded["ok"]):
		return _bad(name, "配置可加载", str(loaded["error"]))
	var config: Config = loaded["config"]
	var result: Dictionary = MatchLib.simulate_hold(config, "scale", "rush")
	if int(result["tick"]) != 133:
		return _bad(name, "tick 133", str(result["tick"]))
	if int(result["tick_after_extra"]) != 133:
		return _bad(name, "再推进一步仍是 133", str(result["tick_after_extra"]))
	if not bool(result["finished"]):
		return _bad(name, "finished", "false")
	if int(result["hold_before_extra"]) != 133 or int(result["hold_after_extra"]) != 133:
		return _bad(name, "consec_hold 133 且不再增加", "%s -> %s" % [str(result["hold_before_extra"]), str(result["hold_after_extra"])])
	if int(result["first_x"]) != 1 or int(result["first_y"]) != 1:
		return _bad(name, "(1,1)", "(%s,%s)" % [str(result["first_x"]), str(result["first_y"])])
	if int(result["second_x"]) != 3 or int(result["second_y"]) != 1:
		return _bad(name, "(3,1)", "(%s,%s)" % [str(result["second_x"]), str(result["second_y"])])
	if int(result["first_facing_x"]) != 1 or int(result["first_facing_y"]) != 0:
		return _bad(name, "先手朝向 (1,0)", "(%s,%s)" % [str(result["first_facing_x"]), str(result["first_facing_y"])])
	if int(result["second_facing_x"]) != -1 or int(result["second_facing_y"]) != 0:
		return _bad(name, "后手朝向 (-1,0)", "(%s,%s)" % [str(result["second_facing_x"]), str(result["second_facing_y"])])
	if int(result["first_stamina"]) != 100 or int(result["second_stamina"]) != 100:
		return _bad(name, "体力 100", "%s,%s" % [str(result["first_stamina"]), str(result["second_stamina"])])
	if int(result["first_pressure"]) != 0 or int(result["second_pressure"]) != 0:
		return _bad(name, "压力 0", "%s,%s" % [str(result["first_pressure"]), str(result["second_pressure"])])
	if str(result["first_action"]) != "hold" or str(result["second_action"]) != "hold":
		return _bad(name, "hold", "%s,%s" % [str(result["first_action"]), str(result["second_action"])])
	if int(result["second_hold"]) != 133:
		return _bad(name, "后手 consec_hold 133", str(result["second_hold"]))
	return _ok(name)


static func _out_of_bounds() -> Dictionary:
	var name: String = "3 移出场地边界时留在原槽"
	var direct: Dictionary = RulesLib.apply_step(0, 1, -1, 0, 3, 1, 5, 3)
	if bool(direct["moved"]) or int(direct["x"]) != 0 or int(direct["y"]) != 1:
		return _bad(name, "(0,1)", "(%s,%s)" % [str(direct["x"]), str(direct["y"])])
	var corner: Dictionary = RulesLib.apply_step(4, 2, 1, 0, 0, 0, 5, 3)
	if bool(corner["moved"]) or int(corner["x"]) != 4 or int(corner["y"]) != 2:
		return _bad(name, "(4,2)", "(%s,%s)" % [str(corner["x"]), str(corner["y"])])
	var retreat: Dictionary = RulesLib.resolve("away", 0, 1, 1, 1, 5, 3)
	if bool(retreat["moved"]) or int(retreat["x"]) != 0 or int(retreat["y"]) != 1:
		return _bad(name, "retreat 留在 (0,1)", "(%s,%s)" % [str(retreat["x"]), str(retreat["y"])])
	return _ok(name)


static func _occupied() -> Dictionary:
	var name: String = "4 目标槽被对手占据时留在原槽"
	var direct: Dictionary = RulesLib.apply_step(1, 1, 1, 0, 2, 1, 5, 3)
	if bool(direct["moved"]) or int(direct["x"]) != 1 or int(direct["y"]) != 1:
		return _bad(name, "(1,1)", "(%s,%s)" % [str(direct["x"]), str(direct["y"])])
	var approach: Dictionary = RulesLib.resolve("near", 1, 1, 2, 1, 5, 3)
	if bool(approach["moved"]) or int(approach["x"]) != 1 or int(approach["y"]) != 1:
		return _bad(name, "approach 留在 (1,1)", "(%s,%s)" % [str(approach["x"]), str(approach["y"])])
	return _ok(name)


static func _one_slot() -> Dictionary:
	var name: String = "5 一拍内位移不超过 1 槽"
	var samples: Array = [[0, 0], "near", "away", "side", [2, 0], [-2, 0], [0, 2], [1, 1], [-1, 1]]
	for x in range(5):
		for y in range(3):
			for opp_x in range(5):
				for opp_y in range(3):
					if x == opp_x and y == opp_y:
						continue
					for sample in samples:
						var resolved: Dictionary = RulesLib.resolve(sample, x, y, opp_x, opp_y, 5, 3)
						var dx: int = absi(int(resolved["x"]) - x)
						var dy: int = absi(int(resolved["y"]) - y)
						if dx + dy > 1 or (dx > 0 and dy > 0):
							return _bad(name, "正交且不超过 1 槽", "(%d,%d)->(%s,%s) %s" % [x, y, str(resolved["x"]), str(resolved["y"]), str(sample)])
						var changed: bool = dx + dy > 0
						if bool(resolved["moved"]) != changed:
							return _bad(name, "moved 与位移一致", str(resolved))
	return _ok(name)


static func _approach_retreat() -> Dictionary:
	var name: String = "6 approach 使距离减 1，retreat 使距离加 1"
	var horizontal: Dictionary = _distance_pair(1, 1, 4, 1)
	if not bool(horizontal["ok"]):
		return _bad(name, str(horizontal["expected"]), str(horizontal["actual"]))
	var vertical_approach: Dictionary = RulesLib.resolve("near", 2, 0, 2, 2, 5, 3)
	var vertical_before: int = RulesLib.manhattan(2, 0, 2, 2)
	var vertical_after: int = RulesLib.manhattan(int(vertical_approach["x"]), int(vertical_approach["y"]), 2, 2)
	if vertical_before - vertical_after != 1:
		return _bad(name, "纵向 approach 减 1", str(vertical_before - vertical_after))
	var vertical_retreat: Dictionary = RulesLib.resolve("away", 2, 1, 2, 0, 5, 3)
	var retreat_before: int = RulesLib.manhattan(2, 1, 2, 0)
	var retreat_after: int = RulesLib.manhattan(int(vertical_retreat["x"]), int(vertical_retreat["y"]), 2, 0)
	if retreat_after - retreat_before != 1:
		return _bad(name, "纵向 retreat 加 1", str(retreat_after - retreat_before))
	return _ok(name)


static func _distance_pair(x: int, y: int, opp_x: int, opp_y: int) -> Dictionary:
	var before: int = RulesLib.manhattan(x, y, opp_x, opp_y)
	var approach: Dictionary = RulesLib.resolve("near", x, y, opp_x, opp_y, 5, 3)
	var approach_dist: int = RulesLib.manhattan(int(approach["x"]), int(approach["y"]), opp_x, opp_y)
	if before - approach_dist != 1:
		return {"ok": false, "expected": "approach 减 1", "actual": "%d -> %d" % [before, approach_dist]}
	var retreat: Dictionary = RulesLib.resolve("away", x, y, opp_x, opp_y, 5, 3)
	var retreat_dist: int = RulesLib.manhattan(int(retreat["x"]), int(retreat["y"]), opp_x, opp_y)
	if retreat_dist - before != 1:
		return {"ok": false, "expected": "retreat 加 1", "actual": "%d -> %d" % [before, retreat_dist]}
	return {"ok": true, "expected": "", "actual": ""}
