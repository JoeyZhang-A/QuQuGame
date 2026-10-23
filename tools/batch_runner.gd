extends SceneTree

const ConfigLib = preload("res://src/core/config.gd")
const MatchLib = preload("res://src/core/match.gd")


func _initialize() -> void:
	var out_dir: String = "res://out"
	var all_pairs: bool = false
	for arg in OS.get_cmdline_user_args():
		var text: String = str(arg)
		if text.begins_with("--out="):
			out_dir = text.substr(6)
		elif text == "--all-pairs":
			all_pairs = true
	if not all_pairs:
		printerr("需要 --all-pairs")
		quit(1)
		return
	var loaded: Dictionary = ConfigLib.load_project()
	if not bool(loaded["ok"]):
		printerr(str(loaded["error"]))
		quit(1)
		return
	var config: Config = loaded["config"]
	var ids: Array = []
	for row in config.crickets():
		var item: Dictionary = row
		ids.append(str(item["id"]))
	var folder: String = out_dir
	if folder.begins_with("res://"):
		folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var match_id: int = 0
	for left in range(ids.size()):
		for right in range(left + 1, ids.size()):
			var bout: Match = MatchLib.new(config, str(ids[left]), str(ids[right]))
			var path: String = folder + "/match_%d.jsonl" % match_id
			bout.open_log(path, match_id)
			bout.run()
			bout.close_log()
			print("MATCH %d %s %s %s %s tick %d" % [match_id, str(ids[left]), str(ids[right]), bout.winner_id, bout.end_reason, bout.end_tick])
			match_id += 1
	print("WROTE %d" % match_id)
	quit(0)
