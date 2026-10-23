extends RefCounted
class_name Cricket

var id: String = ""
var x: int = 0
var y: int = 0
var facing_x: int = 1
var facing_y: int = 0
var stamina: int = 100
var pressure: int = 0
var last_action: String = ""
var consec_hold: int = 0
var param_a: int = 0
var param_r: int = 0
var param_e: int = 0
var param_s: int = 0
var param_p: int = 0
var stun: bool = false
var retreat_chain: int = 0


func apply_deltas(stamina_delta: int, pressure_delta: int) -> void:
	stamina = clampi(stamina + stamina_delta, 0, 100)
	pressure = clampi(pressure + pressure_delta, 0, 100)


func note_action(action_name: String) -> void:
	if action_name == "hold":
		consec_hold += 1
	else:
		consec_hold = 0
	if action_name == "retreat":
		retreat_chain += 1
	else:
		retreat_chain = 0
	last_action = action_name
