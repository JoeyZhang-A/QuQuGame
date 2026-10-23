extends RefCounted
class_name Rules

# 文档列出的四个正交方向，平局时先出现者优先。
# approach / retreat 先比曼哈顿距离，距离相同再比与「靠近 / 远离」的对齐程度。
# flank 按 01：先 (0,+1) 再 (0,-1)。5×3 场上两者都合法时距中心一样远。

const DIR_X: PackedInt32Array = [1, -1, 0, 0]
const DIR_Y: PackedInt32Array = [0, 0, 1, -1]


static func manhattan(ax: int, ay: int, bx: int, by: int) -> int:
	return absi(ax - bx) + absi(ay - by)


static func in_bounds(x: int, y: int, grid_w: int, grid_h: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_w and y < grid_h


static func delta_for_move(move, x: int, y: int, opp_x: int, opp_y: int, grid_w: int, grid_h: int) -> Array:
	if move is String:
		var semantic: String = move
		if semantic == "near":
			return _best_delta(x, y, opp_x, opp_y, true)
		if semantic == "away":
			return _best_delta(x, y, opp_x, opp_y, false)
		if semantic == "side":
			return _flank_delta(x, y, opp_x, opp_y, grid_w, grid_h)
		return [0, 0]
	if move is Array and move.size() == 2:
		return [int(move[0]), int(move[1])]
	return [0, 0]


static func resolve(move, x: int, y: int, opp_x: int, opp_y: int, grid_w: int, grid_h: int) -> Dictionary:
	var delta: Array = delta_for_move(move, x, y, opp_x, opp_y, grid_w, grid_h)
	return apply_step(x, y, int(delta[0]), int(delta[1]), opp_x, opp_y, grid_w, grid_h)


static func apply_step(x: int, y: int, dx: int, dy: int, opp_x: int, opp_y: int, grid_w: int, grid_h: int) -> Dictionary:
	if dx == 0 and dy == 0:
		return _stay(x, y)
	if absi(dx) + absi(dy) != 1:
		return _stay(x, y)
	var next_x: int = x + dx
	var next_y: int = y + dy
	if not in_bounds(next_x, next_y, grid_w, grid_h):
		return _stay(x, y)
	if next_x == opp_x and next_y == opp_y:
		return _stay(x, y)
	return {"x": next_x, "y": next_y, "moved": true}


static func _stay(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y, "moved": false}


static func _best_delta(x: int, y: int, opp_x: int, opp_y: int, toward: bool) -> Array:
	var best_dx: int = 0
	var best_dy: int = 0
	var best_dist: int = 0
	var best_align: int = 0
	var have: bool = false
	for index in DIR_X.size():
		var dx: int = DIR_X[index]
		var dy: int = DIR_Y[index]
		var dist: int = manhattan(x + dx, y + dy, opp_x, opp_y)
		var align: int = _alignment(dx, dy, x, y, opp_x, opp_y, toward)
		if not have or _better(dist, align, best_dist, best_align, toward):
			have = true
			best_dx = dx
			best_dy = dy
			best_dist = dist
			best_align = align
	return [best_dx, best_dy]


static func _alignment(dx: int, dy: int, x: int, y: int, opp_x: int, opp_y: int, toward: bool) -> int:
	var score: int = dx * signi(opp_x - x) + dy * signi(opp_y - y)
	if toward:
		return score
	return -score


static func _better(dist: int, align: int, best_dist: int, best_align: int, toward: bool) -> bool:
	if toward:
		if dist != best_dist:
			return dist < best_dist
	elif dist != best_dist:
		return dist > best_dist
	return align > best_align


static func idiv(numerator: int, denominator: int) -> int:
	return int(float(numerator) / float(denominator))


static func attack_power(stamina: int, endurance_centi: int, pressure: int) -> int:
	var effect: int = 600 + idiv(400 * endurance_centi, 100)
	var power: int = idiv(stamina * effect, 1000)
	if pressure > 85:
		power = idiv(power * 850, 1000)
	return power


static func defense_power(stamina: int, endurance_centi: int, pressure: int) -> int:
	var effect: int = 600 + idiv(400 * endurance_centi, 100)
	var power: int = idiv(idiv(stamina * effect * 900, 1000), 1000)
	if pressure > 85:
		power = idiv(power * 850, 1000)
	return power


static func grapple_result(att_power: int, def_power: int, win_num: int, win_den: int, lose_num: int, lose_den: int) -> String:
	if att_power >= idiv(def_power * win_num, win_den):
		return "suppressed"
	if att_power <= idiv(def_power * lose_num, lose_den):
		return "countered"
	return "even"


static func bite_outcome(att_x: int, att_y: int, facing_x: int, facing_y: int, def_x: int, def_y: int, defender_retreated: bool) -> Dictionary:
	if defender_retreated:
		return {"hit": false, "reason": "retreated"}
	if manhattan(att_x, att_y, def_x, def_y) > 1:
		return {"hit": false, "reason": "out_of_range"}
	var dot: int = (def_x - att_x) * facing_x + (def_y - att_y) * facing_y
	if dot <= 0:
		return {"hit": false, "reason": "facing"}
	return {"hit": true, "reason": ""}


static func _flank_delta(x: int, y: int, opp_x: int, opp_y: int, grid_w: int, grid_h: int) -> Array:
	var up_y: int = y + 1
	if in_bounds(x, up_y, grid_w, grid_h) and not (x == opp_x and up_y == opp_y):
		return [0, 1]
	var down_y: int = y - 1
	if in_bounds(x, down_y, grid_w, grid_h) and not (x == opp_x and down_y == opp_y):
		return [0, -1]
	return [0, 0]
