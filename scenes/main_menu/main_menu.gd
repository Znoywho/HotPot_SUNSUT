extends ScreenBase


func _get_title() -> String:
	return "SÔI SÙNG SỤC"


func _show_status() -> bool:
	return false


func _setup() -> void:
	add_action("Chơi mới", DayManager.start_new_game)
	var continue_button := add_action("Tiếp tục", DayManager.continue_game)
	continue_button.disabled = not SaveManager.has_save()
	if not OS.has_feature("web"): # Trên web không thoát được tab, nên ẩn nút.
		add_action("Thoát", get_tree().quit)
	log_line("Quản lý quán lẩu: sáng đi săn nguyên liệu, trưa nấu nước cốt, chiều tối bán hàng.")
	log_line("Mỗi ngày phải đạt KPI, không đạt là thua.")
	log_line("")
	log_line("[i]Nhóm: Lê Thiên Hạo, Đỗ Hoàng Hải, Nguyễn Ngọc Minh Tuấn[/i]")
