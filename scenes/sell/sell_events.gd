class_name SellEvents
extends Node
## Sự kiện ngẫu nhiên trong buổi bán: thanh tra vệ sinh, nhà phê bình ẩm thực, giám khảo Michelin ẩn danh.
## Mỗi sự kiện tự tung xúc xắc xem hôm nay có xảy ra không và xảy ra lúc nào (hoàn toàn ngẫu nhiên).

const EVENT_CHANCE := 1.0 / 3.0 ## Mỗi loại sự kiện có 1/3 khả năng xảy ra trong 1 buổi bán.
const EARLIEST := 0.12 ## Sớm nhất sau 12% buổi bán.
const LATEST := 0.7 ## Muộn nhất ở 70% buổi bán (để kịp phục vụ khách đặc biệt).

const INSPECT_FINE_BASE := 200_000 ## Thanh tra phát hiện đồ hết hạn: phạt cố định...
const INSPECT_FINE_PER_ITEM := 20_000 ## ...cộng thêm theo từng món hết hạn.
const INSPECT_STAR_LOSS := 1.0
const INSPECT_CLEAN_STAR := 0.25

const CRITIC_STAR_WIN := 0.5
const CRITIC_STAR_LOSE := 1.0
const CRITIC_TIP_BONUS := 0.5 ## Thêm 50% giá món vào tip khi nhà phê bình hài lòng.

const MICHELIN_STAR_WIN := 1.0
const MICHELIN_STAR_LOSE := 0.5
const MICHELIN_REWARD := 300_000

const TAGS := {"critic": "[Nhà phê bình] ", "michelin": "[Khách lạ] "}

var _sell: Node ## Màn bán hàng (để ghi log).
var _schedule: Array[Dictionary] = [] ## {kind, at: số giây còn lại của buổi bán khi xảy ra}
var _pending_special := "" ## Khách đặc biệt sẽ vào ở bàn trống kế tiếp.


func setup(sell: Node) -> void:
	_sell = sell
	var total := DayManager.SELL_DURATION
	for kind in ["inspector", "critic", "michelin"]:
		if randf() < EVENT_CHANCE:
			_schedule.append({"kind": kind, "at": total * (1.0 - randf_range(EARLIEST, LATEST))})


func tick(delta: float, _tables: Array, _sell: Node) -> void:
	_process(delta)


func _process(_delta: float) -> void:
	if not DayManager.timer_running:
		return
	for i in range(_schedule.size() - 1, -1, -1):
		if DayManager.time_left <= float(_schedule[i]["at"]):
			var kind: String = _schedule[i]["kind"]
			_schedule.remove_at(i)
			_trigger(kind)


func _trigger(kind: String) -> void:
	match kind:
		"inspector":
			_inspect()
		"critic":
			_queue_special("critic")
			notice("Nhà phê bình ẩm thực tới!", "Một nhà phê bình nổi tiếng sắp vào quán.\nPhục vụ nhanh để được khen, chậm là bị chê lên báo!", Color("6a3d9a"))
		"michelin":
			_queue_special("michelin")
			_log("[color=#8a6d3b]Có vị khách lạ mặt vừa vào, cứ lặng lẽ ghi chép gì đó...[/color]")


## Khách đặc biệt chờ bàn trống; nếu đã có khách đặc biệt chờ thì cái sau lùi lại một chút.
func _queue_special(kind: String) -> void:
	if _pending_special == "":
		_pending_special = kind
	else:
		_schedule.append({"kind": kind, "at": maxf(DayManager.time_left - 10.0, 5.0)})


## Gọi khi có khách mới vào bàn: trả về loại khách đặc biệt (hoặc "").
func take_pending_special() -> String:
	var kind := _pending_special
	_pending_special = ""
	return kind


static func tag(kind: String) -> String:
	return TAGS.get(kind, "")


# --- Kết quả --------------------------------------------------------------

## Thanh tra: kiểm kho, có đồ hết hạn là phạt + tịch thu.
func _inspect() -> void:
	var bad := GameState.expired_stock_count()
	if bad > 0:
		var fine := INSPECT_FINE_BASE + INSPECT_FINE_PER_ITEM * bad
		GameState.add_money(-fine, false)
		GameState.discard_expired_stock()
		GameState.lose_star(INSPECT_STAR_LOSS)
		notice("Thanh tra vệ sinh!", "Phát hiện %d món hết hạn trong kho.\nPhạt %s, tịch thu toàn bộ, trừ %s sao." % [
			bad, GameState.format_money(fine), _num(INSPECT_STAR_LOSS)], Color("c62828"))
	else:
		GameState.add_star(INSPECT_CLEAN_STAR)
		notice("Thanh tra vệ sinh!", "Kho sạch sẽ, không có đồ hết hạn.\nQuán được khen, +%s sao." % _num(INSPECT_CLEAN_STAR), Color("2e7d32"))


## Khách đặc biệt ăn xong (ok = phục vụ nhanh, món không hết hạn) hoặc bỏ về (ok = false).
## Trả về tiền thưởng thêm (đã cộng vào tiền).
func special_result(table: TableNode, ok: bool, price: int) -> void:
	match table.special:
		"critic":
			if ok:
				var bonus := roundi(price * CRITIC_TIP_BONUS / 1000.0) * 1000
				GameState.add_money(bonus)
				GameState.add_star(CRITIC_STAR_WIN)
				notice("Nhà phê bình hài lòng!", "Bài báo khen quán hết lời.\n+%s sao, tip thêm %s." % [_num(CRITIC_STAR_WIN), GameState.format_money(bonus)], Color("2e7d32"))
			else:
				GameState.lose_star(CRITIC_STAR_LOSE)
				notice("Nhà phê bình chê!", "Bài báo chê quán phục vụ kém.\nTrừ %s sao." % _num(CRITIC_STAR_LOSE), Color("c62828"))
		"michelin":
			if ok:
				GameState.add_money(MICHELIN_REWARD, false)
				GameState.add_star(MICHELIN_STAR_WIN)
				notice("Giám khảo Michelin!", "Vị khách lạ mặt là giám khảo Michelin.\nQuán được khen: +%s sao, thưởng %s." % [_num(MICHELIN_STAR_WIN), GameState.format_money(MICHELIN_REWARD)], Color("b8860b"))
			else:
				GameState.lose_star(MICHELIN_STAR_LOSE)
				notice("Giám khảo Michelin...", "Vị khách lạ mặt hóa ra là giám khảo Michelin.\nÔng không hài lòng: trừ %s sao." % _num(MICHELIN_STAR_LOSE), Color("c62828"))


# --- Thông báo ------------------------------------------------------------

## Bảng thông báo giữa màn hình, chạm "OK" để đóng (không dừng giờ).
func notice(title: String, text: String, color: Color) -> void:
	_log("[color=#%s]%s[/color] %s" % [color.to_html(false), title, text.replace("\n", " ")])
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f3e6c4")
	style.border_color = color
	style.set_border_width_all(5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", color)
	box.add_child(t)
	var body := Label.new()
	body.text = text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 0)
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color("3a2416"))
	box.add_child(body)
	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(200, 56)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_font_size_override("font_size", 22)
	ok.pressed.connect(layer.queue_free)
	box.add_child(ok)
	layer.modulate.a = 0.0
	_sell.add_child(layer)
	layer.create_tween().tween_property(layer, "modulate:a", 1.0, 0.2)


func _log(text: String) -> void:
	if _sell != null and _sell.has_method("log_line"):
		_sell.log_line(text)


static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".").replace(".", ",")
