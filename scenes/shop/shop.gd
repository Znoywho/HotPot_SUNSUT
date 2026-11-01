extends ScreenBase
## Cửa hàng nâng cấp (mở sau khi đạt KPI). Game đã được lưu khi vào màn này.
## TODO(Hạo): chia tab Bếp / Chiến đấu / Quán, hiển thị mô tả, tiến hóa khi max cấp,
##   Lầu 2, phòng riêng, nhân viên.

const TABLE_BASE_PRICE := 50_000 ## Giá bàn tăng dần theo mỗi lần mua. TODO(nhóm): cân bằng.


func _get_title() -> String:
	return "Cửa hàng nâng cấp – chuẩn bị ngày %d" % GameState.day


func _setup() -> void:
	_rebuild()
	if GameState.is_milestone_day():
		log_line("[color=yellow]Mốc ngày %d: quái mạnh hơn, có thể mở khóa nội dung mới.[/color]" % GameState.day)
	log_line("Lượng khách hiện tại: %d%%" % roundi(GameState.customer_multiplier * 100))


func _rebuild() -> void:
	clear_actions()
	for upgrade in Database.upgrades:
		var level := GameState.get_upgrade_level(upgrade.id)
		var cost := upgrade.cost_for_next(level)
		var text := "%s – MAX" % upgrade.display_name
		if cost >= 0:
			text = "%s (cấp %d/%d) – %s" % [upgrade.display_name, level, upgrade.max_level(), GameState.format_money(cost)]
		# Mô tả nằm ngay trên nút (không dùng tooltip vì điện thoại không có hover).
		var button := add_action("%s\n%s" % [text, upgrade.description], _buy_upgrade.bind(upgrade))
		button.disabled = cost < 0 or not GameState.can_afford(cost)

	var table_price := _next_table_price()
	var table_button := add_action(
		"Mua bàn tầng 1 (%d/%d) – %s" % [GameState.tables_floor1, GameState.MAX_TABLES_FLOOR1, GameState.format_money(table_price)],
		_buy_table)
	table_button.disabled = GameState.tables_floor1 >= GameState.MAX_TABLES_FLOOR1 or not GameState.can_afford(table_price)

	add_action("Bắt đầu ngày %d »" % GameState.day, DayManager.next_phase)


func _buy_upgrade(upgrade: UpgradeData) -> void:
	var level := GameState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	if cost >= 0 and GameState.spend_money(cost):
		GameState.set_upgrade_level(upgrade.id, level + 1)
		log_line("Đã nâng %s lên cấp %d." % [upgrade.display_name, level + 1])
		if level + 1 == upgrade.max_level() and upgrade.evolves_into != "":
			log_line("[color=yellow]%s đã max cấp! (TODO: mở khóa %s)[/color]" % [upgrade.display_name, upgrade.evolves_into])
	_rebuild()


func _next_table_price() -> int:
	return TABLE_BASE_PRICE * (GameState.tables_floor1 - GameState.START_TABLES_FLOOR1 + 1)


func _buy_table() -> void:
	if GameState.spend_money(_next_table_price()):
		GameState.tables_floor1 += 1
		log_line("Đã mua thêm bàn. Tầng 1 có %d bàn." % GameState.tables_floor1)
	_rebuild()
