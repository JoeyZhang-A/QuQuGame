extends RefCounted

var _file: FileAccess
var match_id: int = 0


func open(path: String) -> void:
	_file = FileAccess.open(path, FileAccess.WRITE)


func close() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func write_start(bout: Match, id_num: int, tick_ms: int, max_tick: int) -> void:
	match_id = id_num
	var crickets: String = "[%s,%s]" % [_cricket_params(bout.first), _cricket_params(bout.second)]
	var line: String = _obj([
		["type", _str("match_start")],
		["match_id", _int(id_num)],
		["tick_ms", _int(tick_ms)],
		["max_tick", _int(max_tick)],
		["seed", _int(0)],
		["crickets", crickets],
		["start_pos", "[[1,1],[3,1]]"],
		["start_facing", "[[1,0],[-1,0]]"],
		["hud", _str("off")],
		["version", _str("demo1")],
	])
	_store(line)


func write_event(event: Dictionary) -> void:
	var kind: String = str(event["type"])
	if kind == "tick":
		_store(_tick_line(event))
	elif kind == "grapple":
		_store(_grapple_line(event))
	elif kind == "whiff":
		_store(_whiff_line(event))
	elif kind == "clash":
		_store(_clash_line(event))
	elif kind == "stress_trigger":
		_store(_stress_line(event))
	elif kind == "threshold":
		_store(_threshold_line(event))


func write_end(bout: Match) -> void:
	var final_rows: String = "[%s,%s]" % [
		_obj([["id", _str(bout.winner_id)], ["stamina", _int(_stamina_of(bout, bout.winner_id))]]),
		_obj([["id", _str(bout.loser_id)], ["stamina", _int(_stamina_of(bout, bout.loser_id))]]),
	]
	_store(_obj([
		["type", _str("match_end")],
		["match_id", _int(match_id)],
		["tick", _int(bout.end_tick)],
		["winner", _str(bout.winner_id)],
		["loser", _str(bout.loser_id)],
		["reason", _str(bout.end_reason)],
		["final", final_rows],
	]))


func _tick_line(event: Dictionary) -> String:
	var feat: Dictionary = event["feat"] if event.has("feat") else {}
	var scores: Dictionary = event["scores"] if event.has("scores") else {}
	return _obj([
		["type", _str("tick")],
		["match_id", _int(match_id)],
		["tick", _int(event["tick"])],
		["actor", _str(str(event["actor"]))],
		["action", _str(str(event["action"]))],
		["from", "[%d,%d]" % [int(event["from_x"]), int(event["from_y"])]],
		["to", "[%d,%d]" % [int(event["to_x"]), int(event["to_y"])]],
		["facing", "[%d,%d]" % [int(event["facing_x"]), int(event["facing_y"])]],
		["stamina", _int(event["stamina"])],
		["pressure", _int(event["pressure"])],
		["feat", _feat(feat)],
		["scores", _scores(scores)],
		["event", "null"],
	])


func _grapple_line(event: Dictionary) -> String:
	return _obj([
		["type", _str("grapple")],
		["match_id", _int(match_id)],
		["tick", _int(event["tick"])],
		["att", _str(str(event["att"]))],
		["def", _str(str(event["def"]))],
		["result", _str(str(event["result"]))],
		["att_sta_before", _int(event["att_sta_before"])],
		["def_sta_before", _int(event["def_sta_before"])],
		["att_sta_after", _int(event["att_sta_after"])],
		["def_sta_after", _int(event["def_sta_after"])],
		["att_pressure_after", _int(event["att_pressure_after"])],
		["def_pressure_after", _int(event["def_pressure_after"])],
		["att_push", _bool(event["att_push"])],
		["def_push", _bool(event["def_push"])],
	])


func _whiff_line(event: Dictionary) -> String:
	return _obj([
		["type", _str("whiff")],
		["match_id", _int(match_id)],
		["tick", _int(event["tick"])],
		["actor", _str(str(event["actor"]))],
		["target", _str(str(event["target"]))],
		["reason", _str(str(event["reason"]))],
	])


func _clash_line(event: Dictionary) -> String:
	return _obj([
		["type", _str("clash")],
		["match_id", _int(match_id)],
		["tick", _int(event["tick"])],
		["a", _str(str(event["a"]))],
		["b", _str(str(event["b"]))],
		["a_sta_after", _int(event["a_sta_after"])],
		["b_sta_after", _int(event["b_sta_after"])],
		["a_pressure_after", _int(event["a_pressure_after"])],
		["b_pressure_after", _int(event["b_pressure_after"])],
		["a_push", _bool(event["a_push"])],
		["b_push", _bool(event["b_push"])],
	])


func _stress_line(event: Dictionary) -> String:
	return _obj([
		["type", _str("stress_trigger")],
		["match_id", _int(match_id)],
		["tick", _int(event["tick"])],
		["actor", _str(str(event["actor"]))],
		["pressure", _int(event["pressure"])],
		["S", centi_text(int(event["s_centi"]))],
		["mode", _str(str(event["mode"]))],
	])


func _threshold_line(event: Dictionary) -> String:
	return _obj([
		["type", _str("threshold")],
		["match_id", _int(match_id)],
		["tick", _int(event["tick"])],
		["actor", _str(str(event["actor"]))],
		["which", _str(str(event["which"]))],
		["value", _int(event["value"])],
	])


func _feat(feat: Dictionary) -> String:
	return _obj([
		["near", _int(_pick(feat, "near"))],
		["far", _int(_pick(feat, "far"))],
		["face", _int(_pick(feat, "face"))],
		["sta", _int(_pick(feat, "sta"))],
		["pre", _int(_pick(feat, "pre"))],
		["sup", _int(_pick(feat, "sup"))],
		["sdn", _int(_pick(feat, "sdn"))],
	])


func _scores(scores: Dictionary) -> String:
	return _obj([
		["bite", _int(_pick(scores, "bite"))],
		["approach", _int(_pick(scores, "approach"))],
		["flank", _int(_pick(scores, "flank"))],
		["hold", _int(_pick(scores, "hold"))],
		["retreat", _int(_pick(scores, "retreat"))],
	])


func _cricket_params(cricket: Cricket) -> String:
	return _obj([
		["id", _str(cricket.id)],
		["A", centi_text(cricket.param_a)],
		["R", centi_text(cricket.param_r)],
		["E", centi_text(cricket.param_e)],
		["S", centi_text(cricket.param_s)],
		["P", centi_text(cricket.param_p)],
	])


static func centi_text(centi: int) -> String:
	var negative: bool = centi < 0
	var value: int = absi(centi)
	var whole: int = int(float(value) / 100.0)
	var frac: int = value - whole * 100
	var body: String = "%d.%02d" % [whole, frac]
	if negative:
		return "-" + body
	return body


func _stamina_of(bout: Match, id: String) -> int:
	if bout.first.id == id:
		return bout.first.stamina
	return bout.second.stamina


func _pick(row: Dictionary, key: String) -> int:
	if not row.has(key):
		return 0
	return int(row[key])


func _store(line: String) -> void:
	if _file == null:
		return
	_file.store_line(line)
	_file.flush()


static func _obj(pairs: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row in pairs:
		var pair: Array = row
		parts.append("\"%s\":%s" % [str(pair[0]), str(pair[1])])
	return "{" + ",".join(parts) + "}"


static func _str(value: String) -> String:
	return "\"%s\"" % value.replace("\\", "\\\\").replace("\"", "\\\"")


static func _int(value) -> String:
	return str(int(value))


static func _bool(value) -> String:
	if bool(value):
		return "true"
	return "false"
