extends RefCounted
class_name Match

const CricketLib = preload("res://src/core/cricket.gd")
const RulesLib = preload("res://src/core/rules.gd")
const DecisionLib = preload("res://src/core/decision.gd")

const FIXED_ACTION: String = "hold"
const CLASH_STAMINA: int = -12
const CLASH_PRESSURE: int = 15
const WHIFF_PRESSURE: int = 5

var tick: int = 0
var max_tick: int = 0
var grid_w: int = 0
var grid_h: int = 0
var finished: bool = false
var actions: Dictionary = {}
var grapple_cfg: Dictionary = {}
var roster: Dictionary = {}
var first: Cricket
var second: Cricket
var scripted: Array = []
var phase_log: Array = []
var move_log: Array = []
var events: Array = []
var pending_grapple: bool = false
var grapple_att: Cricket
var grapple_def: Cricket
var center_x: int = 2
var center_y: int = 1
var center_bonus: int = 15
var flee_stamina: int = 20
var flee_consecutive: int = 2
var winner_id: String = ""
var loser_id: String = ""
var end_reason: String = ""
var end_tick: int = -1
var weights: Dictionary = {}
var low_stamina: int = 30


func _init(config: Config, first_id: String, second_id: String) -> void:
	max_tick = config.max_tick()
	grid_w = config.grid_w()
	grid_h = config.grid_h()
	actions = config.actions()
	grapple_cfg = config.grapple()
	var center: Array = config.center()
	center_x = int(center[0])
	center_y = int(center[1])
	var scoring: Dictionary = config.scoring()
	center_bonus = int(scoring["center_bonus"])
	flee_consecutive = int(scoring["flee_consecutive"])
	var limits: Dictionary = config.thresholds()
	flee_stamina = int(limits["flee_stamina"])
	low_stamina = int(limits["low_stamina"])
	weights = config.weights()
	for row in config.crickets():
		var item: Dictionary = row
		roster[str(item["id"])] = item
	first = _make(first_id, 1, 1, 1, 0)
	second = _make(second_id, 3, 1, -1, 0)


func run() -> void:
	while tick < max_tick and not finished:
		step()


func step_forced(first_action: String, second_action: String) -> void:
	scripted = [first_action, second_action]
	step()
	scripted = []


func step() -> void:
	if tick >= max_tick:
		if end_reason == "":
			_settle_timeout()
		finished = true
		return
	if pending_grapple:
		_run_grapple_tick()
		return
	phase_log = []
	var first_locked: bool = first.stun
	var second_locked: bool = second.stun
	first.stun = false
	second.stun = false
	var first_x: int = first.x
	var first_y: int = first.y
	var second_x: int = second.x
	var second_y: int = second.y
	var first_intent: Dictionary = _intend(first, second, first_locked)
	var second_intent: Dictionary = _intend(second, first, second_locked)
	_cancel_same_target(first_intent, second_intent)
	_windup(first_intent)
	_windup(second_intent)
	_active(first_intent, second_x, second_y)
	_active(second_intent, first_x, first_y)
	_resolve_bites(first_intent, second_intent)
	_recover(first_intent)
	_recover(second_intent)
	_check_end()
	tick += 1
	if not finished and tick >= max_tick:
		_settle_timeout()


static func simulate_hold(config: Config, first_id: String, second_id: String) -> Dictionary:
	var bout: Match = Match.new(config, first_id, second_id)
	while bout.tick < bout.max_tick and not bout.finished:
		bout.step_forced("hold", "hold")
	var hold_before: int = bout.first.consec_hold
	var tick_before: int = bout.tick
	bout.step()
	return {
		"tick": tick_before,
		"tick_after_extra": bout.tick,
		"finished": bout.finished,
		"hold_before_extra": hold_before,
		"hold_after_extra": bout.first.consec_hold,
		"first_x": bout.first.x,
		"first_y": bout.first.y,
		"first_facing_x": bout.first.facing_x,
		"first_facing_y": bout.first.facing_y,
		"first_stamina": bout.first.stamina,
		"first_pressure": bout.first.pressure,
		"first_action": bout.first.last_action,
		"second_x": bout.second.x,
		"second_y": bout.second.y,
		"second_facing_x": bout.second.facing_x,
		"second_facing_y": bout.second.facing_y,
		"second_stamina": bout.second.stamina,
		"second_pressure": bout.second.pressure,
		"second_action": bout.second.last_action,
		"second_hold": bout.second.consec_hold,
	}


func _make(id: String, x: int, y: int, facing_x: int, facing_y: int) -> Cricket:
	var cricket: Cricket = CricketLib.new()
	cricket.id = id
	cricket.x = x
	cricket.y = y
	cricket.facing_x = facing_x
	cricket.facing_y = facing_y
	if roster.has(id):
		var row: Dictionary = roster[id]
		cricket.param_a = int(row["A"])
		cricket.param_r = int(row["R"])
		cricket.param_e = int(row["E"])
		cricket.param_s = int(row["S"])
		cricket.param_p = int(row["P"])
	return cricket


func _intend(actor: Cricket, opp: Cricket, locked: bool) -> Dictionary:
	var action_name: String = _choose_action(actor, opp, locked)
	var spec: Dictionary = actions[action_name]
	var delta: Array = RulesLib.delta_for_move(spec["move"], actor.x, actor.y, opp.x, opp.y, grid_w, grid_h)
	var dx: int = int(delta[0])
	var dy: int = int(delta[1])
	if action_name == "flank" and dx == 0 and dy == 0:
		action_name = "hold"
		spec = actions["hold"]
	var stamina_cost: int = int(spec["stamina"])
	if locked and stamina_cost > 0:
		stamina_cost = 0
	return {
		"actor": actor,
		"action": action_name,
		"dx": dx,
		"dy": dy,
		"from_x": actor.x,
		"from_y": actor.y,
		"stamina": stamina_cost,
		"pressure": int(spec["pressure"]),
		"windup": int(spec["windup"]),
		"active": int(spec["active"]),
		"recover": int(spec["recover"]),
		"moved": false,
		"skip_recover": false,
		"locked": locked,
	}


func _choose_action(actor: Cricket, opp: Cricket, locked: bool) -> String:
	if locked:
		return "hold"
	if scripted.size() == 2:
		return _action_for(actor)
	var choice: Dictionary = DecisionLib.evaluate(actor, opp, weights, low_stamina)
	actor.last_features = choice["features"]
	actor.last_scores = choice["scores"]
	return str(choice["action"])


func _action_for(actor: Cricket) -> String:
	if scripted.size() != 2:
		return FIXED_ACTION
	if actor == first:
		return str(scripted[0])
	return str(scripted[1])


func _cancel_same_target(lead: Dictionary, follow: Dictionary) -> void:
	var lead_moves: bool = int(lead["dx"]) != 0 or int(lead["dy"]) != 0
	var follow_moves: bool = int(follow["dx"]) != 0 or int(follow["dy"]) != 0
	if not lead_moves or not follow_moves:
		return
	var lead_actor: Cricket = lead["actor"]
	var follow_actor: Cricket = follow["actor"]
	var lead_x: int = lead_actor.x + int(lead["dx"])
	var lead_y: int = lead_actor.y + int(lead["dy"])
	var follow_x: int = follow_actor.x + int(follow["dx"])
	var follow_y: int = follow_actor.y + int(follow["dy"])
	if lead_x == follow_x and lead_y == follow_y:
		follow["dx"] = 0
		follow["dy"] = 0


func _windup(intent: Dictionary) -> void:
	var actor: Cricket = intent["actor"]
	phase_log.append({
		"phase": "windup",
		"id": actor.id,
		"action": str(intent["action"]),
		"x": actor.x,
		"y": actor.y,
		"stamina": actor.stamina,
		"ms": int(intent["windup"]),
	})


func _active(intent: Dictionary, opp_x: int, opp_y: int) -> void:
	var actor: Cricket = intent["actor"]
	var applied: Dictionary = RulesLib.apply_step(actor.x, actor.y, int(intent["dx"]), int(intent["dy"]), opp_x, opp_y, grid_w, grid_h)
	if bool(applied["moved"]):
		var next_x: int = int(applied["x"])
		var next_y: int = int(applied["y"])
		actor.facing_x = next_x - actor.x
		actor.facing_y = next_y - actor.y
		actor.x = next_x
		actor.y = next_y
		intent["moved"] = true
	phase_log.append({
		"phase": "active",
		"id": actor.id,
		"action": str(intent["action"]),
		"x": actor.x,
		"y": actor.y,
		"stamina": actor.stamina,
		"ms": int(intent["active"]),
	})
	move_log.append({
		"tick": tick,
		"id": actor.id,
		"action": str(intent["action"]),
		"from_x": int(intent["from_x"]),
		"from_y": int(intent["from_y"]),
		"to_x": actor.x,
		"to_y": actor.y,
	})


func _resolve_bites(first_intent: Dictionary, second_intent: Dictionary) -> void:
	var first_bite: bool = str(first_intent["action"]) == "bite"
	var second_bite: bool = str(second_intent["action"]) == "bite"
	var first_hit: Dictionary = {"hit": false, "reason": ""}
	var second_hit: Dictionary = {"hit": false, "reason": ""}
	if first_bite:
		first_hit = _bite_between(first, second, second_intent)
	if second_bite:
		second_hit = _bite_between(second, first, first_intent)
	if bool(first_hit["hit"]) and bool(second_hit["hit"]):
		_apply_clash()
		first_intent["skip_recover"] = true
		second_intent["skip_recover"] = true
		return
	if bool(first_hit["hit"]):
		first_intent["skip_recover"] = true
		_schedule_grapple(first, second)
	elif first_bite:
		_mark_whiff(first_intent, first, second, str(first_hit["reason"]))
	if bool(second_hit["hit"]):
		second_intent["skip_recover"] = true
		_schedule_grapple(second, first)
	elif second_bite:
		_mark_whiff(second_intent, second, first, str(second_hit["reason"]))


func _bite_between(att: Cricket, def: Cricket, def_intent: Dictionary) -> Dictionary:
	var retreated: bool = str(def_intent["action"]) == "retreat" and bool(def_intent["moved"])
	return RulesLib.bite_outcome(att.x, att.y, att.facing_x, att.facing_y, def.x, def.y, retreated)


func _mark_whiff(intent: Dictionary, att: Cricket, def: Cricket, reason: String) -> void:
	intent["pressure"] = int(intent["pressure"]) + WHIFF_PRESSURE
	events.append({
		"type": "whiff",
		"tick": tick,
		"actor": att.id,
		"target": def.id,
		"reason": reason,
	})


func _schedule_grapple(att: Cricket, def: Cricket) -> void:
	pending_grapple = true
	grapple_att = att
	grapple_def = def


func _apply_clash() -> void:
	var first_land: Dictionary = RulesLib.resolve("away", first.x, first.y, second.x, second.y, grid_w, grid_h)
	var second_land: Dictionary = RulesLib.resolve("away", second.x, second.y, first.x, first.y, grid_w, grid_h)
	var first_push: bool = _commit_land(first, first_land)
	var second_push: bool = _commit_land(second, second_land)
	first.apply_deltas(CLASH_STAMINA, CLASH_PRESSURE)
	second.apply_deltas(CLASH_STAMINA, CLASH_PRESSURE)
	events.append({
		"type": "clash",
		"tick": tick,
		"a": first.id,
		"b": second.id,
		"a_sta_after": first.stamina,
		"b_sta_after": second.stamina,
		"a_pressure_after": first.pressure,
		"b_pressure_after": second.pressure,
		"a_push": first_push,
		"b_push": second_push,
	})


func _recover(intent: Dictionary) -> void:
	var actor: Cricket = intent["actor"]
	if not bool(intent["skip_recover"]):
		actor.apply_deltas(int(intent["stamina"]), int(intent["pressure"]))
	actor.note_action(str(intent["action"]))
	if not bool(intent["locked"]):
		events.append({
			"type": "tick",
			"tick": tick,
			"actor": actor.id,
			"action": str(intent["action"]),
			"from_x": int(intent["from_x"]),
			"from_y": int(intent["from_y"]),
			"to_x": actor.x,
			"to_y": actor.y,
			"stamina": actor.stamina,
			"pressure": actor.pressure,
		})
	phase_log.append({
		"phase": "recover",
		"id": actor.id,
		"action": str(intent["action"]),
		"x": actor.x,
		"y": actor.y,
		"stamina": actor.stamina,
		"ms": int(intent["recover"]),
	})


func _run_grapple_tick() -> void:
	var att: Cricket = grapple_att
	var defn: Cricket = grapple_def
	var att_before: int = att.stamina
	var def_before: int = defn.stamina
	var att_power: int = RulesLib.attack_power(att.stamina, att.param_e, att.pressure)
	var def_power: int = RulesLib.defense_power(defn.stamina, defn.param_e, defn.pressure)
	var result: String = RulesLib.grapple_result(
		att_power,
		def_power,
		int(grapple_cfg["win_ratio_num"]),
		int(grapple_cfg["win_ratio_den"]),
		int(grapple_cfg["lose_ratio_num"]),
		int(grapple_cfg["lose_ratio_den"])
	)
	var att_sta: int = int(grapple_cfg["even_att"])
	var def_sta: int = int(grapple_cfg["even_def"])
	var att_pre: int = int(grapple_cfg["even_pressure"])
	var def_pre: int = int(grapple_cfg["even_pressure"])
	var att_push: bool = false
	var def_push: bool = false
	if result == "suppressed":
		att_sta = int(grapple_cfg["suppress_att"])
		def_sta = int(grapple_cfg["suppress_def"])
		att_pre = int(grapple_cfg["suppress_pressure_att"])
		def_pre = int(grapple_cfg["suppress_pressure_def"])
		def_push = _push_away(defn, att)
	elif result == "countered":
		att_sta = int(grapple_cfg["counter_att"])
		def_sta = int(grapple_cfg["counter_def"])
		att_pre = int(grapple_cfg["counter_pressure_att"])
		def_pre = int(grapple_cfg["counter_pressure_def"])
		att_push = _push_away(att, defn)
	att.apply_deltas(att_sta, att_pre)
	defn.apply_deltas(def_sta, def_pre)
	att.stun = true
	defn.stun = true
	pending_grapple = false
	events.append({
		"type": "grapple",
		"tick": tick,
		"att": att.id,
		"def": defn.id,
		"result": result,
		"att_sta_before": att_before,
		"def_sta_before": def_before,
		"att_sta_after": att.stamina,
		"def_sta_after": defn.stamina,
		"att_pressure_after": att.pressure,
		"def_pressure_after": defn.pressure,
		"att_push": att_push,
		"def_push": def_push,
	})
	tick += 1
	if tick >= max_tick:
		finished = true


func _check_end() -> void:
	if first.stamina <= 0:
		_finish(second, first, "stamina_zero")
		return
	if second.stamina <= 0:
		_finish(first, second, "stamina_zero")
		return
	if first.retreat_chain >= flee_consecutive and first.stamina < flee_stamina:
		_finish(second, first, "flee")
		return
	if second.retreat_chain >= flee_consecutive and second.stamina < flee_stamina:
		_finish(first, second, "flee")


func _settle_timeout() -> void:
	var first_score: int = _end_score(first)
	var second_score: int = _end_score(second)
	end_tick = tick
	finished = true
	if first_score > second_score:
		winner_id = first.id
		loser_id = second.id
		end_reason = "timeout"
		return
	if second_score > first_score:
		winner_id = second.id
		loser_id = first.id
		end_reason = "timeout"
		return
	winner_id = second.id
	loser_id = first.id
	end_reason = "draw_tiebreak"


func _end_score(cricket: Cricket) -> int:
	var score: int = cricket.stamina
	if cricket.x == center_x and cricket.y == center_y:
		score += center_bonus
	return score


func _finish(winner: Cricket, loser: Cricket, reason: String) -> void:
	winner_id = winner.id
	loser_id = loser.id
	end_reason = reason
	end_tick = tick
	finished = true


func _push_away(who: Cricket, source: Cricket) -> bool:
	var landed: Dictionary = RulesLib.resolve("away", who.x, who.y, source.x, source.y, grid_w, grid_h)
	return _commit_land(who, landed)


func _commit_land(who: Cricket, landed: Dictionary) -> bool:
	if not bool(landed["moved"]):
		return false
	var next_x: int = int(landed["x"])
	var next_y: int = int(landed["y"])
	who.facing_x = next_x - who.x
	who.facing_y = next_y - who.y
	who.x = next_x
	who.y = next_y
	return true
