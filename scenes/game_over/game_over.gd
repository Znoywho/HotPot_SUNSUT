extends ScreenBase


func _get_title() -> String:
	return "GAME OVER"


func _setup() -> void:
	log_line("Quán không đạt KPI ở ngày %d." % GameState.day)
	log_line("Doanh thu %s / KPI %s" % [GameState.format_money(GameState.today_revenue), GameState.format_money(GameState.kpi_target)])
	add_action("Chơi lại", DayManager.start_new_game)
	add_action("Về menu", DayManager.go_to_main_menu)
