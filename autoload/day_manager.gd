extends Node
## Điều phối vòng lặp ngày (autoload: DayManager).
## Sáng: săn -> Trưa: nấu -> Chiều tối: bán -> Tổng kết KPI -> Cửa hàng nâng cấp -> ngày mới.
## Không đạt KPI -> Game Over.

signal phase_changed(phase: int)
signal phase_time_up

enum Phase { NONE, HUNT, COOK, SELL, DAY_END, SHOP, GAME_OVER }

## Một ngày chơi = 7 phút: săn 2:30 + nấu 1:15 + bán 3:15.
const HUNT_DURATION := 150.0 ## Sáng đi săn: 2:30.
const COOK_DURATION := 75.0 ## Trưa nấu nước cốt: 1:15.
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

var current_phase: Phase = Phase.NONE
var time_left := 0.0
var timer_running := false


func _process(delta: float) -> void:
	if not timer_running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		timer_running = false
		phase_time_up.emit()


func start_new_game() -> void:
	GameState.reset_new_game()
	start_day()


## Tiếp tục từ file save (save được ghi lúc vào cửa hàng nâng cấp).
func continue_game() -> void:
	if SaveManager.load_game():
		go_to(Phase.SHOP)


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


func go_to(phase: Phase) -> void:
	current_phase = phase
	timer_running = false
	match phase:
		Phase.HUNT:
			_start_timer(HUNT_DURATION)
		Phase.COOK:
			_start_timer(COOK_DURATION)
		Phase.SELL:
			_start_timer(SELL_DURATION)
	get_tree().change_scene_to_file(SCENES[phase])
	phase_changed.emit(phase)


func go_to_main_menu() -> void:
	current_phase = Phase.NONE
	timer_running = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func time_left_text() -> String:
	var seconds := ceili(time_left)
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _start_timer(duration: float) -> void:
	time_left = duration
	timer_running = true
