extends Control
## Màn tổng kết cuối ngày dạng cuốn sổ.
## Phần giao diện nằm trong day_end.tscn. Chữ đang hiện là SỐ MẪU để xem bố cục.
## TODO(Hạo): viết logic vào các hàm bên dưới, mỗi node đã có sẵn tên %... để gọi.

const NEXT_SHOP_TEXT := "Đến cửa hàng »"
const NEXT_RESULT_TEXT := "Xem kết quả »"
const BAR_FAIL_VARIATION := &"KpiBarFail" ## Thanh đỏ khi trượt, mặc định thanh xanh (giống thanh máu).
const STAMP_PASS_COLOR := Color("2e7d32")
const STAMP_FAIL_COLOR := Color("c62828")

# Tiêu đề
@onready var title_label: Label = %TitleLabel
# Trang trái: số liệu trong ngày
@onready var revenue_value: Label = %RevenueValue
@onready var kpi_value: Label = %KpiValue
@onready var kpi_bar: ProgressBar = %KpiBar
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
	# TODO(Hạo): lấy số từ GameState (day, today_revenue, kpi_target, stars, stars_lost_today).
	# Tiền hiển thị bằng GameState.format_money().
	# Không bị trừ sao thì ẩn star_note để khỏi còn viên thuốc trống.
	pass


## Điền trang phải: con dấu, lời nhắn, KPI ngày mai, tiền hiện có, chữ trên nút.
func _show_result() -> void:
	# TODO(Hạo): rẽ nhánh theo GameState.is_kpi_reached().
	# Đạt: stamp_label.modulate = STAMP_PASS_COLOR,
	#       nút hiện NEXT_SHOP_TEXT, KPI ngày mai lấy từ GameState.next_kpi().
	# Trượt: kpi_bar.theme_type_variation = BAR_FAIL_VARIATION, STAMP_FAIL_COLOR,
	#       NEXT_RESULT_TEXT, ẩn next_kpi_row (ẩn cả viên thuốc KPI ngày mai).
	pass


## Chuyển sang màn tiếp theo khi bấm nút.
func _on_continue_pressed() -> void:
	# TODO(Hạo): gọi DayManager.next_phase(). Chưa có dòng này thì game dừng ở màn này.
	pass
