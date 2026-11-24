extends SceneTree
## Chụp ảnh minh hoạ cho bảng Cách chơi (scenes/common/how_to_play.gd) từ game thật.
## Chạy (dùng thư mục dữ liệu riêng để không đụng save / settings thật):
##   XDG_DATA_HOME=/tmp/hotpot_shots godot --path . -s tools/capture_tutorial_shots.gd
## Kết quả: assets/sprites/ui/tutorial/<tên>.webp (640x360) và in ra dòng `"<tên>": Rect2(...)` của khung chỉ
## (tỉ lệ 0..1 trên ảnh) -> dán vào FOCUS trong how_to_play.gd. Sau đó chạy `godot --headless --path . --import`.
## Ảnh mới thì đặt import Lossy 0.8 (compress/mode=1 trong .import) như các ảnh có sẵn: lossless làm bản web nặng gấp 5.
## Khi màn săn / nấu / bán / cửa hàng đổi giao diện thì chạy lại script này.
## Không chạy được --headless (cần vẽ thật để chụp). Trên niri cửa sổ bị ép dọc nên ép khung hình 1280x720 (KEEP).

const OUT_DIR := "res://assets/sprites/ui/tutorial/"
const BASE := Vector2(1280, 720) ## Kích thước khung game gốc; rect của Control tính theo khung này.
const SHOT_SIZE := Vector2i(640, 360)
const WEBP_QUALITY := 0.8

var _dm: Node
var _gs: Node
var _focus_lines: Array[String] = []


## Dựng màn chính, ép khung hình ngang rồi chạy kịch bản chụp.
func _initialize() -> void:
	root.content_scale_size = Vector2i(BASE)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")
	_run.call_deferred()


## Mỗi khung hình: giấu lớp "Xoay ngang điện thoại" (đọc kích thước cửa sổ thật nên vẫn hiện trên máy này).
func _process(_delta: float) -> bool:
	for label in root.find_children("*", "Label", true, false):
		if label.text.begins_with("Xoay ngang") and label.get_parent() is CanvasItem:
			label.get_parent().modulate.a = 0.0 # màn săn tự bật lại `visible` mỗi khung, nên làm trong suốt
	return false


## Kịch bản: đi lần lượt săn -> nấu -> bán -> cửa hàng, dựng đúng trạng thái rồi chụp từng thẻ.
func _run() -> void:
	await _wait(1.0)
	_dm = root.get_node("DayManager")
	_gs = root.get_node("GameState")
	var how_to_play: Script = load("res://scenes/common/how_to_play.gd")
	for phase in how_to_play.PAGES:
		how_to_play.mark_seen(phase) # để bảng Cách chơi không che ảnh
	_gs.reset_new_game()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	await _capture_hunt()
	await _capture_cook()
	await _capture_sell()
	await _capture_shop()

	print("\n# Dán vào FOCUS trong scenes/common/how_to_play.gd:")
	for line in _focus_lines:
		print(line)
	quit()


## Săn: bản đồ bụi cỏ, công thức cần, nút về bếp; rồi vào một trận để chụp chọn quái + chiêu.
func _capture_hunt() -> void:
	await _go(1) # DayManager.Phase.HUNT
	var hunt: Node = current_scene
	await _shot("hunt_bush", [hunt._cards_box.get_child(0)])
	await _shot("hunt_recipe", _recipe_labels(hunt))
	await _shot("hunt_back", [_button_starting(hunt, "Về bếp nấu lẩu")])
	hunt._start_fight(0)
	var battle: Node = hunt._battle
	var waited := 0.0
	while not battle._waiting_input and waited < 20.0: # chờ màn chào trận + tới lượt mình
		await _wait(0.25)
		waited += 0.25
	await _wait(0.4)
	await _shot("hunt_target", [battle._enemies_box.get_child(0)])
	await _shot("hunt_skills", battle._skill_buttons)


## Nấu: nút sơ chế, bếp, tủ lạnh, nút mở quán; rồi mở bảng sơ chế và bắt đầu một lượt để chụp vùng làm bước.
func _capture_cook() -> void:
	for id in ["tomato", "beef", "mushroom", "enoki"]:
		_gs.add_item(id, 6)
	await _go(2) # DayManager.Phase.COOK
	var cook: Node = current_scene
	await _shot("cook_prep", [_button_starting(cook, "Sơ chế nguyên liệu")])
	await _shot("cook_stove", [cook._stoves[0]])
	await _shot("cook_fridge", [cook._fridge])
	await _shot("cook_open", [_button_starting(cook, "Mở quán bán hàng")])
	cook._open_prep("tomato")
	await _wait(0.8)
	var panel: Node = cook._prep_panel
	panel._start_session("tomato")
	await _wait(1.2)
	await _shot("cook_steps", [panel._host, panel._meter])


## Bán: bảng khách chờ, bàn trống, bàn đã gọi món, chỗ bẩn trên sàn, sao trên HUD.
func _capture_sell() -> void:
	_gs.add_broth("tomato_broth", 6)
	_gs.add_broth("mushroom_broth", 6)
	await _go(3) # DayManager.Phase.SELL
	var sell: Node = current_scene
	for i in 3:
		sell._try_spawn_group()
	await _wait(2.5) # khách đi từ cửa vào hàng chờ
	await _shot("sell_queue", [sell._board])
	await _shot("sell_table", [sell._visuals[0]])
	await sell._seat_at(sell.tables[0])
	await _wait(1.0)
	await _shot("sell_serve", [sell._visuals[0]])
	sell._spawn_mess("trash", Vector2(560, 560))
	await _wait(0.6)
	await _shot("sell_mess", [sell._mess[-1]])
	await _shot("sell_stars", _hud()._stars)


## Cửa hàng: ô KPI trên HUD, hai nhóm tab, nút Mua đầu tiên, nút bắt đầu ngày.
func _capture_shop() -> void:
	await _go(5) # DayManager.Phase.SHOP
	var shop: Node = current_scene
	await _wait(0.6)
	await _shot("shop_kpi", [_hud()._kpi_bar.get_parent()])
	await _shot("shop_tabs", shop._group_buttons)
	await _shot("shop_buy", [_button_starting(shop, "MUA")])
	await _shot("shop_start", [_button_starting(shop, "BẮT ĐẦU NGÀY")])


## Sang buổi `phase` (số của DayManager.Phase) rồi chờ chuyển cảnh xong.
func _go(phase: int) -> void:
	_dm.go_to(phase)
	await _wait(0.5)
	while _dm._transitioning:
		await _wait(0.2)
	await _wait(1.2)


## Chụp màn hiện tại thành <name>.webp (640x360) và ghi lại khung chỉ = hình chữ nhật bao các node `targets`.
func _shot(name: String, targets: Array) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(SHOT_SIZE.x, SHOT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_webp(ProjectSettings.globalize_path(OUT_DIR + name + ".webp"), true, WEBP_QUALITY)
	var box := Rect2()
	for target in targets:
		if target == null or not target is Control:
			push_warning("Ảnh %s: thiếu node để đóng khung" % name)
			continue
		var rect: Rect2 = target.get_global_rect()
		box = rect if box.size == Vector2.ZERO else box.merge(rect)
	var f := Rect2(box.position / BASE, box.size / BASE)
	_focus_lines.append('\t"%s": Rect2(%.3f, %.3f, %.3f, %.3f),' % [name, f.position.x, f.position.y, f.size.x, f.size.y])
	print("chụp ", name)


## Nút đầu tiên (Button) trong `node` có chữ bắt đầu bằng `prefix`.
func _button_starting(node: Node, prefix: String) -> Control:
	for b in node.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


## Nhãn "Công thức hôm nay cần" ở cột trái màn săn và các dòng công thức bên dưới nó.
func _recipe_labels(hunt: Node) -> Array:
	var result: Array = []
	for child in hunt._status_box.get_children():
		if not result.is_empty() or (child is Label and child.text.begins_with("Công thức")):
			result.append(child)
	return result


## HUD dùng chung (DayManager giữ một HUD duy nhất).
func _hud() -> Node:
	return _dm._hud


## Chờ `sec` giây (chạy cả khi game tạm dừng).
func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
