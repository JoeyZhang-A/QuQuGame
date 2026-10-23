extends SceneTree

const RulesTest = preload("res://tests/test_rules.gd")
const GrappleTest = preload("res://tests/test_grapple.gd")
const DecisionTest = preload("res://tests/test_decision.gd")


func _initialize() -> void:
	var results: Array = []
	results.append_array(RulesTest.collect())
	results.append_array(GrappleTest.collect())
	results.append_array(DecisionTest.collect())
	var failed: int = 0
	for item in results:
		var row: Dictionary = item
		if bool(row["ok"]):
			print("PASS %s" % str(row["name"]))
		else:
			failed += 1
			print("FAIL %s: 期望 %s，实际 %s" % [str(row["name"]), str(row["expected"]), str(row["actual"])])
	var passed: int = results.size() - failed
	print("%d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)
