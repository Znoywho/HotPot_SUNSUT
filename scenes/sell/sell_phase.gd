extends Control
## Chiều tối – bán hàng.

const TIP_MIN := 0.03
const TIP_MAX := 0.07
const BASE_EATING_TIME := 8.0
const SPAWN_INTERVAL := 6.0
const CUSTOMER_WAIT := 20.0

var tables: Array[TableNode] = []
var cart := Cart.new()
var _spawn_timer := 3.0
var _table_ui: Array[Dictionary] = []

var _revenue_label: Label
var _stars_label: Label
var _timer_label: Label
var _cart_label: Label
var _inventory_box: HBoxContainer
var _notification_label: Label
var _inventory_buttons: Array[Button] = []
var _inventory_ids: Array[String] = []


func _ready() -> void:
	add_child(cart)
	_build_ui()
	_setup()


func _process(delta: float) -> void:
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
	_update_ui()


func _build_ui() -> void:
	add_child(HuntUI.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := HuntUI.outlined_label("Chiều tối · Bán hàng", 26, HuntUI.GOLD)
	root.add_child(title)

	var header := HBoxContainer.new()
	root.add_child(header)
	_revenue_label = HuntUI.outlined_label("", 18, HuntUI.GOLD)
	header.add_child(_revenue_label)
	_stars_label = HuntUI.outlined_label("", 18, HuntUI.GOLD)
	header.add_child(_stars_label)
	_timer_label = HuntUI.outlined_label("", 18, HuntUI.GOLD)
	header.add_child(_timer_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	grid.set_meta("grid", true)
	set_meta("grid", grid)

	var cart_bar := HBoxContainer.new()
	root.add_child(cart_bar)
	var inv_label := HuntUI.label("Kho nước cốt:", 18, HuntUI.INK)
	cart_bar.add_child(inv_label)
	_inventory_box = HBoxContainer.new()
	cart_bar.add_child(_inventory_box)
	_cart_label = HuntUI.label("Xe đẩy: [Trống]", 18, HuntUI.INK)
	cart_bar.add_child(_cart_label)

	_notification_label = HuntUI.label("", 20, HuntUI.RUST)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_notification_label)

	var footer := HuntUI.button("Đóng cửa, tổng kết »")
	footer.pressed.connect(DayManager.next_phase)
	root.add_child(footer)


func _setup() -> void:
	var grid: GridContainer = get_meta("grid")
	for i in GameState.tables_floor1:
		var table := TableNode.new()
		table.eating_time = BASE_EATING_TIME * Database.upgrade_value("stove")
		add_child(table)
		tables.append(table)
		table.customer_left.connect(_on_table_cleared)
		table.eating_finished.connect(_on_eating_finished)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(240, 180)
		card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card"))
		var vbox := VBoxContainer.new()
		card.add_child(vbox)

		var status := HuntUI.label("", 18, HuntUI.INK)
		vbox.add_child(status)

		var order_lbl := HuntUI.label("", 16, HuntUI.INK_SOFT)
		vbox.add_child(order_lbl)

		var wait_bar := ProgressBar.new()
		wait_bar.custom_minimum_size = Vector2(0, 20)
		vbox.add_child(wait_bar)
		var wait_time_lbl := HuntUI.label("", 16, HuntUI.INK_SOFT)
		vbox.add_child(wait_time_lbl)

		var eat_bar := ProgressBar.new()
		eat_bar.custom_minimum_size = Vector2(0, 20)
		vbox.add_child(eat_bar)
		var eat_time_lbl := HuntUI.label("", 16, HuntUI.INK_SOFT)
		vbox.add_child(eat_time_lbl)

		var serve_btn := HuntUI.button("Giao món đến bàn")
		serve_btn.pressed.connect(_serve_table.bind(table))
		vbox.add_child(serve_btn)

		grid.add_child(card)
		_table_ui.append({
			"table": table,
			"status": status,
			"order": order_lbl,
			"wait_bar": wait_bar,
			"wait_time": wait_time_lbl,
			"eat_bar": eat_bar,
			"eat_time": eat_time_lbl,
			"serve": serve_btn,
		})
	log_line_safe("Quán có %d bàn." % GameState.tables_floor1)
	for broth in Database.broths_for_day(GameState.day):
		var btn := HuntUI.button(broth.display_name)
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_pick_to_cart.bind(broth.id))
		_inventory_box.add_child(btn)
		_inventory_buttons.append(btn)
		_inventory_ids.append(broth.id)


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
	log_line_safe("Khách vào bàn, gọi %s." % broth.display_name)


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


func _pick_to_cart(broth_id: String) -> void:
	if cart.carrying_broth_id != "":
		_notification_label.text = "Xe đẩy đang chở món khác."
		return
	if not cart.pick_broth(broth_id):
		var broth := Database.get_broth(broth_id)
		_notification_label.text = "Kho chưa có món %s!" % (broth.display_name if broth else broth_id)
		return
	_notification_label.text = "Đã bốc %s lên xe đẩy." % broth_id


func _serve_table(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	if cart.carrying_broth_id == "":
		if not cart.pick_broth(table.order_broth_id):
			var broth := Database.get_broth(table.order_broth_id)
			_notification_label.text = "Kho chưa có món %s!" % (broth.display_name if broth else table.order_broth_id)
			return
	elif cart.carrying_broth_id != table.order_broth_id:
		_notification_label.text = "Xe đẩy đang chở %s, bàn này gọi %s!" % [cart.carrying_broth_id, table.order_broth_id]
		return
	if cart.serve_to(table):
		log_line_safe("Đã giao %s đến bàn." % table.order_broth_id)
		_notification_label.text = "Đã phục vụ bàn thành công."


func _finish_eating(table: TableNode) -> void:
	var broth := Database.get_broth(table.order_broth_id)
	if broth:
		var tip_rate := randf_range(TIP_MIN, TIP_MAX) + Database.upgrade_value("furniture")
		var tip := roundi(broth.price * tip_rate / 1000.0) * 1000
		GameState.add_money(broth.price + tip)
		log_line_safe("Khách thanh toán %s: %s + tip %s" % [broth.display_name, GameState.format_money(broth.price), GameState.format_money(tip)])
		_notification_label.text = "Bàn thanh toán: +%s (Tip: +%s)" % [GameState.format_money(broth.price), GameState.format_money(tip)]
	table.clear()


func _customer_timeout(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	GameState.lose_star()
	log_line_safe("[color=red]Khách bỏ về, quán bị trừ sao.[/color]")
	_notification_label.text = "Khách hết kiên nhẫn bỏ về! Bị trừ 1 sao."
	table.clear()


func _on_table_cleared(_table: TableNode) -> void:
	pass


func _on_eating_finished(table: TableNode) -> void:
	_finish_eating(table)


func _update_ui() -> void:
	_revenue_label.text = "Doanh thu: %s / %s" % [GameState.format_money(GameState.today_revenue), GameState.format_money(GameState.kpi_target)]
	_stars_label.text = "Sao: %.1f" % GameState.stars
	if cart.carrying_broth_id == "":
		_cart_label.text = "Xe đẩy: [Trống]"
	else:
		_cart_label.text = "Xe đẩy: [Đang chở: %s]" % cart.carrying_broth_id
	for i in _inventory_ids.size():
		var id := _inventory_ids[i]
		var btn := _inventory_buttons[i]
		var broth := Database.get_broth(id)
		btn.text = "%s: x%d" % [broth.display_name if broth else id, GameState.get_broth_count(id)]
	for ui in _table_ui:
		var table: TableNode = ui["table"]
		var status: Label = ui["status"]
		var order_lbl: Label = ui["order"]
		var wait_bar: ProgressBar = ui["wait_bar"]
		var wait_time_lbl: Label = ui["wait_time"]
		var eat_bar: ProgressBar = ui["eat_bar"]
		var eat_time_lbl: Label = ui["eat_time"]
		var serve_btn: Button = ui["serve"]
		if table.state == TableNode.State.EMPTY:
			status.text = "Bàn: Trống - Đang chờ khách"
			order_lbl.text = ""
			wait_bar.value = 0
			wait_time_lbl.text = ""
			eat_bar.value = 0
			eat_time_lbl.text = ""
			serve_btn.disabled = true
			serve_btn.text = "Giao món"
		elif table.state == TableNode.State.WAITING_ORDER:
			var broth := Database.get_broth(table.order_broth_id)
			status.text = "Khách đang ngồi"
			var side_names: Array[String] = []
			for id in table.side_items:
				side_names.append(GameState.item_display_name(id))
			order_lbl.text = "Gọi: %s | Nhúng: %s" % [broth.display_name if broth else table.order_broth_id, ", ".join(side_names)]
			var rem := table.customer.remaining_time() if table.customer else 0.0
			wait_bar.value = 100.0 * (1.0 - rem / CUSTOMER_WAIT)
			wait_time_lbl.text = "%.0fs còn lại" % rem
			eat_bar.value = 0
			eat_time_lbl.text = ""
			serve_btn.disabled = false
			serve_btn.text = "Giao món đến bàn"
		elif table.state == TableNode.State.EATING:
			var broth := Database.get_broth(table.order_broth_id)
			status.text = "Khách đang thưởng thức lẩu..."
			order_lbl.text = broth.display_name if broth else table.order_broth_id
			wait_bar.value = 100
			wait_time_lbl.text = ""
			var erem := table.eating_remaining()
			eat_bar.value = 100.0 * (1.0 - erem / table.eating_time)
			eat_time_lbl.text = "%.0fs còn lại" % erem
			serve_btn.disabled = true
			serve_btn.text = "Đang ăn"
		else:
			status.text = "Trạng thái khác"
			serve_btn.disabled = true


func log_line_safe(text: String) -> void:
	print(text)