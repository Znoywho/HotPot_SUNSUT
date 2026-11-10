extends Control
## Màn tổng kết cuối ngày dạng cuốn sổ, DayManager đặt đè lên màn bán đang tạm dừng.
## Phần giao diện nằm trong day_end.tscn; chữ mẫu trong scene được thay bằng số thật khi mở sổ.

const NEXT_SHOP_TEXT := "Đến cửa hàng »"
const NEXT_RESULT_TEXT := "Xem kết quả »"
const STAMP_PASS_TEXT := "ĐẠT KPI"
const STAMP_FAIL_TEXT := "TRƯỢT KPI"
const MESSAGE_PASS := "Quán vẫn sôi sùng sục, tiếp tục nào!"
const MESSAGE_FAIL := "Thiếu %s nữa là đạt KPI, quán đành đóng cửa."
const STAR_NOTE_PASS := "Bị trừ sao %d lần, ngày mai khách sẽ giảm."
const STAR_NOTE_FAIL := "Bị trừ sao %d lần trong ngày."
const MAX_STARS := 5
const FILL_FAIL := preload("res://assets/sprites/ui/book/bar_fill_fail.png") ## Thanh đỏ khi trượt, mặc định thanh xanh.
const MAX_BAR_PERCENT := 200.0 ## Vượt nhiều hơn mức này thì thanh không vẽ thêm, số % vẫn hiện đúng.
const STAMP_PASS_COLOR := Color("2e7d32")
const STAMP_FAIL_COLOR := Color("c62828")

# Tiêu đề
@onready var title_label: Label = %TitleLabel
# Trang trái: số liệu trong ngày
@onready var revenue_value: Label = %RevenueValue
@onready var kpi_value: Label = %KpiValue
@onready var kpi_bar: TextureProgressBar = %KpiBar
@onready var kpi_over_bar: TextureProgressBar = %KpiOverBar
@onready var kpi_percent: Label = %KpiPercent
@onready var difference_value: Label = %DifferenceValue
@onready var stars_value: Label = %StarsValue
@onready var star_note: Label = %StarNote
# Trang phải: kết quả
@onready var stamp_label: Label = %StampLabel
@onready var result_message: Label = %ResultMessage
@onready var next_kpi_row: Control = %NextKpiRow
@onready var next_kpi_value: Label = %NextKpiValue
@onready var money_value: Label = %MoneyValue
@onready var continue_button: Button = %ContinueButton
# Lớp phủ nhắc xoay ngang điện thoại
@onready var rotate_hint: Control = %RotateHint


## Khởi tạo màn hình: nối nút rồi đổ dữ liệu lên sổ.
func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	_show_day_summary()
	_show_result()


## Hiện lớp nhắc xoay ngang khi điện thoại đang cầm dọc.
func _process(_delta: float) -> void:
	var window_size := DisplayServer.window_get_size()
	rotate_hint.visible = window_size.y > window_size.x


## Điền trang trái: tiêu đề, doanh thu, KPI, thanh tiến độ, chênh lệch, sao.
func _show_day_summary() -> void:
	var revenue := GameState.today_revenue
	var target := GameState.kpi_target
	var percent := kpi_progress_percent(revenue, target)
	title_label.text = "Tổng kết ngày %d" % GameState.day
	revenue_value.text = GameState.format_money(revenue)
	kpi_value.text = GameState.format_money(target)
	_show_kpi_percent(percent)
	_update_kpi_bar(percent)
	difference_value.text = _signed_money(revenue - target)
	stars_value.text = "%s / %d" % [_stars_text(GameState.stars), MAX_STARS]
	_show_star_note()


## Hiện số lần bị trừ sao; không bị trừ thì ẩn hẳn dòng ghi chú.
func _show_star_note() -> void:
	var lost := GameState.stars_lost_today
	star_note.visible = lost > 0
	star_note.text = (STAR_NOTE_PASS if GameState.is_kpi_reached() else STAR_NOTE_FAIL) % lost


## Điền trang phải: con dấu, lời nhắn, KPI ngày mai, tiền hiện có, chữ trên nút.
func _show_result() -> void:
	money_value.text = GameState.format_money(GameState.money)
	if GameState.is_kpi_reached():
		_show_passed_result()
	else:
		_show_failed_result()


## Trang kết quả khi đạt KPI: dấu xanh, KPI ngày mai, nút sang cửa hàng.
func _show_passed_result() -> void:
	stamp_label.text = STAMP_PASS_TEXT
	stamp_label.modulate = STAMP_PASS_COLOR
	result_message.text = MESSAGE_PASS
	next_kpi_value.text = GameState.format_money(GameState.next_kpi())
	next_kpi_row.visible = true
	continue_button.text = NEXT_SHOP_TEXT


## Trang kết quả khi trượt KPI: thanh và dấu đỏ, số tiền còn thiếu, nút sang Game Over.
func _show_failed_result() -> void:
	kpi_bar.texture_progress = FILL_FAIL
	stamp_label.text = STAMP_FAIL_TEXT
	stamp_label.modulate = STAMP_FAIL_COLOR
	result_message.text = MESSAGE_FAIL % GameState.format_money(GameState.kpi_target - GameState.today_revenue)
	next_kpi_row.visible = false
	continue_button.text = NEXT_RESULT_TEXT


## Làm tròn xuống để chưa đạt KPI thì không bao giờ hiện "100%".
func _show_kpi_percent(percent: float) -> void:
	kpi_percent.text = "%d%%" % floori(percent)


## Chênh lệch có dấu: +250.000đ, -40.000đ, 0đ.
func _signed_money(value: int) -> String:
	return ("+" if value > 0 else "") + GameState.format_money(value)


## Số sao gọn và dùng dấu phẩy: 3.0 -> "3", 2.5 -> "2,5", 3.15 -> "3,15".
func _stars_text(value: float) -> String:
	var text := ("%.2f" % value).rstrip("0").rstrip(".")
	return text.replace(".", ",")


## Vẽ thanh KPI: dưới 100% tô một màu, trên 100% thêm đoạn vàng ở cuối thanh.
func _update_kpi_bar(percent: float) -> void:
	kpi_bar.value = minf(percent, 100.0)
	kpi_over_bar.value = overflow_share_percent(percent)


## Tiến độ KPI: percent = revenue / target × 100. KPI <= 0 thì coi như đã đạt đủ (100%).
static func kpi_progress_percent(revenue: int, target: int) -> float:
	if target <= 0:
		return 100.0
	return revenue / float(target) * 100.0


## Tỉ lệ đoạn vượt mức trên thanh: share = (p - 100) / p × 100, với p = min(percent, MAX_BAR_PERCENT).
## Không vượt KPI (percent <= 100) thì share = 0.
static func overflow_share_percent(percent: float) -> float:
	if percent <= 100.0:
		return 0.0
	var shown_percent := minf(percent, MAX_BAR_PERCENT)
	return (shown_percent - 100.0) / shown_percent * 100.0


## Chuyển sang màn tiếp theo khi bấm nút; khoá nút để bấm nhanh hai lần không bị nhảy qua cửa hàng.
func _on_continue_pressed() -> void:
	continue_button.disabled = true
	DayManager.next_phase()
