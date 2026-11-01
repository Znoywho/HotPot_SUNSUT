extends ScreenBase
## Chiều tối – bán hàng.
## BẢN TẠM: bấm nút để giả lập phục vụ 1 bàn hoặc khách bỏ về.
## TODO(Tuấn): khách vào nhận bàn -> gọi nước cốt + món nhúng -> người chơi chọn bàn,
##   xếp món lên xe đẩy, giao đúng bàn. Giao kịp: tip 3–7% (+ Nội thất).
##   Chờ quá lâu: khách bỏ về, GameState.lose_star(). Lượng khách x GameState.customer_multiplier.

const TIP_MIN := 0.03
const TIP_MAX := 0.07


func _get_title() -> String:
	return "Chiều tối – Bán hàng"


func _setup() -> void:
	add_action("Phục vụ 1 bàn đúng giờ (giả lập)", _serve_table)
	add_action("Khách chờ lâu bỏ về (giả lập)", _customer_left)
	add_action("Đóng cửa, tổng kết »", DayManager.next_phase)
	log_line("Quán có %d bàn. Hết giờ sẽ tự đóng cửa." % GameState.tables_floor1)


func _serve_table() -> void:
	var broth := _first_available_broth()
	if broth == null:
		log_line("[color=orange]Hết nước cốt! Không phục vụ được.[/color]")
		return
	GameState.take_broth(broth.id)
	var tip_rate := randf_range(TIP_MIN, TIP_MAX) + Database.upgrade_value("furniture")
	var tip := roundi(broth.price * tip_rate)
	GameState.add_money(broth.price + tip)
	log_line("Phục vụ %s: %s + tip %s" % [broth.display_name, GameState.format_money(broth.price), GameState.format_money(tip)])


func _customer_left() -> void:
	GameState.lose_star()
	log_line("[color=red]Khách bỏ về, quán bị trừ sao.[/color]")


func _first_available_broth() -> BrothData:
	for id in GameState.broths:
		if GameState.get_broth_count(id) > 0:
			return Database.get_broth(id)
	return null
