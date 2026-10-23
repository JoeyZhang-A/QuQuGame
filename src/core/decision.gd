extends RefCounted
class_name Decision

# 平局用严格大于。先写入的动作保留，所以顺序必须是 action_order。


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
