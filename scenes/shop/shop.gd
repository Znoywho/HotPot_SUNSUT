extends ScreenBase
## Cửa hàng nâng cấp (mở sau khi đạt KPI). Game đã được lưu khi vào màn này.
## TODO(Hạo): chia tab Bếp / Chiến đấu / Quán, hiển thị mô tả, tiến hóa khi max cấp,
##   Lầu 2, phòng riêng, nhân viên.

## Số bàn tầng 1 nay là nâng cấp "Thêm bàn" (data/upgrades/tables.tres, tối đa 10 bàn); đủ 10 bàn thì
## mở "Phí phục vụ" (service.tres) qua trường evolves_into. Giá trong .tres. TODO(nhóm): cân bằng.


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
		if _is_locked(upgrade):
			continue
		var level := GameState.get_upgrade_level(upgrade.id)
		var cost := upgrade.cost_for_next(level)
		var text := "%s – MAX" % upgrade.display_name
		if cost >= 0:
			text = "%s (cấp %d/%d) – %s" % [upgrade.display_name, level, upgrade.max_level(), GameState.format_money(cost)]
		# Mô tả nằm ngay trên nút (không dùng tooltip vì điện thoại không có hover).
		var button := add_action("%s\n%s" % [text, upgrade.description], _buy_upgrade.bind(upgrade))
		button.disabled = cost < 0 or not GameState.can_afford(cost)

	add_action("Bắt đầu ngày %d »" % GameState.day, DayManager.next_phase)


func _buy_upgrade(upgrade: UpgradeData) -> void:
	var level := GameState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	if cost >= 0 and GameState.spend_money(cost):
		GameState.set_upgrade_level(upgrade.id, level + 1)
		log_line("Đã nâng %s lên cấp %d." % [upgrade.display_name, level + 1])
		if upgrade.id == "tables":
			GameState.tables_floor1 = int(upgrade.value_at(level + 1))
			log_line("Tầng 1 có %d bàn." % GameState.tables_floor1)
		if level + 1 == upgrade.max_level() and upgrade.evolves_into != "":
			var next := Database.get_upgrade(upgrade.evolves_into)
			log_line("[color=yellow]%s đã max cấp! Mở khóa %s.[/color]" % [upgrade.display_name, next.display_name if next else upgrade.evolves_into])
	_rebuild()


## Nâng cấp mở khóa nhờ tiến hóa (vd Phí phục vụ) chỉ hiện khi nâng cấp gốc đã max cấp.
func _is_locked(upgrade: UpgradeData) -> bool:
	for other in Database.upgrades:
		if other.evolves_into == upgrade.id:
			return GameState.get_upgrade_level(other.id) < other.max_level()
	return false
