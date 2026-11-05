extends ScreenBase
## Chiều tối – bán hàng.

const TIP_MIN := 0.03
const TIP_MAX := 0.07
const BASE_EATING_TIME := 8.0
const SPAWN_INTERVAL := 6.0
const CUSTOMER_WAIT := 20.0

var tables: Array[TableNode] = []
var cart := Cart.new()
var _spawn_timer := 3.0
var _ui_timer := 0.0
var _buttons: Array[Button] = []


func _get_title() -> String:
	return "Chiều tối – Bán hàng"


func _ready() -> void:
	super._ready()
	add_child(cart)


func _process(delta: float) -> void:
	super._process(delta)
	var spawn_interval := SPAWN_INTERVAL / maxf(0.2, GameState.customer_multiplier)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_try_spawn_customer()
	for table in tables:
		if table.state == TableNode.State.WAITING_ORDER and table.customer:
			if table.customer.remaining_time() <= 0.0:
				_customer_timeout(table)
		elif table.state == TableNode.State.EATING:
			if table.eating_remaining() <= 0.0:
				_finish_eating(table)
	_ui_timer += delta
	if _ui_timer >= 0.5:
		_ui_timer = 0.0
		_update_buttons()


func _setup() -> void:
	for i in GameState.tables_floor1:
		var table := TableNode.new()
		table.eating_time = BASE_EATING_TIME * Database.upgrade_value("stove")
		add_child(table)
		tables.append(table)
		table.customer_left.connect(_on_table_cleared)
		table.eating_finished.connect(_on_eating_finished)
	_rebuild_ui()
	add_action("Đóng cửa, tổng kết »", DayManager.next_phase)
	log_line("Quán có %d bàn." % GameState.tables_floor1)


func _try_spawn_customer() -> void:
	var empty_table := _first_empty_table()
	if empty_table == null:
		return
	var broth := _random_unlocked_broth()
	if broth == null:
		return
	var sides := _random_side_items()
	var customer := Customer.new()
	add_child(customer)
	customer.setup(broth.id, sides, CUSTOMER_WAIT)
	empty_table.occupy(customer)
	empty_table.place_order(broth.id, sides)
	log_line("Khách vào bàn, gọi %s." % broth.display_name)
	_rebuild_ui()


func _first_empty_table() -> TableNode:
	for table in tables:
		if table.state == TableNode.State.EMPTY:
			return table
	return null


func _random_unlocked_broth() -> BrothData:
	var broths := Database.broths_for_day(GameState.day)
	if broths.is_empty():
		return null
	return broths[randi() % broths.size()]


func _random_side_items() -> Array[String]:
	var pool := ["beef", "mushroom", "greens", "shrimp", "enoki", "tomato"]
	var count := 1 + randi() % 2
	var result: Array[String] = []
	for i in count:
		result.append(pool[randi() % pool.size()])
	return result


func _serve_table(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	if not cart.pick_broth(table.order_broth_id):
		var broth := Database.get_broth(table.order_broth_id)
		log_line("[color=orange]Kho chưa có món %s![/color]" % (broth.display_name if broth else table.order_broth_id))
		return
	if cart.serve_to(table):
		log_line("Đã giao %s đến bàn." % table.order_broth_id)
		_rebuild_ui()


func _finish_eating(table: TableNode) -> void:
	var broth := Database.get_broth(table.order_broth_id)
	if broth:
		var tip_rate := randf_range(TIP_MIN, TIP_MAX) + Database.upgrade_value("furniture")
		var tip := roundi(broth.price * tip_rate)
		GameState.add_money(broth.price + tip)
		log_line("Khách thanh toán %s: %s + tip %s" % [broth.display_name, GameState.format_money(broth.price), GameState.format_money(tip)])
	table.clear()
	_rebuild_ui()


func _customer_timeout(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	GameState.lose_star()
	log_line("[color=red]Khách bỏ về, quán bị trừ sao.[/color]")
	table.clear()
	_rebuild_ui()


func _on_table_cleared(_table: TableNode) -> void:
	pass


func _on_eating_finished(table: TableNode) -> void:
	_finish_eating(table)


func _rebuild_ui() -> void:
	clear_actions()
	_buttons.clear()
	for i in tables.size():
		var table := tables[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.add_theme_font_size_override("font_size", 20)
		if table.state == TableNode.State.EMPTY:
			button.text = "Bàn %d: Trống - Đang chờ khách" % (i + 1)
			button.disabled = true
		elif table.state == TableNode.State.WAITING_ORDER:
			button.text = "👉 Giao món cho Bàn %d: Cần %s (%.0fs)" % [i + 1, table.order_broth_id, table.customer.remaining_time() if table.customer else 0.0]
			button.disabled = false
			button.pressed.connect(_serve_table.bind(table))
		elif table.state == TableNode.State.EATING:
			button.text = "Bàn %d: Khách đang ăn (%.0fs)" % [i + 1, table.eating_remaining()]
			button.disabled = true
		else:
			button.text = "Bàn %d: %s" % [i + 1, "Trạng thái khác"]
			button.disabled = true
		actions.add_child(button)
		_buttons.append(button)
	add_action("Đóng cửa, tổng kết »", DayManager.next_phase)


func _update_buttons() -> void:
	for i in tables.size():
		if i >= _buttons.size():
			return
		var table := tables[i]
		var button := _buttons[i]
		if table.state == TableNode.State.WAITING_ORDER:
			button.text = "👉 Giao món cho Bàn %d: Cần %s (%.0fs)" % [i + 1, table.order_broth_id, table.customer.remaining_time() if table.customer else 0.0]
		elif table.state == TableNode.State.EATING:
			button.text = "Bàn %d: Khách đang ăn (%.0fs)" % [i + 1, table.eating_remaining()]