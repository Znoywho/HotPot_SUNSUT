class_name DamageNumber
extends RefCounted
## Số / chữ bật ra trên đầu đơn vị trong trận, dùng font pixel PixelTitle:
## bật to quá đà rồi về cỡ thật (TRANS_BACK), bay vòng cung lệch sang một bên rồi rơi, mờ dần lúc cuối.
## Chí mạng: to hơn, vàng, giữ một nhịp và lắc nghiêng. Chữ báo (NÉ!, CUỒNG NỘ!, "!") bay thẳng lên.
## Tween bỏ qua time_scale: số vẫn bật ra ngay cả lúc hitstop đứng hình (skill game-feel: UI chạy theo thời gian thật).

enum Kind { DAMAGE, CRIT, HEAL, ARMOR, CALLOUT, WARN }

## Kind -> [bảng màu PixelTitle, độ phóng nguyên lần]
const STYLE := {
	Kind.DAMAGE: ["game_over", 2],
	Kind.CRIT: ["noon", 3],
	Kind.HEAL: ["heal", 2],
	Kind.ARMOR: ["armor", 2],
	Kind.CALLOUT: ["white", 2],
	Kind.WARN: ["game_over", 2],
}
const STACK_STEP := 34.0 ## Nhiều số trên cùng một đơn vị trong một bước: xếp chồng cách nhau chừng này px.


## Hiện chữ `text` với tâm ở `anchor` (toạ độ global). stack = thứ tự xếp chồng, side = hướng bay lệch (-1 trái, 1 phải).
static func spawn(layer: Control, anchor: Vector2, text: String, kind := Kind.DAMAGE, stack := 0, side := 1.0, speed := 1.0) -> Label:
	var style: Array = STYLE[kind]
	var l := Label.new()
	l.text = text
	PixelTitle.apply_label(l, style[0], style[1])
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 5
	layer.add_child(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = (l.size / 2.0).round()
	var arcs := kind == Kind.DAMAGE or kind == Kind.CRIT
	var jitter := randf_range(-10.0, 10.0) if arcs else 0.0
	l.global_position = (anchor - l.size / 2.0 + Vector2(jitter, -stack * STACK_STEP)).round()
	l.scale = Vector2.ONE * 0.4
	var d := 1.0 / maxf(speed, 0.1)
	var crit := kind == Kind.CRIT
	var pop := l.create_tween().set_ignore_time_scale(true)
	pop.tween_property(l, "scale", Vector2.ONE * (1.4 if crit else 1.2), 0.07 * d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(l, "scale", Vector2.ONE, 0.09 * d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if crit:
		var wobble := l.create_tween().set_ignore_time_scale(true)
		wobble.tween_property(l, "rotation", -0.14, 0.05 * d)
		wobble.tween_property(l, "rotation", 0.1, 0.06 * d)
		wobble.tween_property(l, "rotation", 0.0, 0.08 * d)
	var y0 := l.position.y
	var total := 0.85
	var move := l.create_tween().set_ignore_time_scale(true)
	if arcs:
		var hold := 0.18 if crit else 0.0
		total = hold + 0.72
		move.tween_interval(hold * d)
		move.tween_property(l, "position:y", y0 - 56.0, 0.3 * d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		move.tween_property(l, "position:y", y0 - 30.0, 0.42 * d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var drift := l.create_tween().set_ignore_time_scale(true)
		drift.tween_interval(hold * d)
		drift.tween_property(l, "position:x", l.position.x + side * randf_range(24.0, 48.0), 0.72 * d)
	else:
		move.tween_property(l, "position:y", y0 - 48.0, total * d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade := l.create_tween().set_ignore_time_scale(true)
	fade.tween_interval((total - 0.25) * d)
	fade.tween_property(l, "modulate:a", 0.0, 0.25 * d)
	fade.tween_callback(l.queue_free)
	return l
