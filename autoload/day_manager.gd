extends Node
## Điều phối vòng lặp ngày (autoload: DayManager).
## Sáng: săn -> Trưa: nấu -> Chiều tối: bán -> Tổng kết KPI -> Cửa hàng nâng cấp -> ngày mới.
## Không đạt KPI -> Game Over.

signal phase_changed(phase: int)
signal phase_time_up

enum Phase { NONE, HUNT, COOK, SELL, DAY_END, SHOP, GAME_OVER }

## Một ngày chơi = 10 phút 15: săn 2:30 + sơ chế, nấu 4:30 + bán 3:15.
const HUNT_DURATION := 150.0 ## Sáng đi săn: 2:30.
const COOK_DURATION := 270.0 ## Trưa sơ chế + nấu nước cốt: 4:30 (sơ chế nhiều bước + nấu, 2:30 làm không kịp).
const SELL_DURATION := 195.0 ## Chiều tối bán hàng: 3:15.

const SCENES := {
	Phase.HUNT: "res://scenes/hunt/hunt_phase.tscn",
	Phase.COOK: "res://scenes/cook/cook_phase.tscn",
	Phase.SELL: "res://scenes/sell/sell_phase.tscn",
	Phase.DAY_END: "res://scenes/day_end/day_end.tscn",
	Phase.SHOP: "res://scenes/shop/shop.tscn",
	Phase.GAME_OVER: "res://scenes/game_over/game_over.tscn",
}
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const DAY_END_LAYER := 100 ## Sổ tổng kết nằm trên mọi giao diện khác, kể cả HUD.
const HUD_SCENE := preload("res://scenes/common/hud.tscn")
const HUD_SCRIPT := preload("res://scenes/common/hud.gd")
const PHASES_WITH_HUD: Array[Phase] = [Phase.HUNT, Phase.COOK, Phase.SELL, Phase.DAY_END, Phase.SHOP]
## Các màn đã tự chừa chỗ phía trên cho HUD; màn còn lại được DayManager đẩy xuống dưới thanh HUD.
const PHASES_RESERVING_HUD_SPACE: Array[Phase] = [Phase.COOK, Phase.SELL]
const PHASE_DURATIONS := {Phase.HUNT: HUNT_DURATION, Phase.COOK: COOK_DURATION, Phase.SELL: SELL_DURATION}

# --- Chuyển cảnh giữa các buổi (S16) ---
const TRANSITION_LAYER := 50 ## Trên màn chơi, dưới HUD để vẫn thấy đồng hồ mặt trời trượt sang buổi mới.
const HUD_LAYER := 60 ## Dưới sổ tổng kết (DAY_END_LAYER) và menu tạm dừng.
const FADE_OUT_SECONDS := 0.3
const CARD_SECONDS := 0.8 ## Thẻ tên buổi hiện giữa màn tối.
const FADE_IN_SECONDS := 0.35
const COVER_COLOR := Color("1a0f0b")
const MENU_FLASH_COLOR := Color("fff4d6") ## Khớp FLASH_COLOR của menu chính: menu kết thúc bằng màn sáng phủ kín.
const CARD_TITLE_COLOR := Color("ffd36b")
const CARD_SUBTITLE_COLOR := Color("fbe9d0")

var current_phase: Phase = Phase.NONE
var time_left := 0.0
var timer_running := false
var _hud: CanvasLayer ## Một HUD duy nhất sống qua các màn để đồng hồ mặt trời trượt mượt khi đổi giai đoạn.
var _cover: ColorRect ## Màn che khi chuyển buổi (chặn bấm trong lúc chuyển).
var _card: VBoxContainer ## Thẻ tên buổi giữa màn che.
var _card_title: Label
var _card_subtitle: Label
var _transitioning := false


## Tạo HUD (ẩn sẵn) và theo dõi việc đổi màn để đặt màn mới nằm dưới thanh HUD.
func _ready() -> void:
	_hud = HUD_SCENE.instantiate()
	_hud.visible = false
	_hud.layer = HUD_LAYER
	add_child(_hud)
	_build_transition()
	get_tree().scene_changed.connect(_fit_current_scene_below_hud)
	GameMusic.ensure(get_tree()) # Nhạc nền theo buổi (assets/audio/game_music.gd).


func _process(delta: float) -> void:
	if not timer_running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		timer_running = false
		phase_time_up.emit()


## Chơi mới: mở cửa hàng trước để tiêu tiền khởi nghiệp chuẩn bị ngày 1, rồi mới đi săn.
## Lưu ngay để lần chơi mới thay hẳn save cũ: "Tiếp tục" không mở lại lần chơi đã bỏ.
func start_new_game() -> void:
	GameState.reset_new_game()
	SaveManager.save_game()
	go_to(Phase.SHOP)


## Tiếp tục từ file save (save được ghi lúc vào cửa hàng nâng cấp).
## Save hỏng thì xoá rồi về menu (nút "Tiếp tục" bị khoá) thay vì kẹt ở màn sáng của menu.
func continue_game() -> void:
	if SaveManager.load_game():
		go_to(Phase.SHOP)
	else:
		SaveManager.delete_save()
		go_to_main_menu()


func start_day() -> void:
	go_to(Phase.HUNT)


## Chuyển sang giai đoạn kế tiếp trong ngày.
func next_phase() -> void:
	match current_phase:
		Phase.HUNT:
			go_to(Phase.COOK)
		Phase.COOK:
			go_to(Phase.SELL)
		Phase.SELL:
			go_to(Phase.DAY_END)
		Phase.DAY_END:
			if GameState.is_kpi_reached():
				GameState.advance_to_next_day()
				SaveManager.save_game()
				go_to(Phase.SHOP)
			else:
				SaveManager.delete_save()
				go_to(Phase.GAME_OVER)
		Phase.SHOP:
			start_day()
		_:
			push_warning("next_phase() được gọi ở phase %s" % Phase.keys()[current_phase])


## Sang giai đoạn mới. Sổ tổng kết hiện đè ngay lên màn đang chơi; các giai đoạn khác có chuyển cảnh:
## màn tối dần -> đổi màn + thẻ tên buổi -> sáng dần, rồi đồng hồ buổi mới bắt đầu chạy (không mất giây nào).
func go_to(phase: Phase) -> void:
	if _transitioning:
		return
	var from_menu := current_phase == Phase.NONE
	current_phase = phase
	timer_running = false
	# Đặt giờ buổi mới ngay khi đổi buổi: HUD / ánh sáng tính giờ theo current_phase + time_left, nếu để
	# time_left của buổi cũ trong lúc tối màn thì đồng hồ vọt quá giờ rồi tụt lại (vd săn 11h -> 11h30 -> 11h).
	time_left = PHASE_DURATIONS.get(phase, 0.0)
	if phase == Phase.DAY_END:
		get_tree().paused = false
		_update_hud_visibility()
		_show_day_end_over_current_scene()
		phase_changed.emit(phase)
		return
	_transitioning = true
	await _cover_screen(from_menu)
	get_tree().paused = false # bỏ tạm dừng (sổ tổng kết, menu tạm dừng) ngay lúc đổi màn, sau khi đã che kín
	_update_hud_visibility()
	get_tree().change_scene_to_file(SCENES[phase])
	phase_changed.emit(phase)
	if not from_menu:
		await _show_card(phase)
	await _uncover_screen()
	_transitioning = false
	timer_running = PHASE_DURATIONS.has(phase) and current_phase == phase
	# Lần đầu vào buổi này: bảng "Cách chơi" tạm dừng game (đồng hồ đứng yên) tới khi bấm "Đã hiểu".
	if current_phase == phase and HowToPlay.should_show(phase):
		get_tree().root.add_child(HowToPlay.new(phase))


func go_to_main_menu() -> void:
	current_phase = Phase.NONE
	timer_running = false
	_update_hud_visibility()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Đặt sổ tổng kết đè lên màn hiện tại và tạm dừng màn đó.
## Sổ là con của màn hiện tại nên tự biến mất khi go_to() đổi sang màn tiếp theo.
func _show_day_end_over_current_scene() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		get_tree().change_scene_to_file(SCENES[Phase.DAY_END])
		return
	var layer := CanvasLayer.new()
	layer.layer = DAY_END_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(load(SCENES[Phase.DAY_END]).instantiate())
	current_scene.add_child(layer)
	get_tree().paused = true


func time_left_text() -> String:
	var seconds := ceili(time_left)
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Chỉ hiện HUD ở các giai đoạn trong ngày chơi (ẩn ở menu chính và Game Over).
func _update_hud_visibility() -> void:
	_hud.visible = current_phase in PHASES_WITH_HUD


## Đẩy màn vừa mở xuống dưới thanh HUD nếu màn đó chưa tự chừa chỗ.
func _fit_current_scene_below_hud() -> void:
	var scene := get_tree().current_scene as Control
	if scene != null and _hud.visible and current_phase not in PHASES_RESERVING_HUD_SPACE:
		scene.offset_top = HUD_SCRIPT.HEIGHT


# --- Chuyển cảnh ---------------------------------------------------------------

## Dựng sẵn màn che + thẻ tên buổi (ẩn), chạy cả khi game đang tạm dừng.
func _build_transition() -> void:
	var layer := CanvasLayer.new()
	layer.layer = TRANSITION_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.color = COVER_COLOR
	_cover.visible = false
	layer.add_child(_cover)
	_card = VBoxContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 8)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(_card)
	_card_title = _make_card_label(56, CARD_TITLE_COLOR)
	_card_subtitle = _make_card_label(28, CARD_SUBTITLE_COLOR)
	_card.add_child(_card_title)
	_card.add_child(_card_subtitle)


## Một dòng chữ căn giữa có viền tối cho thẻ tên buổi.
func _make_card_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", PixelButton.outline_for(font_size))
	return label


## Che màn: tối dần. Từ menu chính thì menu đã tự phủ sáng kín màn, nên che ngay bằng đúng màu đó.
func _cover_screen(from_menu: bool) -> void:
	_card.modulate.a = 0.0
	_cover.visible = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	if from_menu:
		_cover.color = MENU_FLASH_COLOR
		return
	_cover.color = Color(COVER_COLOR, 0.0)
	var tween := _cover.create_tween()
	tween.tween_property(_cover, "color:a", 1.0, FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Thẻ tên buổi (vd "NGÀY 8 · SÁNG / Đi săn nguyên liệu") hiện dần rồi mờ đi trên màn tối.
func _show_card(phase: Phase) -> void:
	var text := _card_text(phase)
	if text[0] == "":
		return
	_card_title.text = text[0]
	_card_subtitle.text = text[1]
	var tween := _card.create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, CARD_SECONDS * 0.25)
	tween.tween_interval(CARD_SECONDS * 0.5)
	tween.tween_property(_card, "modulate:a", 0.0, CARD_SECONDS * 0.25)
	await tween.finished


## [dòng lớn, dòng nhỏ] của thẻ tên buổi; dòng rỗng = không hiện thẻ.
func _card_text(phase: Phase) -> Array[String]:
	match phase:
		Phase.HUNT:
			return ["NGÀY %d · SÁNG" % GameState.day, "Đi săn nguyên liệu"]
		Phase.COOK:
			return ["TRƯA", "Sơ chế và nấu lẩu"]
		Phase.SELL:
			return ["CHIỀU TỐI", "Mở quán bán hàng"]
		Phase.SHOP:
			return ["CỬA HÀNG NÂNG CẤP", "Chuẩn bị ngày %d" % GameState.day]
	return ["", ""] # Game Over đã có tiêu đề "Quán đóng cửa" riêng: chỉ mờ, không thẻ


## Mở màn: màn mới sáng dần rồi ẩn màn che, trả lại thao tác.
func _uncover_screen() -> void:
	var tween := _cover.create_tween()
	tween.tween_property(_cover, "color:a", 0.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_cover.visible = false
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
