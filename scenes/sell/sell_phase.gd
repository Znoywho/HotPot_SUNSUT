extends ScreenBase
## Chiều tối – bán hàng.

const TIP_MIN := 0.03
const TIP_MAX := 0.07
const BASE_EATING_TIME := 8.0
const SPAWN_INTERVAL := 6.0
const CUSTOMER_WAIT := 20.0
## Sao: phục vụ nhanh (còn hơn nửa thời gian chờ) được cộng nhiều hơn; khách bỏ về bị trừ.
const STAR_FAST_SERVE := 0.15
const STAR_SERVE := 0.05
const STAR_CUSTOMER_LEFT := 0.25
## Thương lượng đổi món khi hết: tỷ lệ khách đồng ý (vòng quay Có/Không chia đôi).
const NEGOTIATE_CHANCE := 0.5
## Bán đồ hết hạn: 25% khách phát hiện -> hoàn tiền + bồi thường gấp đôi giá món + trừ sao.
const EXPIRED_DETECT_CHANCE := 0.25
const EXPIRED_COMPENSATION := 2.0
const EXPIRED_STAR_LOSS := 0.5

var tables: Array[TableNode] = []
var cart := Cart.new()
var _spawn_timer := 3.0
var _ui_timer := 0.0
var _buttons: Array[Button] = []
var _negotiating: TableNode = null ## Bàn đang quay thương lượng.
var _events := SellEvents.new() ## Thanh tra, nhà phê bình, giám khảo Michelin.


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
			if table.customer.remaining_time() <= 0.0 and table != _negotiating:
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
	add_child(_events)
	_events.setup(self)
	_rebuild_ui()
	log_line("Quán có %d bàn." % GameState.tables_floor1)
	var expired := GameState.expired_stock_count()
	if expired > 0:
		log_line("[color=orange]Kho đang giữ %d món hết hạn: bán ra có thể bị khách phát hiện, thanh tra tới là bị phạt.[/color]" % expired)


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
	empty_table.special = _events.take_pending_special()
	if empty_table.special == "critic":
		log_line("[color=#6a3d9a]Nhà phê bình vào bàn, gọi %s.[/color]" % broth.display_name)
	else:
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
	if _negotiating != null:
		return
	if not cart.pick_broth(table.order_broth_id):
		_negotiate(table)
		return
	_deliver(table)


func _deliver(table: TableNode) -> void:
	var fast := table.customer != null and table.customer.remaining_time() > CUSTOMER_WAIT * 0.5
	if cart.serve_to(table):
		table.served_fast = fast
		GameState.add_star(STAR_FAST_SERVE if fast else STAR_SERVE)
		log_line("Đã giao %s đến bàn%s." % [_broth_name(table.order_broth_id), " (nhanh, +sao)" if fast else ""])
		_rebuild_ui()


## Hết món khách gọi: mời khách đổi sang món còn trong kho bằng vòng quay Có/Không.
func _negotiate(table: TableNode) -> void:
	var missing := _broth_name(table.order_broth_id)
	var offer := _best_in_stock()
	if offer == null:
		log_line("[color=orange]Hết %s và kho không còn nồi nào để mời đổi![/color]" % missing)
		return
	if table.customer != null and table.customer.has_meta("negotiated"):
		log_line("[color=orange]Khách bàn này đã từ chối đổi món rồi.[/color]")
		return
	_negotiating = table
	var wheel := NegotiationWheel.new()
	add_child(wheel)
	wheel.open(missing, offer.display_name, NEGOTIATE_CHANCE)
	var accepted: bool = await wheel.decided
	_negotiating = null
	if table.state != TableNode.State.WAITING_ORDER:
		return
	if table.customer != null:
		table.customer.set_meta("negotiated", true)
	if accepted and cart.pick_broth(offer.id):
		table.order_broth_id = offer.id
		if table.customer != null:
			table.customer.desired_broth_id = offer.id
		log_line("[color=#4caf50]Khách đồng ý đổi sang %s.[/color]" % offer.display_name)
		_deliver(table)
	else:
		_customer_timeout(table)


## Món còn trong kho nhiều nồi nhất (hòa thì lấy món đắt hơn).
func _best_in_stock() -> BrothData:
	var best: BrothData = null
	for b in Database.broths:
		var n := GameState.get_broth_count(b.id)
		if n <= 0:
			continue
		if best == null or n > GameState.get_broth_count(best.id) or (n == GameState.get_broth_count(best.id) and b.price > best.price):
			best = b
	return best


func _broth_name(id: String) -> String:
	var broth := Database.get_broth(id)
	return broth.display_name if broth else id


func _finish_eating(table: TableNode) -> void:
	if table.state != TableNode.State.EATING:
		return
	var broth := Database.get_broth(table.order_broth_id)
	# Món hết hạn: khách thường có thể phát hiện; khách đặc biệt luôn phát hiện.
	if broth and table.served_expired and (table.special != "" or randf() < EXPIRED_DETECT_CHANCE):
		var compensation := roundi(broth.price * EXPIRED_COMPENSATION / 1000.0) * 1000
		GameState.add_money(-compensation, false)
		GameState.lose_star(EXPIRED_STAR_LOSS)
		log_line("[color=red]Khách phát hiện %s đã hết hạn! Không trả tiền, quán bồi thường %s, trừ sao.[/color]" % [
			broth.display_name, GameState.format_money(compensation)])
		if table.special != "":
			_events.special_result(table, false, broth.price)
		table.clear()
		_rebuild_ui()
		return
	if broth:
		var tip_rate := randf_range(TIP_MIN, TIP_MAX) + Database.upgrade_value("furniture")
		var tip := roundi(broth.price * tip_rate / 1000.0) * 1000 # Làm tròn đến 1.000đ.
		GameState.add_money(broth.price + tip)
		log_line("Khách thanh toán %s: %s + tip %s" % [broth.display_name, GameState.format_money(broth.price), GameState.format_money(tip)])
		if table.special != "":
			_events.special_result(table, table.served_fast and not table.served_expired, broth.price)
	table.clear()
	_rebuild_ui()


func _customer_timeout(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	GameState.lose_star(STAR_CUSTOMER_LEFT)
	log_line("[color=red]Khách bỏ về, quán bị trừ sao.[/color]")
	if table.special != "":
		_events.special_result(table, false, 0)
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
			button.text = "» %sGiao món cho Bàn %d: %s (%.0fs)" % [SellEvents.tag(table.special), i + 1, _broth_name(table.order_broth_id), table.customer.remaining_time() if table.customer else 0.0]
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
			button.text = "» %sGiao món cho Bàn %d: %s (%.0fs)" % [SellEvents.tag(table.special), i + 1, _broth_name(table.order_broth_id), table.customer.remaining_time() if table.customer else 0.0]
		elif table.state == TableNode.State.EATING:
			button.text = "Bàn %d: Khách đang ăn (%.0fs)" % [i + 1, table.eating_remaining()]