class_name TableNode
extends Node

enum State { EMPTY, OCCUPIED, WAITING_ORDER, SERVED, EATING }
var state: State = State.EMPTY
var customer: Customer = null
var order_broth_id := ""
var side_items: Array[String] = []
var is_served := false
var eating_time := 0.0
var _eating_remaining := 0.0

signal customer_arrived(table: TableNode)
signal order_ready(table: TableNode, broth_id: String, side_items: Array[String])
signal customer_left(table: TableNode)
signal eating_finished(table: TableNode)


func occupy(c: Customer) -> void:
	customer = c
	state = State.OCCUPIED
	customer_arrived.emit(self)


func place_order(broth_id: String, sides: Array[String]) -> void:
	order_broth_id = broth_id
	side_items = sides
	state = State.WAITING_ORDER
	order_ready.emit(self, broth_id, sides)


func serve(broth_id: String) -> bool:
	if state != State.WAITING_ORDER or broth_id != order_broth_id:
		return false
	is_served = true
	state = State.EATING
	_eating_remaining = eating_time
	if customer:
		customer.stop_waiting()
	return true


func _process(delta: float) -> void:
	if state != State.EATING:
		return
	_eating_remaining -= delta
	if _eating_remaining <= 0.0:
		eating_finished.emit(self)


func eating_remaining() -> float:
	return maxf(_eating_remaining, 0.0)


func clear() -> void:
	if customer and customer.is_inside_tree():
		customer.queue_free()
	customer = null
	order_broth_id = ""
	side_items.clear()
	is_served = false
	state = State.EMPTY
	customer_left.emit(self)