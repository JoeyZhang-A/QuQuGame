extends RefCounted
class_name Match

const CricketLib = preload("res://src/core/cricket.gd")
const RulesLib = preload("res://src/core/rules.gd")

# T2：决策尚未接入，每拍动作固定为 hold。
const FIXED_ACTION: String = "hold"

var tick: int = 0
var max_tick: int = 0
var grid_w: int = 0
var grid_h: int = 0
var finished: bool = false
var actions: Dictionary = {}
var first: Cricket
var second: Cricket


func _init(config: Config, first_id: String, second_id: String) -> void:
	max_tick = config.max_tick()
	grid_w = config.grid_w()
	grid_h = config.grid_h()
	actions = config.actions()
	first = _make(first_id, 1, 1, 1, 0)
	second = _make(second_id, 3, 1, -1, 0)


func run() -> void:
	while tick < max_tick:
		step()


func step() -> void:
	if tick >= max_tick:
		finished = true
		return
	var first_x: int = first.x
	var first_y: int = first.y
	var second_x: int = second.x
	var second_y: int = second.y
	var first_intent: Dictionary = _intend(first, second)
	var second_intent: Dictionary = _intend(second, first)
	_cancel_same_target(first_intent, second_intent)
	_apply(first_intent, second_x, second_y)
	_apply(second_intent, first_x, first_y)
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
	var action_name: String = FIXED_ACTION
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
		"stamina": int(spec["stamina"]),
		"pressure": int(spec["pressure"]),
	}


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


func _apply(intent: Dictionary, opp_x: int, opp_y: int) -> void:
	var actor: Cricket = intent["actor"]
	var applied: Dictionary = RulesLib.apply_step(actor.x, actor.y, int(intent["dx"]), int(intent["dy"]), opp_x, opp_y, grid_w, grid_h)
	if bool(applied["moved"]):
		var next_x: int = int(applied["x"])
		var next_y: int = int(applied["y"])
		actor.facing_x = next_x - actor.x
		actor.facing_y = next_y - actor.y
		actor.x = next_x
		actor.y = next_y
	actor.apply_deltas(int(intent["stamina"]), int(intent["pressure"]))
	actor.note_action(str(intent["action"]))
