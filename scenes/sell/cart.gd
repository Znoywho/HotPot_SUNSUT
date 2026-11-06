class_name Cart
extends Node

var carrying_broth_id := ""


func pick_broth(broth_id: String) -> bool:
	if not GameState.take_broth(broth_id):
		return false
	carrying_broth_id = broth_id
	return true


func serve_to(table: TableNode) -> bool:
	if carrying_broth_id == "":
		return false
	var ok := table.serve(carrying_broth_id)
	if ok:
		carrying_broth_id = ""
	return ok


func clear() -> void:
	carrying_broth_id = ""