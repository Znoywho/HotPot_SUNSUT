class_name Customer
extends Node

signal order_placed(broth_id: String, side_items: Array[String])
signal left_angry

var desired_broth_id := ""
var group_size := 1 ## Số người trong nhóm (mỗi người ăn 1 phần lẩu).
var side_items: Array[String] = []
var wait_time := 20.0
var _remaining := 0.0
var _active := false


func setup(broth_id: String, sides: Array[String], wait_seconds: float) -> void:
	desired_broth_id = broth_id
	side_items = sides
	wait_time = wait_seconds
	_remaining = wait_seconds
	_active = true
	order_placed.emit(broth_id, sides)


func _process(delta: float) -> void:
	if not _active:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_active = false
		left_angry.emit()


func remaining_time() -> float:
	return maxf(_remaining, 0.0)


func stop_waiting() -> void:
	_active = false