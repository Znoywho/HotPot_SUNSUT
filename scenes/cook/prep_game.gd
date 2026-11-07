class_name PrepGame
extends Control
## Khung chung cho 1 trò sơ chế: làm `units` phần nguyên liệu `item_id` bằng chạm / vuốt / kéo / giữ.
## Mỗi phần xong phát unit_done (bảng sơ chế trừ kho thô, cộng kho đã sơ chế), xong hết phát all_done.
## Thao tác dùng sự kiện chuột trái; trên điện thoại chạm được giả lập thành chuột nên dùng ngón tay được.

signal unit_done
signal all_done

const KIT := "res://assets/sprites/kitchen/"
const SFX := "res://assets/audio/sfx/"
const AREA := Vector2(780, 300)

var item_id := ""
var units := 1
var done := 0
var cfg: KitchenConfig
var _finished := false


func begin(id: String, n: int, config: KitchenConfig) -> void:
	item_id = id
	units = maxi(1, n)
	done = 0
	cfg = config
	custom_minimum_size = AREA
	size = AREA
	mouse_filter = MOUSE_FILTER_STOP
	_build()


# --- Màn con override ------------------------------------------------------

func title() -> String:
	return "SƠ CHẾ " + item_name().to_upper()


func hint() -> String:
	return ""


## Tiến độ phần đang làm dở (0..1).
func partial() -> float:
	return 0.0


func status_text() -> String:
	return "Tiến độ: %d%% · Xong %d/%d phần" % [roundi(progress() * 100.0), done, units]


func _build() -> void:
	pass


# --- Chung -------------------------------------------------------------------

func progress() -> float:
	return clampf((float(done) + partial()) / float(units), 0.0, 1.0)


func item_name() -> String:
	return GameState.item_display_name(item_id)


func base_id() -> String:
	return item_id.trim_prefix(GameState.GOLDEN_PREFIX)


func is_finished() -> bool:
	return _finished


## Dừng sớm (vd phụ bếp đã lấy hết nguyên liệu thô).
func stop() -> void:
	_finished = true


func _finish_unit() -> void:
	if _finished:
		return
	done += 1
	unit_done.emit()
	if done >= units:
		_finished = true
		all_done.emit()


func kit(name: String) -> Texture2D:
	return load(KIT + name + ".png")


func icon() -> Texture2D:
	return HuntUI.ingredient_texture(item_id)


## Ảnh "bẩn" của nguyên liệu (cho trò rửa / nhặt), không có thì dùng ảnh thường.
func dirty_icon() -> Texture2D:
	var path := KIT + base_id() + "_dirty.png"
	return load(path) if ResourceLoader.exists(path) else icon()


func sprite(tex: Texture2D, scale: float, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = tex.get_size() * scale
	r.position = pos
	r.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func caption(text: String, pos: Vector2, size_px := 18, color := HuntUI.INK) -> Label:
	var l := HuntUI.label(text, size_px, color)
	l.position = pos
	l.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Chữ nổi kiểu truyện tranh ("Chặt!", "Xoẹt!").
func pop_text(text: String, at: Vector2, color := Color.WHITE, size_px := 26) -> void:
	var l := HuntUI.outlined_label(text, size_px, color)
	l.position = at
	l.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(l)
	l.pivot_offset = Vector2(30, 16)
	l.scale = Vector2(0.6, 0.6)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", at.y - 34, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)


## Văng vài mảnh nhỏ ra xung quanh (bọt nước, vỏ tôm, vụn rau).
func burst(tex: Texture2D, at: Vector2, n := 5, scale := 3.0, spread := 60.0) -> void:
	for i in n:
		var r := sprite(tex, scale, at - tex.get_size() * scale / 2.0)
		var ang := randf() * TAU
		var dist := randf_range(spread * 0.4, spread)
		var t := r.create_tween().set_parallel(true)
		t.tween_property(r, "position", r.position + Vector2(cos(ang), sin(ang) - 0.6) * dist, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(r, "modulate:a", 0.0, 0.25).set_delay(0.25)
		t.chain().tween_callback(r.queue_free)


func sfx(name: String, db := -8.0) -> void:
	var path := SFX + name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Tween di chuyển + đổi cỡ một sprite.
func move_sprite(r: TextureRect, pos: Vector2, new_size := Vector2.ZERO, duration := 0.25) -> Tween:
	var t := r.create_tween().set_parallel(true)
	t.tween_property(r, "position", pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if new_size != Vector2.ZERO:
		t.tween_property(r, "size", new_size, duration)
	return t


static func hit(r: Control, p: Vector2, pad := 0.0) -> bool:
	return Rect2(r.position - Vector2(pad, pad), r.size + Vector2(pad, pad) * 2.0).has_point(p)


static func is_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed()


static func is_release(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.is_pressed()
