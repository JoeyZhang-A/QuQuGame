extends RefCounted
class_name Match

const CricketLib = preload("res://src/core/cricket.gd")
const RulesLib = preload("res://src/core/rules.gd")

# 决策在 T6 接入。在此之前，未指定动作的拍固定为 hold。
const FIXED_ACTION: String = "hold"

var tick: int = 0
var max_tick: int = 0
var grid_w: int = 0
var grid_h: int = 0
var finished: bool = false
var actions: Dictionary = {}
var first: Cricket
var second: Cricket
var scripted: Array = []
var phase_log: Array = []
var move_log: Array = []


func _init(config: Config, first_id: String, second_id: String) -> void:
	max_tick = config.max_tick()
	grid_w = config.grid_w()
	grid_h = config.grid_h()
	actions = config.actions()
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
		finished = true
		return
	phase_log = []
	var first_x: int = first.x
	var first_y: int = first.y
	var second_x: int = second.x
	var second_y: int = second.y
	var first_intent: Dictionary = _intend(first, second)
	var second_intent: Dictionary = _intend(second, first)
	_cancel_same_target(first_intent, second_intent)
	_windup(first_intent)
	_windup(second_intent)
	_active(first_intent, second_x, second_y)
	_active(second_intent, first_x, first_y)
	_recover(first_intent)
	_recover(second_intent)
	tick += 1
	if tick >= max_tick:
		finished = true


static func simulate_hold(config: Config, first_id: String, second_id: String) -> Dictionary:
	var bout: Match = Match.new(config, first_id, second_id)
	bout.run()
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
	return cricket


func _intend(actor: Cricket, opp: Cricket) -> Dictionary:
	var action_name: String = _action_for(actor)
	var spec: Dictionary = actions[action_name]
	var delta: Array = RulesLib.delta_for_move(spec["move"], actor.x, actor.y, opp.x, opp.y, grid_w, grid_h)
	var dx: int = int(delta[0])
	var dy: int = int(delta[1])
	if action_name == "flank" and dx == 0 and dy == 0:
		action_name = "hold"
		spec = actions["hold"]
	return {
		"actor": actor,
		"action": action_name,
		"dx": dx,
		"dy": dy,
		"from_x": actor.x,
		"from_y": actor.y,
		"stamina": int(spec["stamina"]),
		"pressure": int(spec["pressure"]),
		"windup": int(spec["windup"]),
		"active": int(spec["active"]),
		"recover": int(spec["recover"]),
	}


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
	intent["moved"] = bool(applied["moved"])
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


func _recover(intent: Dictionary) -> void:
	var actor: Cricket = intent["actor"]
	actor.apply_deltas(int(intent["stamina"]), int(intent["pressure"]))
	actor.note_action(str(intent["action"]))
	phase_log.append({
		"phase": "recover",
		"id": actor.id,
		"action": str(intent["action"]),
		"x": actor.x,
		"y": actor.y,
		"stamina": actor.stamina,
		"ms": int(intent["recover"]),
	})
