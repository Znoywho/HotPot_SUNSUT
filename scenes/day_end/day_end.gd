extends Control
## Màn tổng kết cuối ngày dạng cuốn sổ, DayManager đặt đè lên màn bán đang tạm dừng.
## Phần giao diện nằm trong day_end.tscn; chữ mẫu trong scene được thay bằng số thật khi mở sổ.

const NEXT_SHOP_TEXT := "Đến cửa hàng »"
const NEXT_RESULT_TEXT := "Xem kết quả »"
const STAMP_PASS_TEXT := "ĐẠT KPI"
const STAMP_FAIL_TEXT := "TRƯỢT KPI"
const STAMP_TUTORIAL_TEXT := "XONG" ## Ngày 0 hướng dẫn không có KPI.
const MESSAGE_PASS := "Quán vẫn sôi sùng sục, tiếp tục nào!"
const MESSAGE_FAIL := "Thiếu %s nữa là đạt KPI, quán đành đóng cửa."
const STAR_NOTE_PASS := "Bị trừ sao %d lần, ngày mai khách sẽ giảm."
const STAR_NOTE_FAIL := "Bị trừ sao %d lần trong ngày."
const MAX_STARS := 5
const FILL_FAIL := preload("res://assets/sprites/ui/book/bar_fill_fail.png") ## Thanh đỏ khi trượt, mặc định thanh xanh.
const MAX_BAR_PERCENT := 200.0 ## Vượt nhiều hơn mức này thì thanh không vẽ thêm, số % vẫn hiện đúng.
const STAMP_PASS_COLOR := Color("2e7d32")
const STAMP_FAIL_COLOR := Color("c62828")
const MESSAGE_TUTORIAL := "Xong ngày hướng dẫn! Nhận vốn khởi nghiệp %s."
const MESSAGE_RECORD := "Phá kỷ lục cũ %d ngày, quá đỉnh!"
# Nhịp mở sổ: đếm doanh thu -> đập dấu -> hiện lời nhắn, nút.
const COUNT_SECONDS := 0.9
const STAMP_SECONDS := 0.16
const STAMP_FROM_SCALE := 2.4 ## Con dấu bắt đầu to chừng này lần rồi đập xuống cỡ thật.
const FADE_SECONDS := 0.25
const SKIP_GUARD_MS := 300 ## Sau khi chạm bỏ qua hiệu ứng, chặn chạm chừng này ms để không bấm luôn nút.
# Ảnh pixel theo kết quả (tools/make_result_art.py): trượt thì nồi lẩu nguội, đạt thì pháo hoa sau cuốn sổ.
const COLD_POT := preload("res://assets/sprites/ui/result/cold_pot.png")
const FIREWORK := preload("res://assets/sprites/ui/result/firework.png")
const FIREWORK_FRAMES := 7
const FIREWORK_SECONDS := 0.7
const FIREWORK_COLORS: Array[Color] = [Color("ffd34e"), Color("ff6b5a"), Color("8fe388"), Color("ffb3d9"), Color("9fd8ff")]

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
@onready var book: Control = $Center/Book
@onready var money_row: Control = $Center/Book/RightPage/Margin/Content/MoneyRow
@onready var hotpot: TextureRect = $Center/Book/LeftPage/Hotpot
# Lớp phủ nhắc xoay ngang điện thoại
@onready var rotate_hint: Control = %RotateHint

var _reveal: Tween ## Hiệu ứng mở sổ; chạm khi đang chạy thì nhảy tới cuối.
var _unlock_ms := 0 ## Chặn chạm tới mốc này (ms).
var _fireworks: Control ## Lớp pháo hoa nằm giữa nền tối và cuốn sổ.
var _firework_timer: Timer


## Khởi tạo màn hình: nối nút, đổ dữ liệu lên sổ rồi mở sổ có nhịp.
func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	# Con dấu ĐẠT KPI / TRƯỢT KPI: font pixel chung (chữ trắng, nhuộm xanh / đỏ bằng modulate như cũ).
	PixelTitle.style(stamp_label, stamp_label.get_theme_font_size("font_size"))
	_show_day_summary()
	_show_result()
	_play_reveal()


## Mở sổ có nhịp: doanh thu đếm từ 0 lên cùng thanh KPI, con dấu ĐẠT / TRƯỢT đập xuống (sổ rung),
## rồi lời nhắn, các dòng bên phải và nút hiện dần. Nút chỉ bấm được khi đã hiện.
func _play_reveal() -> void:
	var late: Array[Control] = [result_message, next_kpi_row, money_row, continue_button]
	for item in late:
		item.modulate.a = 0.0
	stamp_label.modulate.a = 0.0 # giữ màu xanh/đỏ, chỉ ẩn (tâm xoay/phóng đặt sẵn trong scene)
	continue_button.mouse_filter = MOUSE_FILTER_IGNORE
	_show_progress(0.0)
	_reveal = create_tween()
	_reveal.tween_method(_show_progress, 0.0, float(GameState.today_revenue), COUNT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(stamp_label, "modulate:a", 1.0, STAMP_SECONDS)
	_reveal.parallel().tween_property(stamp_label, "scale", Vector2.ONE, STAMP_SECONDS) \
			.from(Vector2.ONE * STAMP_FROM_SCALE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reveal.tween_callback(_on_stamp_landed)
	for i in late.size():
		if i > 0:
			_reveal.parallel()
		_reveal.tween_property(late[i], "modulate:a", 1.0, FADE_SECONDS).set_delay(0.1 + i * 0.12)
	_reveal.tween_callback(func(): continue_button.mouse_filter = MOUSE_FILTER_STOP)


## Một khung của đoạn đếm: doanh thu đang hiện, % và thanh KPI theo đúng số đó.
func _show_progress(shown_revenue: float) -> void:
	var shown := roundi(shown_revenue)
	revenue_value.text = GameState.format_money(shown)
	var percent := kpi_progress_percent(shown, GameState.kpi_target)
	_show_kpi_percent(percent)
	_update_kpi_bar(percent)


## Con dấu chạm sổ: tiếng đập + sổ rung nhẹ; đạt KPI thì bắt đầu bắn pháo hoa.
func _on_stamp_landed() -> void:
	Sfx.play(self, Sfx.HIT)
	ParticleBurst.play(self, ParticleBurst.DUST, stamp_label.get_global_rect().get_center())
	var origin := book.position
	var shake := book.create_tween()
	for offset in [Vector2(6, 3), Vector2(-5, -2), Vector2(3, 1), Vector2.ZERO]:
		shake.tween_property(book, "position", origin + offset, 0.04)
	if GameState.is_kpi_reached():
		_start_fireworks()


## Pháo hoa bắn liên tục hai bên cuốn sổ (sau sổ, trên nền tối) tới khi đóng sổ.
func _start_fireworks() -> void:
	_fireworks = Control.new()
	_fireworks.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_fireworks.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_fireworks)
	move_child(_fireworks, 1) # ngay trên Backdrop, dưới cuốn sổ
	_firework_timer = Timer.new()
	_firework_timer.one_shot = true
	_firework_timer.timeout.connect(_launch_firework)
	_fireworks.add_child(_firework_timer)
	_launch_firework()
	_launch_firework()


## Một chùm pháo hoa màu ngẫu nhiên ở khoảng trống trái hoặc phải cuốn sổ: nở hết dải khung rồi tự xoá, hẹn chùm sau.
func _launch_firework() -> void:
	var screen := get_viewport_rect().size
	var book_rect := book.get_global_rect()
	var sprite := Sprite2D.new()
	sprite.texture = FIREWORK
	sprite.hframes = FIREWORK_FRAMES
	sprite.modulate = FIREWORK_COLORS.pick_random()
	var x := randf_range(0.0, book_rect.position.x) if randf() < 0.5 else randf_range(book_rect.end.x, screen.x)
	sprite.position = Vector2(x, randf_range(FIREWORK.get_height() * 0.5, screen.y * 0.6)).round()
	_fireworks.add_child(sprite)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "frame", FIREWORK_FRAMES - 1, FIREWORK_SECONDS).from(0)
	tween.tween_callback(sprite.queue_free)
	_firework_timer.start(randf_range(0.25, 0.6))


## Chạm trong lúc sổ đang mở: nhảy tới cuối, không bắt người chơi chờ.
## Chặn thêm một nhịp ngắn vì trên điện thoại một lần chạm sinh cả sự kiện chạm lẫn sự kiện chuột giả lập.
func _input(event: InputEvent) -> void:
	var press := (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if not press:
		return
	if _reveal != null and _reveal.is_running():
		_reveal.custom_step(60.0)
		_unlock_ms = Time.get_ticks_msec() + SKIP_GUARD_MS
	if Time.get_ticks_msec() < _unlock_ms:
		get_viewport().set_input_as_handled()


## Hiện lớp nhắc xoay ngang khi điện thoại đang cầm dọc.
func _process(_delta: float) -> void:
	var window_size := DisplayServer.window_get_size()
	rotate_hint.visible = window_size.y > window_size.x


## Điền trang trái: tiêu đề, doanh thu, KPI, thanh tiến độ, chênh lệch, sao.
func _show_day_summary() -> void:
	var revenue := GameState.today_revenue
	var target := GameState.kpi_target
	var percent := kpi_progress_percent(revenue, target)
	title_label.text = "Tổng kết ngày %d" % GameState.shown_day()
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
	# Ngày 0: tiền bán thử được thay bằng vốn khởi nghiệp khi sang cửa hàng (GameState._finish_tutorial).
	money_value.text = GameState.format_money(GameState.START_MONEY if GameState.in_tutorial else GameState.money)
	if GameState.is_kpi_reached():
		_show_passed_result()
	else:
		_show_failed_result()


## Trang kết quả khi đạt KPI: dấu xanh, KPI ngày mai, nút sang cửa hàng.
func _show_passed_result() -> void:
	stamp_label.text = STAMP_PASS_TEXT
	stamp_label.modulate = STAMP_PASS_COLOR
	result_message.text = MESSAGE_PASS
	# Hôm nay vừa vượt kỷ lục của các lần chơi trước (kỷ lục chỉ ghi khi Game Over).
	var best := BestRecord.best_days()
	if best > 0 and GameState.day == best + 1:
		result_message.text = MESSAGE_RECORD % best
	if GameState.in_tutorial:
		stamp_label.text = STAMP_TUTORIAL_TEXT
		result_message.text = MESSAGE_TUTORIAL % GameState.format_money(GameState.START_MONEY)
	next_kpi_value.text = GameState.format_money(GameState.next_kpi())
	next_kpi_row.visible = true
	continue_button.text = NEXT_SHOP_TEXT


## Trang kết quả khi trượt KPI: thanh và dấu đỏ, số tiền còn thiếu, nút sang Game Over.
func _show_failed_result() -> void:
	kpi_bar.texture_progress = FILL_FAIL
	hotpot.texture = COLD_POT
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
