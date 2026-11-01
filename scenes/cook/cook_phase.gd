extends ScreenBase
## Trưa – nấu nước cốt lẩu.
## BẢN TẠM: bấm là nấu xong ngay.
## TODO(Tuấn): thời gian nấu = cook_time * Database.upgrade_value("stove"),
##   giới hạn số nồi nấu cùng lúc theo cấp bếp, UI bếp thật.


func _get_title() -> String:
	return "Trưa – Nấu nước cốt lẩu"


func _setup() -> void:
	_rebuild()
	log_line("Chọn nước cốt để nấu. Mỗi nồi tốn nguyên liệu theo công thức.")


func _rebuild() -> void:
	clear_actions()
	for broth in Database.broths_for_day(GameState.day):
		var button := add_action(
			"Nấu %s (cần %s)" % [broth.display_name, GameState.describe_items(broth.ingredients)],
			_cook.bind(broth))
		button.disabled = not GameState.has_items(broth.ingredients)
	add_action("Mở quán bán hàng »", DayManager.next_phase)


func _cook(broth: BrothData) -> void:
	if GameState.consume_items(broth.ingredients):
		GameState.add_broth(broth.id)
		log_line("Đã nấu 1 nồi %s." % broth.display_name)
	_rebuild()
