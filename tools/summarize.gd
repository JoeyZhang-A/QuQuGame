extends SceneTree

const ACTIONS: PackedStringArray = ["hold", "retreat", "approach", "flank", "bite"]


func _initialize() -> void:
	var in_dir: String = "res://out"
	for arg in OS.get_cmdline_user_args():
		var text: String = str(arg)
		if text.begins_with("--in="):
			in_dir = text.substr(5)
	var folder: String = in_dir
	if folder.begins_with("res://"):
		folder = ProjectSettings.globalize_path(folder)
	var files: Array = _match_files(folder)
	var rows: Array = []
	for path in files:
		rows.append(_read_match(str(path)))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["match_id"]) < int(b["match_id"]))
	_write_summary(folder, rows)
	_write_dist(folder, rows)
	print("SUMMARIZED %d" % rows.size())
	quit(0)


func _match_files(folder: String) -> Array:
	var found: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		printerr("打不开 %s" % folder)
		quit(1)
		return found
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if _is_match_log(name):
			found.append(folder + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	return found


func _is_match_log(name: String) -> bool:
	if not name.begins_with("match_") or not name.ends_with(".jsonl"):
		return false
	var middle: String = name.trim_prefix("match_").trim_suffix(".jsonl")
	if middle == "":
		return false
	for index in middle.length():
		var code: int = middle.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


func _read_match(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = text.split("\n", false)
	var start: Dictionary = {}
	var ending: Dictionary = {}
	var ticks: Array = []
	var whiff: Dictionary = {}
	var stress: Dictionary = {}
	var pressure_sum: Dictionary = {}
	var pressure_max: Dictionary = {}
	var pressure_count: Dictionary = {}
	var action_count: Dictionary = {}
	var grapple_win: int = 0
	var grapple_lose: int = 0
	for line in lines:
		var parsed = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = parsed
		var kind: String = str(row["type"])
		if kind == "match_start":
			start = row
		elif kind == "match_end":
			ending = row
		elif kind == "tick":
			ticks.append(row)
			var actor: String = str(row["actor"])
			var action_name: String = str(row["action"])
			if not action_count.has(actor):
				action_count[actor] = {}
			action_count[actor][action_name] = int(action_count[actor].get(action_name, 0)) + 1
			var pressure: int = int(row["pressure"])
			pressure_sum[actor] = int(pressure_sum.get(actor, 0)) + pressure
			pressure_count[actor] = int(pressure_count.get(actor, 0)) + 1
			if not pressure_max.has(actor) or pressure > int(pressure_max[actor]):
				pressure_max[actor] = pressure
		elif kind == "whiff":
			var who: String = str(row["actor"])
			whiff[who] = int(whiff.get(who, 0)) + 1
		elif kind == "stress_trigger":
			var who_s: String = str(row["actor"])
			stress[who_s] = int(stress.get(who_s, 0)) + 1
		elif kind == "grapple":
			var att: String = str(row["att"])
			var defn: String = str(row["def"])
			var result: String = str(row["result"])
			var cricket_a: String = str(start["crickets"][0]["id"]) if start.has("crickets") else ""
			if cricket_a == "":
				continue
			var won: bool = (att == cricket_a and result == "suppressed") or (defn == cricket_a and result == "countered")
			var lost: bool = (att == cricket_a and result == "countered") or (defn == cricket_a and result == "suppressed")
			if won:
				grapple_win += 1
			if lost:
				grapple_lose += 1
	var cricket_a_id: String = str(start["crickets"][0]["id"])
	var cricket_b_id: String = str(start["crickets"][1]["id"])
	return {
		"match_id": int(ending["match_id"]),
		"a": cricket_a_id,
		"b": cricket_b_id,
		"winner": str(ending["winner"]),
		"loser": str(ending["loser"]),
		"reason": str(ending["reason"]),
		"ticks": int(ending["tick"]),
		"a_actions": action_count.get(cricket_a_id, {}),
		"b_actions": action_count.get(cricket_b_id, {}),
		"a_whiff": int(whiff.get(cricket_a_id, 0)),
		"b_whiff": int(whiff.get(cricket_b_id, 0)),
		"a_grapple_win": grapple_win,
		"a_grapple_lose": grapple_lose,
		"a_avg_pressure": _avg(pressure_sum, pressure_count, cricket_a_id),
		"b_avg_pressure": _avg(pressure_sum, pressure_count, cricket_b_id),
		"a_max_pressure": int(pressure_max.get(cricket_a_id, 0)),
		"b_max_pressure": int(pressure_max.get(cricket_b_id, 0)),
		"a_stress": int(stress.get(cricket_a_id, 0)),
		"b_stress": int(stress.get(cricket_b_id, 0)),
	}


func _avg(sums: Dictionary, counts: Dictionary, id: String) -> float:
	var count: int = int(counts.get(id, 0))
	if count <= 0:
		return 0.0
	return float(int(sums.get(id, 0))) / float(count)


func _write_summary(folder: String, rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("match_id,cricket_a,cricket_b,winner,loser,reason,ticks,a_hold,a_retreat,a_approach,a_flank,a_bite,b_hold,b_retreat,b_approach,b_flank,b_bite,a_whiff,b_whiff,a_grapple_win,a_grapple_lose,a_avg_pressure,a_max_pressure,a_stress_triggers,b_avg_pressure,b_max_pressure,b_stress_triggers")
	for row in rows:
		var item: Dictionary = row
		var fields: PackedStringArray = PackedStringArray([
			str(int(item["match_id"])),
			str(item["a"]),
			str(item["b"]),
			str(item["winner"]),
			str(item["loser"]),
			str(item["reason"]),
			str(int(item["ticks"])),
		])
		_append_ratios(fields, item["a_actions"])
		_append_ratios(fields, item["b_actions"])
		fields.append(str(int(item["a_whiff"])))
		fields.append(str(int(item["b_whiff"])))
		fields.append(str(int(item["a_grapple_win"])))
		fields.append(str(int(item["a_grapple_lose"])))
		fields.append(_num(float(item["a_avg_pressure"])))
		fields.append(str(int(item["a_max_pressure"])))
		fields.append(str(int(item["a_stress"])))
		fields.append(_num(float(item["b_avg_pressure"])))
		fields.append(str(int(item["b_max_pressure"])))
		fields.append(str(int(item["b_stress"])))
		lines.append(",".join(fields))
	_write(folder + "/summary.csv", "\n".join(lines) + "\n")


func _write_dist(folder: String, rows: Array) -> void:
	var table: Dictionary = {}
	for row in rows:
		var item: Dictionary = row
		_accumulate(table, str(item["a"]), item["a_actions"], str(item["winner"]) == str(item["a"]), int(item["ticks"]), float(item["a_avg_pressure"]))
		_accumulate(table, str(item["b"]), item["b_actions"], str(item["winner"]) == str(item["b"]), int(item["ticks"]), float(item["b_avg_pressure"]))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("id,matches,hold,retreat,approach,flank,bite,win_rate,avg_ticks,avg_pressure")
	var ids: Array = table.keys()
	ids.sort()
	for id in ids:
		var bucket: Dictionary = table[id]
		var fields: PackedStringArray = PackedStringArray([str(id), str(int(bucket["matches"]))])
		_append_ratios(fields, bucket["actions"])
		var matches: int = int(bucket["matches"])
		var win_rate: float = 0.0
		if matches > 0:
			win_rate = float(int(bucket["wins"])) / float(matches)
		var avg_ticks: float = 0.0
		var avg_pressure: float = 0.0
		if matches > 0:
			avg_ticks = float(int(bucket["ticks"])) / float(matches)
			avg_pressure = float(bucket["pressure"]) / float(matches)
		fields.append(_num(win_rate))
		fields.append(_num(avg_ticks))
		fields.append(_num(avg_pressure))
		lines.append(",".join(fields))
	_write(folder + "/dist.csv", "\n".join(lines) + "\n")


func _accumulate(table: Dictionary, id: String, actions: Dictionary, won: bool, ticks: int, avg_pressure: float) -> void:
	if not table.has(id):
		table[id] = {"matches": 0, "wins": 0, "ticks": 0, "pressure": 0.0, "actions": {}}
	var bucket: Dictionary = table[id]
	bucket["matches"] = int(bucket["matches"]) + 1
	if won:
		bucket["wins"] = int(bucket["wins"]) + 1
	bucket["ticks"] = int(bucket["ticks"]) + ticks
	bucket["pressure"] = float(bucket["pressure"]) + avg_pressure
	for action_name in actions.keys():
		bucket["actions"][action_name] = int(bucket["actions"].get(action_name, 0)) + int(actions[action_name])
	table[id] = bucket


func _append_ratios(fields: PackedStringArray, actions: Dictionary) -> void:
	var total: int = 0
	for action_name in ACTIONS:
		total += int(actions.get(action_name, 0))
	var parts: Array = []
	var sum_parts: int = 0
	var largest: int = 0
	for index in ACTIONS.size():
		var count: int = int(actions.get(ACTIONS[index], 0))
		var part: int = 0
		if total > 0:
			part = int(round(float(count) * 1000.0 / float(total)))
		parts.append(part)
		sum_parts += part
		if part > int(parts[largest]):
			largest = index
	if total > 0 and sum_parts != 1000:
		parts[largest] = int(parts[largest]) + (1000 - sum_parts)
	for part in parts:
		fields.append(_thousandths(int(part)))


func _thousandths(part: int) -> String:
	var whole: int = int(float(part) / 1000.0)
	var frac: int = part - whole * 1000
	if frac < 0:
		frac = -frac
	return "%d.%03d" % [whole, frac]


func _num(value: float) -> String:
	return _thousandths(int(round(value * 1000.0)))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.flush()
	file.close()
