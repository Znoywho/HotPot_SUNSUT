class_name PrepAction
extends Control
## Khung chung cho 1 bước sơ chế. Mỗi kiểu thao tác (hold_wash, tap_targets, drag_pull, swipe_cut, timed_stage)
## là 1 script con: dựng hình trong _build(), xử lý chạm, gọi mistake() khi sai và complete() khi xong.
## Điểm bước = 100 - step.penalty × số lỗi. Bước tùy chọn có nút "Bỏ qua" (phát finished(-1)).
## Thao tác dùng sự kiện chuột trái; trên điện thoại chạm được giả lập thành chuột nên dùng ngón tay được.

signal finished(score: int) ## 0..100; -1 = bỏ qua bước tùy chọn.

const KIT := "res://assets/sprites/kitchen/"
const SFX := "res://assets/audio/sfx/"
const AREA := Vector2(780, 300)

var step: PrepStepData
var cfg: PrepConfig
var item_id := ""
var units := 1
var difficulty := 1.0 ## Độ khó thật (đã trừ phần Dao bén làm dễ).
var mistakes := 0
var item: TextureRect ## Hình nguyên liệu lớn ở giữa dụng cụ.
var carry: Texture2D ## Hình nguyên liệu sau bước trước (đã gỡ lá, đã thái...). null = hình gốc. Gán trước begin().
var item_center := Vector2(390, 188)
var _done := false
var _clock := 0.0
var _overlay: Control ## Lớp vẽ tay (thanh, đường chấm, điểm chạm) nằm trên các hình.
var _img: Image ## Bản sao ảnh nguyên liệu để khoét / đổi màu khi gỡ bộ phận (tạo lúc cần).
var _px := 1.0 ## Số px màn hình cho 1 pixel ảnh nguyên liệu.
var _item_home := Vector2.ZERO
var _body_center := Vector2.ZERO ## Tâm phần có hình (pixel ảnh), không phải tâm khung ảnh.
var _body_rect := Rect2() ## Khung bao phần có hình (pixel ảnh).
var _edge_dist := PackedInt32Array() ## Khoảng cách (pixel) từ mỗi pixel có hình tới mép ngoài; tính lúc cần.


func begin(s: PrepStepData, config: PrepConfig, id: String, n: int, diff: float) -> void:
	step = s
	cfg = config
	item_id = id
	units = maxi(1, n)
	difficulty = maxf(0.3, diff)
	custom_minimum_size = AREA
	size = AREA
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	sprite(kit("prep_bg"), 4.0, Vector2.ZERO) # Tường gạch + mặt bàn inox.
	_build_prop()
	var badge := caption("x%d phần" % units, Vector2(16, 108), 18, HuntUI.GOLD)
	badge.z_index = 1
	_build()
	_overlay = Control.new()
	_overlay.size = AREA
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.z_index = 1
	_overlay.draw.connect(func(): _paint(_overlay))
	add_child(_overlay)
	if step.optional:
		var skip := HuntUI.button("Bỏ qua  »", 150)
		skip.position = Vector2(AREA.x - 162, 8)
		skip.pressed.connect(func():
			if not _done:
				_done = true
				finished.emit(-1))
		add_child(skip)


func _process(delta: float) -> void:
	_clock += delta


## Màn con override.
func _build() -> void:
	pass


## Màn con override: vẽ tay lên lớp phủ (dùng c.draw_line, c.draw_rect...).
func _paint(_c: CanvasItem) -> void:
	pass


func redraw() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


# --- Dụng cụ + nguyên liệu ---------------------------------------------------

## Vẽ dụng cụ theo step.prop và hình nguyên liệu. Nồi / bát / rổ vẽ đè lên nửa dưới nguyên liệu (như đang nằm trong đó).
func _build_prop() -> void:
	var scale := 4.0
	match step.prop:
		"sink":
			sprite(kit("sink_big"), 3.0, Vector2(264, 104))
			item_center = Vector2(390, 172)
		"pot":
			item_center = Vector2(390, 168)
		"bowl":
			item_center = Vector2(390, 176)
		"basket":
			sprite(kit("basket_clean"), 4.0, Vector2(274, 150))
			item_center = Vector2(390, 172)
		_:
			sprite(kit("board_big"), 4.0, Vector2(250, 112))
			item_center = Vector2(376, 186)
			scale = 5.0
	var tex := icon_tex()
	item = sprite(tex, scale, item_center - tex.get_size() * scale / 2.0)
	item.pivot_offset = item.size / 2.0
	match step.prop:
		"pot":
			sprite(kit("pot_empty"), 5.0, Vector2(310, 146))
		"bowl":
			sprite(kit("bowl"), 5.0, Vector2(280, 186))
		"basket":
			sprite(kit("basket_front"), 4.0, Vector2(274, 150))


# --- Chấm điểm ---------------------------------------------------------------

func is_done() -> bool:
	return _done


func score() -> int:
	return clampi(100 - step.penalty * mistakes, 0, 100)


func complete() -> void:
	if _done:
		return
	_done = true
	finished.emit(score())


## Xong sau một chút (cho kịp xem hiệu ứng).
func complete_soon(delay := 0.35) -> void:
	if _done:
		return
	get_tree().create_timer(delay).timeout.connect(complete)


func mistake(at: Vector2, text := "Trượt!") -> void:
	mistakes += 1
	pop_text(text, at, Color("ff8a80"), 24)
	sfx("hit", -12.0)
	if item != null:
		var home := item.position
		var t := item.create_tween()
		t.tween_property(item, "position:x", home.x + 8, 0.04)
		t.tween_property(item, "position:x", home.x - 8, 0.06)
		t.tween_property(item, "position:x", home.x, 0.04)


func good(at: Vector2, text := "Chuẩn!", sound := "slice") -> void:
	pop_text(text, at, HuntUI.GOLD, 24)
	sfx(sound, -12.0)


# --- Bộ phận rời ra (lá, vỏ, cuống, đầu mực...) --------------------------------

## Kiểu bộ phận rời ra, đoán theo tên bước: "carve" (gỡ hẳn khỏi nguyên liệu, bỏ đi), "split" (tách ra
## để dùng: lá / cụm nằm lại trên thớt, bước sau vẫn đủ), "peel" (mảnh vỏ bẩy lên rồi rơi, chỗ đó lộ màu
## thịt sáng hơn), "strand" (rút ra 1 sợi: chỉ lưng, xương mực), "pry" (cạy vỏ: nắp vỏ bẩy lên rơi đi,
## còn nửa vỏ dưới có miếng thịt), "" (không có).
func removal_mode() -> String:
	var t := step.title.strip_edges().to_lower()
	if t.begins_with("lột"):
		return "peel"
	if t.begins_with("cạy"):
		return "pry"
	if t.begins_with("rút"):
		return "strand"
	if t.begins_with("tách") and not t.begins_with("tách đầu"):
		return "split"
	for k in ["tách", "bóc", "nhặt", "bỏ", "loại", "gỡ", "lọc", "cắt râu"]:
		if t.begins_with(k):
			return "carve"
	return ""


func _ensure_img() -> bool:
	if _img != null:
		return true
	if item == null or item.texture == null:
		return false
	_img = item.texture.get_image()
	if _img == null:
		return false
	if _img.is_compressed():
		_img.decompress()
	_img.convert(Image.FORMAT_RGBA8)
	_px = item.size.x / float(_img.get_width())
	_item_home = item.position
	var sum := Vector2.ZERO
	var n := 0
	var lo := Vector2(_img.get_size())
	var hi := Vector2.ZERO
	for y in _img.get_height():
		for x in _img.get_width():
			if _img.get_pixel(x, y).a > 0.5:
				var p := Vector2(x + 0.5, y + 0.5)
				sum += p
				n += 1
				lo = lo.min(p)
				hi = hi.max(p)
	_body_center = sum / n if n > 0 else Vector2(_img.get_size()) / 2.0
	_body_rect = Rect2(lo, hi - lo) if n > 0 else Rect2(Vector2.ZERO, Vector2(_img.get_size()))
	return true


## Toạ độ trong khung thao tác -> toạ độ pixel ảnh nguyên liệu.
func to_px(p: Vector2) -> Vector2:
	_ensure_img()
	return (p - _item_home) / _px


## Điểm p (toạ độ khung) có nằm trên phần có hình của nguyên liệu không.
func opaque_at(p: Vector2) -> bool:
	if not _ensure_img():
		return true
	var q := Vector2i(to_px(p).floor())
	if q.x < 0 or q.y < 0 or q.x >= _img.get_width() or q.y >= _img.get_height():
		return false
	return _img.get_pixelv(q).a > 0.5


## Mặt nạ hình quạt từ tâm phần có hình theo hướng dir (góc ±half_angle), bỏ phần lõi gần tâm.
func wedge(dir: Vector2, half_angle: float, inner := 0.15) -> Callable:
	_ensure_img()
	var c := _body_center
	var r := maxf(_body_rect.size.x, _body_rect.size.y) / 2.0
	return func(p: Vector2) -> bool:
		var v := p - c
		return v.length() >= r * inner and absf(v.angle_to(dir)) <= half_angle


## Mặt nạ 1 phần khung bao hình, toạ độ 0..1 (vd Rect2(0, 0.55, 1, 0.45) = 45% phía dưới).
func body_part(frac: Rect2) -> Callable:
	_ensure_img()
	var r := Rect2(_body_rect.position + frac.position * _body_rect.size, frac.size * _body_rect.size)
	return func(p: Vector2) -> bool: return r.grow(0.5).has_point(p)


## Mặt nạ dải viền ngoài dày depth pixel (lớp lá / vỏ ngoài cùng), ôm theo đúng dáng nguyên liệu.
func edge_band(depth: int) -> Callable:
	if not _ensure_img():
		return func(_p: Vector2) -> bool: return false
	var w := _img.get_width()
	var h := _img.get_height()
	if _edge_dist.is_empty():
		_edge_dist.resize(w * h)
		_edge_dist.fill(-1)
		var queue: Array[Vector2i] = []
		for y in h:
			for x in w:
				if _img.get_pixel(x, y).a <= 0.5:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or _img.get_pixelv(q).a <= 0.5:
						_edge_dist[y * w + x] = 0
						queue.append(Vector2i(x, y))
						break
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
					continue
				if _edge_dist[q.y * w + q.x] == -1 and _img.get_pixelv(q).a > 0.5:
					_edge_dist[q.y * w + q.x] = _edge_dist[c.y * w + c.x] + 1
					queue.append(q)
	var dist := _edge_dist
	return func(p: Vector2) -> bool:
		var i := int(p.y) * w + int(p.x)
		return i >= 0 and i < dist.size() and dist[i] >= 0 and dist[i] < depth


## Mặt nạ hình tròn (toạ độ pixel ảnh).
func circle(center: Vector2, radius: float) -> Callable:
	return func(p: Vector2) -> bool: return p.distance_to(center) <= radius


## Tách các pixel thoả mask thành 1 mảnh riêng nằm đúng chỗ cũ.
## remove = khoét khỏi nguyên liệu; nếu không, recolor (a = mức pha) đổi màu chỗ đó trên nguyên liệu.
func carve(mask: Callable, remove := true, recolor := Color(0, 0, 0, 0)) -> TextureRect:
	if not _ensure_img():
		return null
	var w := _img.get_width()
	var h := _img.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	var picked: Array[Vector2i] = []
	for y in h:
		for x in w:
			if _img.get_pixel(x, y).a <= 0.1 or not mask.call(Vector2(x + 0.5, y + 0.5)):
				continue
			var q := Vector2i(x, y)
			picked.append(q)
			lo = lo.min(q)
			hi = hi.max(q)
	if picked.is_empty():
		return null
	var dims := hi - lo + Vector2i.ONE
	var piece := Image.create(dims.x, dims.y, false, Image.FORMAT_RGBA8)
	for q in picked:
		var c := _img.get_pixelv(q)
		piece.set_pixelv(q - lo, c)
		if remove:
			_img.set_pixelv(q, Color(0, 0, 0, 0))
		elif recolor.a > 0.0:
			_img.set_pixelv(q, Color(c.lerp(recolor, recolor.a), c.a))
	if remove or recolor.a > 0.0:
		item.texture = ImageTexture.create_from_image(_img)
	var r := sprite(ImageTexture.create_from_image(piece), _px, _item_home + Vector2(lo) * _px)
	r.pivot_offset = r.size / 2.0
	r.z_index = 2 # Nằm trên núm kéo / vòng chạm để thấy rõ bộ phận đang rời ra.
	return r


## Mảnh bật ra theo hướng push rồi rơi xuống khỏi khung, vừa rơi vừa xoay.
func drop_piece(r: TextureRect, push := Vector2.ZERO) -> void:
	if r == null:
		return
	var start := r.position
	var side := signf(push.x) if absf(push.x) > 0.1 else (1.0 if randf() < 0.5 else -1.0)
	var top := start + push * 30.0 + Vector2(0, -18)
	var t := r.create_tween()
	t.tween_property(r, "position", top, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(r, "rotation", r.rotation + side * 0.4, 0.14)
	t.tween_property(r, "position", top + Vector2(side * 40.0, AREA.y - top.y + 30.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(r, "rotation", r.rotation + side * 2.4, 0.55)
	t.parallel().tween_property(r, "modulate:a", 0.0, 0.2).set_delay(0.35)
	t.tween_callback(r.queue_free)


# --- Tiện ích vẽ -------------------------------------------------------------

func kit(name: String) -> Texture2D:
	return load(KIT + name + ".png")


func icon_tex() -> Texture2D:
	return carry if carry != null else HuntUI.ingredient_texture(item_id)


## Hình nguyên liệu sau bước này, để bước sau tiếp tục từ đó. null = quay về hình gốc.
func result_texture() -> Texture2D:
	if item != null and item.texture != null:
		return item.texture
	return carry


## Ảnh "bẩn" của nguyên liệu (cho bước rửa), không có thì dùng ảnh thường.
func dirty_tex() -> Texture2D:
	if carry != null:
		return carry
	var path := KIT + item_id.trim_prefix(GameState.GOLDEN_PREFIX) + "_dirty.png"
	return load(path) if ResourceLoader.exists(path) else icon_tex()


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


func caption(text: String, pos: Vector2, size_px := 18, color := Color.WHITE) -> Label:
	var l := HuntUI.outlined_label(text, size_px, color)
	l.position = pos
	l.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Bàn tay chỉ chỗ cần thao tác. kind: "tap" (nhấp), "swipe" (đưa theo dir), "hold" (nhấn giữ).
func pointer(at: Vector2, kind := "tap", dir := Vector2.RIGHT) -> TextureRect:
	var h := sprite(kit("hand"), 4.0, at)
	h.z_index = 2
	var t := h.create_tween().set_loops()
	match kind:
		"swipe":
			t.tween_property(h, "position", at + dir * 90.0, 0.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(h, "position", at, 0.01)
			t.tween_interval(0.25)
		"circle":
			t.tween_method(func(a: float): h.position = at + Vector2(cos(a), sin(a)) * 36.0, 0.0, TAU, 1.1)
		"hold":
			t.tween_property(h, "scale", Vector2(0.9, 0.9), 0.4)
			t.tween_property(h, "scale", Vector2.ONE, 0.4)
		_:
			t.tween_property(h, "position:y", at.y + 12, 0.25).set_trans(Tween.TRANS_SINE)
			t.tween_property(h, "position:y", at.y, 0.25).set_trans(Tween.TRANS_SINE)
	return h


## Chữ nổi kiểu truyện tranh ("Chuẩn!", "Đứt rồi!").
func pop_text(text: String, at: Vector2, color := Color.WHITE, size_px := 26) -> void:
	var l := HuntUI.outlined_label(text, size_px, color)
	l.position = at
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.z_index = 3
	add_child(l)
	l.pivot_offset = Vector2(30, 16)
	l.scale = Vector2(0.6, 0.6)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", at.y - 34, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)


## Văng vài mảnh nhỏ ra xung quanh (bọt nước, vụn...).
func burst(tex: Texture2D, at: Vector2, n := 5, scale := 3.0, spread := 60.0, up := 0.6) -> void:
	for i in n:
		var r := sprite(tex, scale, at - tex.get_size() * scale / 2.0)
		var ang := randf() * TAU
		var dist := randf_range(spread * 0.4, spread)
		var t := r.create_tween().set_parallel(true)
		t.tween_property(r, "position", r.position + Vector2(cos(ang), sin(ang) - up) * dist, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


## Vòi nước gắn tường; trả về dòng nước (bật/tắt bằng visible). Nước rơi tới độ cao bottom.
func faucet(at: Vector2, bottom: float) -> TextureRect:
	sprite(kit("faucet"), 4.0, at)
	var atlas := AtlasTexture.new()
	atlas.atlas = kit("water_stream")
	atlas.region = Rect2(0, 0, 6, 20)
	var mouth := at + Vector2(17.0 * 4.0, 17.0 * 4.0)
	var w := sprite(atlas, 4.0, mouth)
	w.size = Vector2(24, maxf(8.0, bottom - mouth.y))
	var t := w.create_tween().set_loops()
	for i in 4:
		t.tween_callback(func(): atlas.region = Rect2(6 * i, 0, 6, 20))
		t.tween_interval(0.08)
	return w


## Viên thịt vẽ tay: rough 1 = nắm thịt méo lổn nhổn, 0 = tròn đều. spin xoay các đốm mỡ (trông như đang lăn).
func draw_meatball(c: CanvasItem, at: Vector2, r: float, rough: float, seed_i: int, spin := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (seed_i + 1)
	var pts := PackedVector2Array()
	var n := 18
	for k in n:
		var a := TAU * k / n
		var rr := r * (1.0 + rough * rng.randf_range(-0.28, 0.32))
		pts.append(at + Vector2(cos(a), sin(a) * (1.0 - rough * 0.25)) * rr)
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(at + (p - at) * 1.0 + (p - at).normalized() * 4.0)
	c.draw_colored_polygon(outline, Color("3b2116"))
	c.draw_colored_polygon(pts, Color("8b5a3c"))
	c.draw_circle(at + Vector2(r * 0.12, r * 0.18), r * 0.62, Color("6e4430"))
	c.draw_circle(at + Vector2(-r * 0.32, -r * 0.32), r * 0.26, Color("b07a55"))
	for k in 5:
		var a := rng.randf() * TAU + spin
		var d := rng.randf_range(0.2, 0.7) * r
		var sz := rng.randf_range(3.0, 5.0)
		c.draw_rect(Rect2(at + Vector2(cos(a), sin(a)) * d - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color("e0bf96"))


## Vẽ đường nét đứt (dash) từ a tới b.
func dashed(c: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 4.0, dash := 10.0) -> void:
	c.draw_dashed_line(a, b, color, width, dash)


static func is_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed()


static func is_release(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.is_pressed()
