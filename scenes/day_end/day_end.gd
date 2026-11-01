extends ScreenBase
## Tổng kết cuối ngày: kiểm tra KPI.


func _get_title() -> String:
	return "Tổng kết ngày %d" % GameState.day


func _setup() -> void:
	log_line("Doanh thu: [b]%s[/b]" % GameState.format_money(GameState.today_revenue))
	log_line("KPI:       [b]%s[/b]" % GameState.format_money(GameState.kpi_target))
	if GameState.stars_lost_today > 0:
		log_line("Bị trừ sao %d lần, khách ngày mai sẽ giảm." % GameState.stars_lost_today)
	log_line("")
	if GameState.is_kpi_reached():
		log_line("[color=green][b]ĐẠT KPI![/b][/color] KPI ngày mai: %s" %
			GameState.format_money(GameState.next_kpi()))
		add_action("Đến cửa hàng nâng cấp »", DayManager.next_phase)
	else:
		log_line("[color=red][b]KHÔNG ĐẠT KPI.[/b][/color]")
		add_action("Xem kết quả »", DayManager.next_phase)
