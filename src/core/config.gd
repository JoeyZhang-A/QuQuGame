extends RefCounted
class_name Config

## 加载 data 下三份 JSON 并校验。非法值返回错误，不钳制。
##
## 性格参数以百分之一整数保存：JSON 0.20 → 20，JSON -0.90 → -90。
## 这就是 02 所说的「乘 100 后转成整数分量」。
## 性格项整数式为 p_A * A + p_R * R + p_E * E（A/R/E 已是 ×100）。
## 等价于公式里的 (p_A * A原 + p_R * R原 + p_E * E原) * 100。
## 重复惩罚整数式为 repeat_penalty * P / 100，P 同样已是 ×100。
## 角力比值以百分数分子保存：JSON 1.15 → win_ratio_num 115，分母 100。
## 对应 01 的 att >= def * num / den。

const PERSONALITY_SCALE := 100
const RATIO_SCALE := 100

const ACTION_NAMES: PackedStringArray = ["hold", "retreat", "approach", "flank", "bite"]
const FEATURE_NAMES: PackedStringArray = ["near", "far", "face", "sta", "pre", "sup", "sdn"]
const PERSONALITY_KEYS: PackedStringArray = ["A", "R", "E"]

const CRICKETS_PATH := "res://data/crickets.json"
const ACTIONS_PATH := "res://data/actions.json"
const WEIGHTS_PATH := "res://data/weights.json"

var _tick_ms := 0
var _max_tick := 0
var _grid_w := 0
var _grid_h := 0
var _center_x := 0
var _center_y := 0
var _actions: Dictionary = {}
var _grapple: Dictionary = {}
var _thresholds: Dictionary = {}
var _scoring: Dictionary = {}
var _crickets: Array = []
var _weights: Dictionary = {}


static func load_project() -> Dictionary:
	return load_files(CRICKETS_PATH, ACTIONS_PATH, WEIGHTS_PATH)


static func load_files(crickets_path: String, actions_path: String, weights_path: String) -> Dictionary:
	var cfg := Config.new()
	var err := cfg._load_all(crickets_path, actions_path, weights_path)
	if err != "":
		return {"ok": false, "error": err, "config": null}
	return {"ok": true, "error": "", "config": cfg}


func snapshot() -> Dictionary:
	return {
		"personality_scale": PERSONALITY_SCALE,
		"tick_ms": _tick_ms,
		"max_tick": _max_tick,
		"grid": {"w": _grid_w, "h": _grid_h},
		"center": [_center_x, _center_y],
		"actions": _dup(_actions),
		"grapple": _dup(_grapple),
		"thresholds": _dup(_thresholds),
		"scoring": _dup(_scoring),
		"crickets": _dup(_crickets),
		"weights": _dup(_weights),
	}


func tick_ms() -> int:
	return _tick_ms


func max_tick() -> int:
	return _max_tick


func grid_w() -> int:
	return _grid_w


func grid_h() -> int:
	return _grid_h


func center() -> Array:
	return [_center_x, _center_y]


func actions() -> Dictionary:
	return _dup(_actions)


func action(action_name: String) -> Dictionary:
	if not _actions.has(action_name):
		return {}
	return _dup(_actions[action_name])


func grapple() -> Dictionary:
	return _dup(_grapple)


func thresholds() -> Dictionary:
	return _dup(_thresholds)


func scoring() -> Dictionary:
	return _dup(_scoring)


func crickets() -> Array:
	return _dup(_crickets)


func cricket_by_id(id: String) -> Dictionary:
	for item in _crickets:
		if item["id"] == id:
			return _dup(item)
	return {}


func weights() -> Dictionary:
	return _dup(_weights)


func _load_all(crickets_path: String, actions_path: String, weights_path: String) -> String:
	var err := _load_actions(actions_path)
	if err != "":
		return err
	err = _load_crickets(crickets_path)
	if err != "":
		return err
	return _load_weights(weights_path)


func _load_actions(path: String) -> String:
	var packed := _read_json(path)
	if packed["error"] != "":
		return packed["error"]
	var data: Dictionary = packed["data"]
	var err := _exact(data, PackedStringArray([
		"version", "tick_ms", "max_tick", "grid", "center",
		"actions", "grapple", "thresholds", "scoring",
	]), path)
	if err != "":
		return err
	err = _require_version(data, path)
	if err != "":
		return err

	var tick := _as_int(data["tick_ms"], "%s tick_ms" % path)
	if tick["error"] != "":
		return tick["error"]
	if int(tick["value"]) <= 0:
		return "%s tick_ms 必须为正，实际 %d" % [path, int(tick["value"])]
	_tick_ms = int(tick["value"])

	var max_tick := _as_int(data["max_tick"], "%s max_tick" % path)
	if max_tick["error"] != "":
		return max_tick["error"]
	if int(max_tick["value"]) <= 0:
		return "%s max_tick 必须为正，实际 %d" % [path, int(max_tick["value"])]
	_max_tick = int(max_tick["value"])

	if typeof(data["grid"]) != TYPE_DICTIONARY:
		return "%s grid 必须是对象" % path
	err = _exact(data["grid"], PackedStringArray(["w", "h"]), "%s grid" % path)
	if err != "":
		return err
	var grid_w := _as_int(data["grid"]["w"], "%s grid.w" % path)
	if grid_w["error"] != "":
		return grid_w["error"]
	var grid_h := _as_int(data["grid"]["h"], "%s grid.h" % path)
	if grid_h["error"] != "":
		return grid_h["error"]
	if int(grid_w["value"]) <= 0 or int(grid_h["value"]) <= 0:
		return "%s grid 宽高必须为正" % path
	_grid_w = int(grid_w["value"])
	_grid_h = int(grid_h["value"])

	if typeof(data["center"]) != TYPE_ARRAY or data["center"].size() != 2:
		return "%s center 必须是 [x, y]" % path
	var cx := _as_int(data["center"][0], "%s center[0]" % path)
	if cx["error"] != "":
		return cx["error"]
	var cy := _as_int(data["center"][1], "%s center[1]" % path)
	if cy["error"] != "":
		return cy["error"]
	_center_x = int(cx["value"])
	_center_y = int(cy["value"])
	if _center_x < 0 or _center_x >= _grid_w or _center_y < 0 or _center_y >= _grid_h:
		return "%s center [%d, %d] 不在场地内" % [path, _center_x, _center_y]

	if typeof(data["actions"]) != TYPE_DICTIONARY:
		return "%s actions 必须是对象" % path
	err = _exact(data["actions"], ACTION_NAMES, "%s actions" % path)
	if err != "":
		return err
	_actions = {}
	for action_name in ACTION_NAMES:
		var loaded = _load_one_action(path, action_name, data["actions"][action_name])
		if loaded["error"] != "":
			return loaded["error"]
		_actions[action_name] = loaded["value"]

	err = _load_grapple(path, data["grapple"])
	if err != "":
		return err
	err = _load_int_object(data["thresholds"], PackedStringArray([
		"low_stamina", "stress", "panic", "flee_stamina",
	]), "%s thresholds" % path)
	if err != "":
		return err
	_thresholds = _last_int_object
	err = _load_int_object(data["scoring"], PackedStringArray([
		"center_bonus", "flee_consecutive",
	]), "%s scoring" % path)
	if err != "":
		return err
	_scoring = _last_int_object
	return ""


var _last_int_object: Dictionary = {}


func _load_one_action(path: String, action_name: String, raw) -> Dictionary:
	var where := "%s actions.%s" % [path, action_name]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "%s 必须是对象" % where, "value": {}}
	var err := _exact(raw, PackedStringArray([
		"windup", "active", "recover", "move", "stamina", "pressure",
	]), where)
	if err != "":
		return {"error": err, "value": {}}
	var windup := _as_int(raw["windup"], "%s.windup" % where)
	if windup["error"] != "":
		return {"error": windup["error"], "value": {}}
	var active := _as_int(raw["active"], "%s.active" % where)
	if active["error"] != "":
		return {"error": active["error"], "value": {}}
	var recover := _as_int(raw["recover"], "%s.recover" % where)
	if recover["error"] != "":
		return {"error": recover["error"], "value": {}}
	if int(windup["value"]) < 0 or int(active["value"]) < 0 or int(recover["value"]) < 0:
		return {"error": "%s 阶段时长不能为负" % where, "value": {}}
	var phase_sum := int(windup["value"]) + int(active["value"]) + int(recover["value"])
	if phase_sum != _tick_ms:
		return {
			"error": "%s 三阶段之和为 %d，必须等于 tick_ms %d" % [where, phase_sum, _tick_ms],
			"value": {},
		}
	var move := _parse_move(raw["move"], "%s.move" % where)
	if move["error"] != "":
		return {"error": move["error"], "value": {}}
	var stamina := _as_int(raw["stamina"], "%s.stamina" % where)
	if stamina["error"] != "":
		return {"error": stamina["error"], "value": {}}
	var pressure := _as_int(raw["pressure"], "%s.pressure" % where)
	if pressure["error"] != "":
		return {"error": pressure["error"], "value": {}}
	return {
		"error": "",
		"value": {
			"windup": int(windup["value"]),
			"active": int(active["value"]),
			"recover": int(recover["value"]),
			"move": move["value"],
			"stamina": int(stamina["value"]),
			"pressure": int(pressure["value"]),
		},
	}


func _load_grapple(path: String, raw) -> String:
	var where := "%s grapple" % path
	if typeof(raw) != TYPE_DICTIONARY:
		return "%s 必须是对象" % where
	var err := _exact(raw, PackedStringArray([
		"suppress_att", "suppress_def",
		"counter_att", "counter_def",
		"even_att", "even_def",
		"suppress_pressure_att", "suppress_pressure_def",
		"counter_pressure_att", "counter_pressure_def",
		"even_pressure",
		"win_ratio", "lose_ratio",
	]), where)
	if err != "":
		return err
	var ints: Dictionary = {}
	for key in PackedStringArray([
		"suppress_att", "suppress_def",
		"counter_att", "counter_def",
		"even_att", "even_def",
		"suppress_pressure_att", "suppress_pressure_def",
		"counter_pressure_att", "counter_pressure_def",
		"even_pressure",
	]):
		var parsed := _as_int(raw[key], "%s.%s" % [where, key])
		if parsed["error"] != "":
			return parsed["error"]
		ints[key] = int(parsed["value"])
	var win := _as_scaled_int(raw["win_ratio"], "%s.win_ratio" % where, RATIO_SCALE, false, 0, 0)
	if win["error"] != "":
		return win["error"]
	var lose := _as_scaled_int(raw["lose_ratio"], "%s.lose_ratio" % where, RATIO_SCALE, false, 0, 0)
	if lose["error"] != "":
		return lose["error"]
	ints["win_ratio_num"] = int(win["value"])
	ints["win_ratio_den"] = RATIO_SCALE
	ints["lose_ratio_num"] = int(lose["value"])
	ints["lose_ratio_den"] = RATIO_SCALE
	_grapple = ints
	return ""


func _load_int_object(raw, keys: PackedStringArray, where: String) -> String:
	if typeof(raw) != TYPE_DICTIONARY:
		return "%s 必须是对象" % where
	var err := _exact(raw, keys, where)
	if err != "":
		return err
	var out: Dictionary = {}
	for key in keys:
		var parsed := _as_int(raw[key], "%s.%s" % [where, key])
		if parsed["error"] != "":
			return parsed["error"]
		out[key] = int(parsed["value"])
	_last_int_object = out
	return ""


func _load_crickets(path: String) -> String:
	var packed := _read_json(path)
	if packed["error"] != "":
		return packed["error"]
	var data: Dictionary = packed["data"]
	var err := _exact(data, PackedStringArray(["version", "crickets"]), path)
	if err != "":
		return err
	err = _require_version(data, path)
	if err != "":
		return err
	if typeof(data["crickets"]) != TYPE_ARRAY:
		return "%s crickets 必须是数组" % path
	if data["crickets"].is_empty():
		return "%s crickets 不能为空" % path
	var seen := {}
	var loaded: Array = []
	for index in data["crickets"].size():
		var item = data["crickets"][index]
		var one = _load_one_cricket(path, index, item, seen)
		if one["error"] != "":
			return one["error"]
		seen[one["value"]["id"]] = true
		loaded.append(one["value"])
	_crickets = loaded
	return ""


func _load_one_cricket(path: String, index: int, raw, seen: Dictionary) -> Dictionary:
	var where := "%s crickets[%d]" % [path, index]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "%s 必须是对象" % where, "value": {}}
	var err := _exact(raw, PackedStringArray(["id", "name", "A", "R", "E", "S", "P"]), where)
	if err != "":
		return {"error": err, "value": {}}
	if typeof(raw["id"]) != TYPE_STRING or str(raw["id"]) == "":
		return {"error": "%s.id 必须是非空字符串" % where, "value": {}}
	var id := str(raw["id"])
	if seen.has(id):
		return {"error": "%s id 重复: %s" % [path, id], "value": {}}
	if typeof(raw["name"]) != TYPE_STRING or str(raw["name"]) == "":
		return {"error": "%s.name 必须是非空字符串" % where, "value": {}}
	var params := {"A": [0, PERSONALITY_SCALE], "R": [0, PERSONALITY_SCALE], "E": [0, PERSONALITY_SCALE], "P": [0, PERSONALITY_SCALE], "S": [-PERSONALITY_SCALE, PERSONALITY_SCALE]}
	var out := {
		"id": id,
		"name": str(raw["name"]),
	}
	for key in ["A", "R", "E", "S", "P"]:
		var bounds: Array = params[key]
		var parsed := _as_scaled_int(
			raw[key],
			"%s[%s].%s" % [path, id, key],
			PERSONALITY_SCALE,
			true,
			int(bounds[0]),
			int(bounds[1])
		)
		if parsed["error"] != "":
			return {"error": parsed["error"], "value": {}}
		out[key] = int(parsed["value"])
	return {"error": "", "value": out}


func _load_weights(path: String) -> String:
	var packed := _read_json(path)
	if packed["error"] != "":
		return packed["error"]
	var data: Dictionary = packed["data"]
	var err := _exact(data, PackedStringArray([
		"version", "base", "feature", "personality", "repeat_penalty", "action_order", "deadlock",
	]), path)
	if err != "":
		return err
	err = _require_version(data, path)
	if err != "":
		return err

	var base := _load_action_int_map(data["base"], "%s base" % path)
	if base["error"] != "":
		return base["error"]
	var feature := _load_feature_map(data["feature"], "%s feature" % path)
	if feature["error"] != "":
		return feature["error"]
	var personality := _load_personality_map(data["personality"], "%s personality" % path)
	if personality["error"] != "":
		return personality["error"]
	var repeat_penalty := _load_action_int_map(data["repeat_penalty"], "%s repeat_penalty" % path)
	if repeat_penalty["error"] != "":
		return repeat_penalty["error"]
	var order := _load_action_order(data["action_order"], "%s action_order" % path)
	if order["error"] != "":
		return order["error"]
	err = _load_int_object(data["deadlock"], PackedStringArray([
		"hold_chain_start", "hold_chain_penalty", "same_action_limit",
	]), "%s deadlock" % path)
	if err != "":
		return err
	_weights = {
		"base": base["value"],
		"feature": feature["value"],
		"personality": personality["value"],
		"repeat_penalty": repeat_penalty["value"],
		"action_order": order["value"],
		"deadlock": _last_int_object.duplicate(true),
	}
	return ""


func _load_action_int_map(raw, where: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "%s 必须是对象" % where, "value": {}}
	var err := _exact(raw, ACTION_NAMES, where)
	if err != "":
		return {"error": err, "value": {}}
	var out: Dictionary = {}
	for action_name in ACTION_NAMES:
		var parsed := _as_int(raw[action_name], "%s.%s" % [where, action_name])
		if parsed["error"] != "":
			return {"error": parsed["error"], "value": {}}
		out[action_name] = int(parsed["value"])
	return {"error": "", "value": out}


func _load_feature_map(raw, where: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "%s 必须是对象" % where, "value": {}}
	var err := _exact(raw, ACTION_NAMES, where)
	if err != "":
		return {"error": err, "value": {}}
	var out: Dictionary = {}
	for action_name in ACTION_NAMES:
		var row = raw[action_name]
		var row_where := "%s.%s" % [where, action_name]
		if typeof(row) != TYPE_DICTIONARY:
			return {"error": "%s 必须是对象" % row_where, "value": {}}
		err = _exact(row, FEATURE_NAMES, row_where)
		if err != "":
			return {"error": err, "value": {}}
		var parsed_row: Dictionary = {}
		for feature_name in FEATURE_NAMES:
			var parsed := _as_int(row[feature_name], "%s.%s" % [row_where, feature_name])
			if parsed["error"] != "":
				return {"error": parsed["error"], "value": {}}
			parsed_row[feature_name] = int(parsed["value"])
		out[action_name] = parsed_row
	return {"error": "", "value": out}


func _load_personality_map(raw, where: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"error": "%s 必须是对象" % where, "value": {}}
	var err := _exact(raw, ACTION_NAMES, where)
	if err != "":
		return {"error": err, "value": {}}
	var out: Dictionary = {}
	for action_name in ACTION_NAMES:
		var row = raw[action_name]
		var row_where := "%s.%s" % [where, action_name]
		if typeof(row) != TYPE_DICTIONARY:
			return {"error": "%s 必须是对象" % row_where, "value": {}}
		err = _exact(row, PERSONALITY_KEYS, row_where)
		if err != "":
			return {"error": err, "value": {}}
		var parsed_row: Dictionary = {}
		for key in PERSONALITY_KEYS:
			var parsed := _as_int(row[key], "%s.%s" % [row_where, key])
			if parsed["error"] != "":
				return {"error": parsed["error"], "value": {}}
			parsed_row[key] = int(parsed["value"])
		out[action_name] = parsed_row
	return {"error": "", "value": out}


func _load_action_order(raw, where: String) -> Dictionary:
	if typeof(raw) != TYPE_ARRAY:
		return {"error": "%s 必须是数组" % where, "value": []}
	if raw.size() != ACTION_NAMES.size():
		return {"error": "%s 长度必须为 %d" % [where, ACTION_NAMES.size()], "value": []}
	var seen := {}
	var order: Array = []
	for item in raw:
		if typeof(item) != TYPE_STRING:
			return {"error": "%s 的元素必须是字符串" % where, "value": []}
		var action_name := str(item)
		if not ACTION_NAMES.has(action_name):
			return {"error": "%s 含未知动作 %s" % [where, action_name], "value": []}
		if seen.has(action_name):
			return {"error": "%s 重复动作 %s" % [where, action_name], "value": []}
		seen[action_name] = true
		order.append(action_name)
	return {"error": "", "value": order}


func _parse_move(raw, field: String) -> Dictionary:
	if typeof(raw) == TYPE_STRING:
		var semantic := str(raw)
		if semantic != "near" and semantic != "away" and semantic != "side":
			return {"error": "%s=%s 不是 near/away/side" % [field, semantic], "value": ""}
		return {"error": "", "value": semantic}
	if typeof(raw) == TYPE_ARRAY:
		if raw.size() != 2:
			return {"error": "%s 必须是长度为 2 的偏移" % field, "value": []}
		var x := _as_int(raw[0], "%s[0]" % field)
		if x["error"] != "":
			return {"error": x["error"], "value": []}
		var y := _as_int(raw[1], "%s[1]" % field)
		if y["error"] != "":
			return {"error": y["error"], "value": []}
		return {"error": "", "value": [int(x["value"]), int(y["value"])]}
	return {"error": "%s 必须是字符串或 [x, y]" % field, "value": []}


static func _require_version(data: Dictionary, path: String) -> String:
	var parsed := _as_int(data["version"], "%s version" % path)
	if parsed["error"] != "":
		return parsed["error"]
	if int(parsed["value"]) != 1:
		return "%s version=%d，只接受 1" % [path, int(parsed["value"])]
	return ""


static func _exact(data: Dictionary, keys: PackedStringArray, where: String) -> String:
	var allowed := {}
	for key in keys:
		allowed[String(key)] = true
		if not data.has(key):
			return "%s 缺少字段 %s" % [where, key]
	for key in data.keys():
		if not allowed.has(String(key)):
			return "%s 含有未定义字段 %s" % [where, str(key)]
	return ""


static func _as_int(raw, field: String) -> Dictionary:
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return {"error": "%s 必须是整数" % field, "value": 0}
	var number := float(raw)
	if not is_finite(number):
		return {"error": "%s 不是有限数字" % field, "value": 0}
	var nearest: float = round(number)
	if absf(number - nearest) > 0.000001:
		return {"error": "%s=%s 不是整数，拒绝取整" % [field, str(raw)], "value": 0}
	return {"error": "", "value": int(nearest)}


static func _as_scaled_int(raw, field: String, scale: int, check_range: bool, lo: int, hi: int) -> Dictionary:
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return {"error": "%s 必须是数字" % field, "value": 0}
	var number := float(raw)
	if not is_finite(number):
		return {"error": "%s 不是有限数字" % field, "value": 0}
	if check_range:
		var lo_f := float(lo) / float(scale)
		var hi_f := float(hi) / float(scale)
		if number < lo_f - 0.0000001 or number > hi_f + 0.0000001:
			return {
				"error": "%s=%s 超出 %s..%s，拒绝钳制" % [field, str(raw), _format_bound(lo_f), _format_bound(hi_f)],
				"value": 0,
			}
	var scaled := number * float(scale)
	var nearest: float = round(scaled)
	if absf(scaled - nearest) > 0.000001:
		return {"error": "%s=%s 不能精确换算成 1/%d 整数，拒绝取整" % [field, str(raw), scale], "value": 0}
	var value := int(nearest)
	if check_range and (value < lo or value > hi):
		return {"error": "%s=%s 超出范围，拒绝钳制" % [field, str(raw)], "value": 0}
	return {"error": "", "value": value}


static func _format_bound(bound: float) -> String:
	if is_equal_approx(bound, round(bound)):
		return str(int(round(bound)))
	return str(bound)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "找不到配置文件 %s" % path, "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "无法打开 %s（%s）" % [path, error_string(FileAccess.get_open_error())], "data": {}}
	var text := file.get_as_text()
	file.close()
	if text.begins_with("\uFEFF"):
		text = text.substr(1)
	var parser := JSON.new()
	var code := parser.parse(text)
	if code != OK:
		return {
			"error": "%s JSON 解析失败，第 %d 行：%s" % [path, parser.get_error_line(), parser.get_error_message()],
			"data": {},
		}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"error": "%s 的根必须是 JSON 对象" % path, "data": {}}
	return {"error": "", "data": parser.data}


static func _dup(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
