extends PrepAction
## SWIPE_CUT: vuốt dọc theo đường chấm để cắt / khía / thái. Vuốt đủ dài và không lệch quá
## swipe_tolerance (px, chia độ khó) là được; vuốt lệch bị trừ điểm. pattern "cross" = khía chữ thập.
## Mỗi nhát đúng tách hình nguyên liệu thành mảnh thật (AtlasTexture) và đẩy 2 bên ra; nhát cuối các mảnh văng
## ra rồi đổ nghiêng. Bước "Khía..." chỉ hở khe nhỏ (khía chứ không đứt).

const SPLIT_GAP := 10.0 ## px mỗi nhát cắt đẩy 2 nửa ra xa nhau.
const SCORE_GAP := 3.0 ## px với bước khía.
const FLASH_TIME := 0.22 ## Giây vệt sáng của nhát dao.

var _lines: Array = [] ## [[a, b], ...]
var _i := 0
var _cuts: Array = []
var _swiping := false
var _path := PackedVector2Array()
var _knife: TextureRect
var _hand: TextureRect
var _pieces: Array = [] ## [{rect: TextureRect, region: Rect2 (pixel ảnh), offset: Vector2}]
var _flashes: Array = [] ## [[a, b, tuổi]]


func _build() -> void:
	var c := item_center
	var h := item.size.y * 0.46
	if step.pattern == "cross":
		for k in step.count:
			if k % 2 == 0:
				_lines.append([c + Vector2(-h, 0), c + Vector2(h, 0)])
			else:
				_lines.append([c + Vector2(0, -h), c + Vector2(0, h)])
	else:
		var gap := minf(40.0, item.size.x * 0.8 / maxf(1.0, step.count))
		for k in step.count:
			var x := c.x + (k - (step.count - 1) / 2.0) * gap
			_lines.append([Vector2(x, c.y - h), Vector2(x, c.y + h)])
	_knife = sprite(kit("knife_big"), 3.0, Vector2(560, 120))
	_knife.pivot_offset = Vector2(84, 15)
	var first: Array = _lines[0]
	var a: Vector2 = first[0]
	var b: Vector2 = first[1]
	_hand = pointer(a + Vector2(-4, 0), "swipe", (b - a).normalized())
	_make_pieces()


func _process(delta: float) -> void:
	super(delta)
	for f in _flashes:
		f[2] += delta
	_flashes = _flashes.filter(func(f): return f[2] < FLASH_TIME)
	redraw()


func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if is_press(event):
		_swiping = true
		_path = PackedVector2Array([(event as InputEventMouseButton).position])
		if _hand != null:
			_hand.queue_free()
			_hand = null
		accept_event()
	elif event is InputEventMouseMotion and _swiping:
		_path.append((event as InputEventMouseMotion).position)
		accept_event()
	elif is_release(event) and _swiping:
		_swiping = false
		_judge()
		accept_event()


## Vuốt đúng: phủ >= 70% đường chấm và lệch trung bình <= dung sai.
func _judge() -> void:
	if _i >= _lines.size() or _path.size() < 2:
		return
	var line: Array = _lines[_i]
	var a: Vector2 = line[0]
	var b: Vector2 = line[1]
	var ab := b - a
	var t_min := 1.0
	var t_max := 0.0
	var dev := 0.0
	var walked := 0.0
	for k in _path.size():
		var p := _path[k]
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		t_min = minf(t_min, t)
		t_max = maxf(t_max, t)
		dev += p.distance_to(a + ab * t)
		if k > 0:
			walked += p.distance_to(_path[k - 1])
	dev /= _path.size()
	if walked < 30.0:
		return # Chạm nhẹ, không tính.
	var tol := cfg.swipe_tolerance / difficulty
	if t_max - t_min >= 0.7 and dev <= tol:
		_cuts.append(line)
		_i += 1
		_flashes.append([a, b, 0.0])
		_split(line)
		burst(kit("bubble"), b, 3, 2.0, 30.0)
		good(b + Vector2(10, -40), "Xoẹt!", "slice")
		var kt := _knife.create_tween()
		kt.tween_property(_knife, "rotation", 0.5, 0.06)
		kt.tween_property(_knife, "rotation", 0.0, 0.14)
		if _i >= _lines.size():
			_fall_apart()
			complete_soon(0.7)
	else:
		mistake(_path[_path.size() - 1] + Vector2(-40, -50), "Lệch rồi!")


# --- Tách mảnh ---------------------------------------------------------------

func _is_scoring() -> bool:
	return step.title.strip_edges().to_lower().begins_with("khía")


## Thay hình nguyên liệu bằng 1 mảnh duy nhất (con của item để mistake() rung cả cụm).
func _make_pieces() -> void:
	var tex := item.texture
	if tex == null:
		return
	_px = item.size.x / tex.get_size().x
	_add_piece(tex, Rect2(Vector2.ZERO, tex.get_size()), Vector2.ZERO)
	item.texture = null


func _add_piece(src: Texture2D, region: Rect2, offset: Vector2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = region
	var r := TextureRect.new()
	r.texture = atlas
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = region.size * _px
	r.pivot_offset = r.size / 2.0
	r.position = region.position * _px + offset
	r.mouse_filter = MOUSE_FILTER_IGNORE
	item.add_child(r)
	_pieces.append({"rect": r, "region": region, "offset": offset, "src": src})


## Cắt mọi mảnh mà đường cắt đi qua thành 2, rồi đẩy 2 phía ra xa nhau.
func _split(line: Array) -> void:
	if _pieces.is_empty():
		return
	var a: Vector2 = line[0]
	var b: Vector2 = line[1]
	var vertical := absf(b.x - a.x) < absf(b.y - a.y)
	## Toạ độ đường cắt theo pixel ảnh (làm tròn để mảnh khớp pixel).
	var at := roundf(((a.x - item.position.x) if vertical else (a.y - item.position.y)) / _px)
	var split_any := false
	for p in _pieces.duplicate():
		var reg: Rect2 = p.region
		var lo: float = reg.position.x if vertical else reg.position.y
		var hi: float = reg.end.x if vertical else reg.end.y
		if at <= lo or at >= hi:
			continue
		split_any = true
		_pieces.erase(p)
		(p.rect as TextureRect).queue_free()
		var first := reg
		var second := reg
		if vertical:
			first.size.x = at - reg.position.x
			second.position.x = at
			second.size.x = reg.end.x - at
		else:
			first.size.y = at - reg.position.y
			second.position.y = at
			second.size.y = reg.end.y - at
		_add_piece(p.src, first, p.offset)
		_add_piece(p.src, second, p.offset)
	if not split_any:
		return
	var gap := (SCORE_GAP if _is_scoring() else (SPLIT_GAP * 0.5 if step.title.to_lower().begins_with("ngắt") else SPLIT_GAP)) / 2.0 # Rau ngắt khúc: khe hẹp, đừng làm rau trông nát.
	for p in _pieces:
		var reg: Rect2 = p.region
		var centre: Vector2 = reg.get_center()
		var side: float = signf((centre.x if vertical else centre.y) - at)
		p.offset += (Vector2(side * gap, 0) if vertical else Vector2(0, side * gap))
		var r: TextureRect = p.rect
		var t := r.create_tween()
		t.tween_property(r, "position", reg.position * _px + p.offset, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Nhát cuối: các mảnh văng ra khỏi tâm một chút rồi đổ nghiêng (bước khía thì chỉ nảy nhẹ).
func _fall_apart() -> void:
	var centre := item.size / 2.0
	var scoring := _is_scoring()
	for p in _pieces:
		var r: TextureRect = p.rect
		var reg: Rect2 = p.region
		var dir: Vector2 = (reg.get_center() * _px - centre)
		dir = dir.normalized() if dir.length() > 1.0 else Vector2.ZERO
		var home: Vector2 = reg.position * _px + p.offset
		var t := r.create_tween()
		if scoring:
			t.tween_property(r, "position", home + dir * 4.0 + Vector2(0, -6), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(r, "position", home + dir * 4.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			continue
		var out: Vector2 = home + dir * randf_range(14.0, 24.0)
		t.set_parallel(true)
		t.tween_property(r, "position", out + Vector2(0, -14), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(r, "rotation", signf(dir.x if dir.x != 0.0 else randf() - 0.5) * randf_range(0.12, 0.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(r, "position", out, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if not scoring:
		burst(kit("bubble"), item.position + centre, 6, 2.0, 70.0, 0.3)


## Ghép các lát thành 1 hình (có khe) cho bước sau. Bước khía: hình nguyên vẹn + vệt khía sẫm.
func result_texture() -> Texture2D:
	if _pieces.is_empty():
		return super()
	var src: Image = (_pieces[0].src as Texture2D).get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	if _is_scoring():
		var img := src.duplicate() as Image
		for line in _cuts:
			var a: Vector2 = line[0]
			var b: Vector2 = line[1]
			var vertical := absf(b.x - a.x) < absf(b.y - a.y)
			var at := int(roundf(((a.x - item.position.x) if vertical else (a.y - item.position.y)) / _px))
			for k in (img.get_height() if vertical else img.get_width()):
				var q := Vector2i(at, k) if vertical else Vector2i(k, at)
				if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
					continue
				var col := img.get_pixelv(q)
				if col.a > 0.5:
					img.set_pixelv(q, Color(col.lerp(Color.BLACK, 0.4), col.a))
		return ImageTexture.create_from_image(img)
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	var places: Array = []
	for p in _pieces:
		var reg: Rect2 = p.region
		var dst := Vector2i(reg.position.round()) + Vector2i((p.offset / _px).round())
		places.append([Rect2i(reg), dst])
		lo = lo.min(dst)
		hi = hi.max(dst + Vector2i(reg.size.round()))
	var out := Image.create(hi.x - lo.x, hi.y - lo.y, false, Image.FORMAT_RGBA8)
	for pl in places:
		out.blend_rect(src, pl[0], (pl[1] as Vector2i) - lo)
	return ImageTexture.create_from_image(out)


func _paint(c: CanvasItem) -> void:
	if _pieces.is_empty():
		for line in _cuts:
			c.draw_line(line[0], line[1], Color(0.24, 0.1, 0.06, 0.9), 5.0)
	for f in _flashes:
		var k: float = 1.0 - f[2] / FLASH_TIME
		c.draw_line(f[0], f[1], Color(1, 1, 1, 0.9 * k), 3.0 + 6.0 * k)
	for k in range(_i, _lines.size()):
		var line: Array = _lines[k]
		var col := Color.WHITE if k == _i else Color(1, 1, 1, 0.35)
		dashed(c, line[0], line[1], Color(0, 0, 0, 0.4) if k == _i else Color(0, 0, 0, 0.15), 8.0, 12.0)
		dashed(c, line[0], line[1], col, 4.0, 12.0)
	if _swiping and _path.size() >= 2:
		c.draw_polyline(_path, Color(1, 1, 1, 0.9), 6.0)
