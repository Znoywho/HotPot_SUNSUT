class_name Cart
extends Node

var carrying_broth_id := ""
var carrying_expired := false ## Nồi đang bưng là đồ hết hạn (chủ quán chọn bán tiếp).


## Lấy nồi cũ nhất trong kho.
func pick_broth(broth_id: String) -> bool:
	var r := GameState.take_broth_info(broth_id)
	if not r["ok"]:
		return false
	carrying_broth_id = broth_id
	carrying_expired = r["expired"]
	return true


func serve_to(table: TableNode) -> bool:
	if carrying_broth_id == "":
		return false
	var ok := table.serve(carrying_broth_id)
	if ok:
		table.served_expired = carrying_expired
		carrying_broth_id = ""
		carrying_expired = false
	return ok


func clear() -> void:
	carrying_broth_id = ""
	carrying_expired = false