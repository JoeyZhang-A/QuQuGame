extends RefCounted

const ConfigLib = preload("res://src/core/config.gd")
const RulesLib = preload("res://src/core/rules.gd")
const MatchLib = preload("res://src/core/match.gd")


static func collect() -> Array:
	var out: Array = []
	out.append(_out_of_range())
	out.append(_facing())
	out.append(_hit())
	out.append(_retreated())
	out.append(_suppress())
	out.append(_counter())
	out.append(_even())
	out.append(_grapple_tick_silent())
	out.append(_stun_lock())
	out.append(_panic_ratio())
	out.append(_clash())
	return out


static func _ok(name: String) -> Dictionary:
	return {"ok": true, "name": name, "expected": "", "actual": ""}


static func _bad(name: String, expected: String, actual: String) -> Dictionary:
	return {"ok": false, "name": name, "expected": expected, "actual": actual}


static func _bout() -> Match:
	var loaded: Dictionary = ConfigLib.load_project()
	return MatchLib.new(loaded["config"], "scale", "rush")


static func _place(bout: Match, ax: int, ay: int, afx: int, afy: int, bx: int, by: int, bfx: int, bfy: int) -> void:
	bout.first.x = ax
	bout.first.y = ay
	bout.first.facing_x = afx
	bout.first.facing_y = afy
	bout.second.x = bx
	bout.second.y = by
	bout.second.facing_x = bfx
	bout.second.facing_y = bfy


static func _whiff_reason(bout: Match, actor: String) -> String:
	for row in bout.events:
		var event: Dictionary = row
		if str(event["type"]) == "whiff" and str(event["actor"]) == actor:
			return str(event["reason"])
	return ""


static func _count(bout: Match, event_type: String, at_tick: int) -> int:
	var total: int = 0
	for row in bout.events:
		var event: Dictionary = row
		if str(event["type"]) == event_type and int(event["tick"]) == at_tick:
			total += 1
	return total


static func _out_of_range() -> Dictionary:
	var name: String = "7 距离 2 时 bite 必 whiff，reason == out_of_range"
	var bout: Match = _bout()
	bout.step_forced("bite", "hold")
	var reason: String = _whiff_reason(bout, "scale")
	if reason != "out_of_range":
		return _bad(name, "out_of_range", reason)
	if bout.pending_grapple:
		return _bad(name, "不进角力", "pending")
	return _ok(name)


static func _facing() -> Dictionary:
	var name: String = "8 相邻但朝向相反时 bite 必 whiff，reason == facing"
	var bout: Match = _bout()
	_place(bout, 1, 1, -1, 0, 2, 1, 1, 0)
	bout.step_forced("bite", "hold")
	var reason: String = _whiff_reason(bout, "scale")
	if reason != "facing":
		return _bad(name, "facing", reason)
	return _ok(name)


static func _hit() -> Dictionary:
	var name: String = "9 相邻且朝向前方时命中"
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.step_forced("bite", "hold")
	if not bout.pending_grapple:
		return _bad(name, "进入角力", "未命中")
	if _whiff_reason(bout, "scale") != "":
		return _bad(name, "无 whiff", _whiff_reason(bout, "scale"))
	return _ok(name)


static func _retreated() -> Dictionary:
	var name: String = "10 对手本拍 retreat 成功时 bite 落空，reason == retreated"
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.step_forced("bite", "retreat")
	var reason: String = _whiff_reason(bout, "scale")
	if reason != "retreated":
		return _bad(name, "retreated", reason)
	if bout.second.x != 4 or bout.second.y != 1:
		return _bad(name, "后撤到 (4,1)", "(%d,%d)" % [bout.second.x, bout.second.y])
	return _ok(name)


static func _suppress() -> Dictionary:
	var name: String = "11 角力压制：守方体力 -18，被推开 1 槽"
	var power: int = RulesLib.attack_power(100, 90, 0)
	if power != 96:
		return _bad(name, "攻方有效力 96", str(power))
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.first.stamina = 100
	bout.first.param_e = 90
	bout.first.pressure = 0
	bout.second.stamina = 40
	bout.second.param_e = 10
	bout.second.pressure = 0
	bout.step_forced("bite", "hold")
	var def_before: int = bout.second.stamina
	var att_before: int = bout.first.stamina
	bout.step()
	if att_before - bout.first.stamina != 6:
		return _bad(name, "攻方 -6", str(att_before - bout.first.stamina))
	if def_before - bout.second.stamina != 18:
		return _bad(name, "守方 -18", str(def_before - bout.second.stamina))
	if bout.second.x != 4 or bout.second.y != 1:
		return _bad(name, "守方被推到 (4,1)", "(%d,%d)" % [bout.second.x, bout.second.y])
	if bout.first.x != 2:
		return _bad(name, "攻方留在 x=2", str(bout.first.x))
	return _ok(name)


static func _counter() -> Dictionary:
	var name: String = "12 角力被反制：攻方体力 -14，被推开 1 槽"
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.first.stamina = 20
	bout.first.param_e = 0
	bout.first.pressure = 0
	bout.second.stamina = 100
	bout.second.param_e = 90
	bout.second.pressure = 0
	bout.step_forced("bite", "hold")
	var att_before: int = bout.first.stamina
	bout.step()
	if att_before - bout.first.stamina != 14:
		return _bad(name, "攻方 -14", str(att_before - bout.first.stamina))
	if bout.first.x != 1 or bout.first.y != 1:
		return _bad(name, "攻方被推到 (1,1)", "(%d,%d)" % [bout.first.x, bout.first.y])
	if bout.second.x != 3:
		return _bad(name, "守方留在 x=3", str(bout.second.x))
	return _ok(name)


static func _even() -> Dictionary:
	var name: String = "13 角力僵平：双方 -8，位置不变"
	var att_power: int = RulesLib.attack_power(100, 50, 0)
	var def_power: int = RulesLib.defense_power(100, 50, 0)
	var result: String = RulesLib.grapple_result(att_power, def_power, 115, 100, 87, 100)
	if result != "even":
		return _bad(name, "even", "%s att=%d def=%d" % [result, att_power, def_power])
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.first.stamina = 100
	bout.first.param_e = 50
	bout.second.stamina = 100
	bout.second.param_e = 50
	bout.step_forced("bite", "hold")
	var att_before: int = bout.first.stamina
	var def_before: int = bout.second.stamina
	bout.step()
	if att_before - bout.first.stamina != 8 or def_before - bout.second.stamina != 8:
		return _bad(name, "双方 -8", "%d,%d" % [att_before - bout.first.stamina, def_before - bout.second.stamina])
	if bout.first.x != 2 or bout.second.x != 3:
		return _bad(name, "位置不变", "(%d,%d)" % [bout.first.x, bout.second.x])
	return _ok(name)


static func _grapple_tick_silent() -> Dictionary:
	var name: String = "14 角力占一整拍，该拍双方都不产生决策记录"
	var bout: Match = _hit_pair()
	var grapple_tick: int = bout.tick
	bout.step()
	if _count(bout, "tick", grapple_tick) != 0:
		return _bad(name, "0 条 tick", str(_count(bout, "tick", grapple_tick)))
	if _count(bout, "grapple", grapple_tick) != 1:
		return _bad(name, "1 条 grapple", str(_count(bout, "grapple", grapple_tick)))
	return _ok(name)


static func _stun_lock() -> Dictionary:
	var name: String = "15 角力后双方下一拍锁定，不得选择其他动作"
	var bout: Match = _hit_pair()
	bout.step()
	var att_before: int = bout.first.stamina
	var def_before: int = bout.second.stamina
	bout.step_forced("bite", "approach")
	if bout.first.last_action != "hold" or bout.second.last_action != "hold":
		return _bad(name, "hold/hold", "%s/%s" % [bout.first.last_action, bout.second.last_action])
	if bout.first.stamina != att_before or bout.second.stamina != def_before:
		return _bad(name, "硬直不回复体力", "%d->%d %d->%d" % [att_before, bout.first.stamina, def_before, bout.second.stamina])
	if bout.pending_grapple:
		return _bad(name, "锁定拍不进新角力", "pending")
	return _ok(name)


static func _panic_ratio() -> Dictionary:
	var name: String = "16 pressure > 85 时有效力 ×0.85"
	var calm: int = RulesLib.attack_power(90, 0, 0)
	var panicked: int = RulesLib.attack_power(90, 0, 90)
	if panicked != RulesLib.idiv(calm * 850, 1000):
		return _bad(name, "有效力 ×0.85", "%d -> %d" % [calm, panicked])
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.first.stamina = 90
	bout.first.param_e = 0
	bout.first.pressure = 90
	bout.second.stamina = 80
	bout.second.param_e = 0
	bout.second.pressure = 0
	bout.step_forced("bite", "hold")
	var def_before: int = bout.second.stamina
	bout.step()
	if def_before - bout.second.stamina != 8:
		return _bad(name, "高压后僵平，守方 -8", str(def_before - bout.second.stamina))
	return _ok(name)


static func _clash() -> Dictionary:
	var name: String = "17 双方同拍互咬：各 -12 体力、各 +15 压力、各被推开 1 槽、下一拍不锁定"
	var bout: Match = _bout()
	_place(bout, 1, 1, 1, 0, 2, 1, -1, 0)
	bout.first.stamina = 80
	bout.second.stamina = 80
	bout.first.pressure = 0
	bout.second.pressure = 0
	bout.step_forced("bite", "bite")
	if bout.pending_grapple:
		return _bad(name, "不进角力", "pending")
	if bout.first.stamina != 68 or bout.second.stamina != 68:
		return _bad(name, "体力 68", "%d,%d" % [bout.first.stamina, bout.second.stamina])
	if bout.first.pressure != 15 or bout.second.pressure != 15:
		return _bad(name, "压力 15", "%d,%d" % [bout.first.pressure, bout.second.pressure])
	if bout.first.x != 0 or bout.second.x != 3:
		return _bad(name, "推到 x=0 与 x=3", "%d,%d" % [bout.first.x, bout.second.x])
	if _count(bout, "clash", 0) != 1:
		return _bad(name, "1 条 clash", str(_count(bout, "clash", 0)))
	if _count(bout, "tick", 0) != 2:
		return _bad(name, "2 条 tick", str(_count(bout, "tick", 0)))
	bout.step_forced("approach", "approach")
	if bout.first.last_action != "approach" or bout.second.last_action != "approach":
		return _bad(name, "下一拍可选择 approach", "%s/%s" % [bout.first.last_action, bout.second.last_action])
	return _ok(name)


static func _hit_pair() -> Match:
	var bout: Match = _bout()
	_place(bout, 2, 1, 1, 0, 3, 1, -1, 0)
	bout.first.stamina = 100
	bout.first.param_e = 90
	bout.second.stamina = 40
	bout.second.param_e = 10
	bout.step_forced("bite", "hold")
	return bout
