extends RefCounted
class_name Decision

const RulesLib = preload("res://src/core/rules.gd")


static func pick_action(order: Array, scores: Dictionary) -> String:
	var best_name: String = ""
	var best_score: int = -1000001
	for item in order:
		var action_name: String = str(item)
		var score: int = int(scores[action_name])
		if score > best_score:
			best_score = score
			best_name = action_name
	return best_name


static func compute_features(actor: Cricket, opp: Cricket) -> Dictionary:
	var dist: int = RulesLib.manhattan(actor.x, actor.y, opp.x, opp.y)
	var near: int = 0
	var far: int = 0
	if dist <= 1:
		near = 100
	elif dist == 2:
		near = 50
		far = 50
	else:
		far = 100
	var dot: int = (opp.x - actor.x) * actor.facing_x + (opp.y - actor.y) * actor.facing_y
	var face: int = 100 if dot > 0 else 0
	var sup: int = 100 if actor.pressure > 60 and actor.param_s > 0 else 0
	var sdn: int = 100 if actor.pressure > 60 and actor.param_s < 0 else 0
	return {
		"near": near,
		"far": far,
		"face": face,
		"sta": actor.stamina,
		"pre": actor.pressure,
		"sup": sup,
		"sdn": sdn,
	}


static func score_action(action_name: String, features: Dictionary, actor: Cricket, weights: Dictionary, low_stamina_line: int) -> int:
	var base_row: Dictionary = weights["base"]
	var feature_row: Dictionary = weights["feature"][action_name]
	var personality_row: Dictionary = weights["personality"][action_name]
	var value: int = int(base_row[action_name])
	value += RulesLib.idiv(int(feature_row["near"]) * int(features["near"]) + int(feature_row["far"]) * int(features["far"]) + int(feature_row["face"]) * int(features["face"]), 100)
	value += RulesLib.idiv(int(feature_row["sta"]) * int(features["sta"]) + int(feature_row["pre"]) * int(features["pre"]), 100)
	value += RulesLib.idiv(int(feature_row["sup"]) * int(features["sup"]) + int(feature_row["sdn"]) * int(features["sdn"]), 100)
	value += int(personality_row["A"]) * actor.param_a + int(personality_row["R"]) * actor.param_r + int(personality_row["E"]) * actor.param_e
	if action_name == actor.last_action:
		var penalties: Dictionary = weights["repeat_penalty"]
		value -= RulesLib.idiv(int(penalties[action_name]) * actor.param_p, 100)
	var deadlock: Dictionary = weights["deadlock"]
	if action_name == "hold" and actor.consec_hold >= int(deadlock["hold_chain_start"]):
		value -= (actor.consec_hold - 2) * int(deadlock["hold_chain_penalty"])
	if actor.stamina < low_stamina_line:
		if action_name == "bite":
			value -= 300
		elif action_name == "retreat":
			value += 200
	if actor.chain_count >= int(deadlock["same_action_limit"]) and action_name == actor.chain_action:
		value = -999999
	return value


static func evaluate(actor: Cricket, opp: Cricket, weights: Dictionary, low_stamina_line: int) -> Dictionary:
	var features: Dictionary = compute_features(actor, opp)
	var order: Array = weights["action_order"]
	var scores: Dictionary = {}
	for item in order:
		var action_name: String = str(item)
		scores[action_name] = score_action(action_name, features, actor, weights, low_stamina_line)
	return {
		"action": pick_action(order, scores),
		"features": features,
		"scores": scores,
	}
