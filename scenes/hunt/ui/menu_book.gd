class_name MenuBook
extends RefCounted
## Nội dung thẻ "Thực đơn" trong bảng Kho: các loại lẩu (giá, công thức, ngày mở khoá, số nồi có sẵn)
## và đồ nhúng (giá theo chất lượng sơ chế). Chỉ đọc dữ liệu, không đổi gì trong game.

const POT_ICON := "res://assets/sprites/ui/broth_pot.png"
const SELL_SCRIPT := "res://scenes/sell/sell_phase.gd" ## Giá gốc + danh sách đồ nhúng lấy từ màn bán (Tuấn).
const FALLBACK_DIPPING_PRICE := 10_000


## Danh sách thực đơn để đặt vào ScrollContainer.
static func build() -> Control:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)

	list.add_child(HuntUI.label("Nước lẩu (giá mỗi nồi, 1 bàn gọi 1 nồi)", 22, HuntUI.RUST))
	var broths: Array = Database.broths.duplicate()
	broths.sort_custom(func(a: BrothData, b: BrothData) -> bool:
		return a.unlock_day < b.unlock_day or (a.unlock_day == b.unlock_day and a.price < b.price))
	var pot: Texture2D = load(POT_ICON) if ResourceLoader.exists(POT_ICON) else null
	for broth in broths:
		list.add_child(_broth_row(broth, pot))

	list.add_child(HSeparator.new())
	list.add_child(HuntUI.label("Đồ nhúng (giá mỗi đĩa, theo chất lượng sơ chế)", 22, HuntUI.RUST))
	for id in _dipping_ids():
		list.add_child(_dipping_row(id))
	return list


static func _broth_row(broth: BrothData, pot: Texture2D) -> Control:
	var unlocked := broth.unlock_day <= GameState.day
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if pot != null:
		var ic := HuntUI.texture_rect(pot, 48)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 12)
	var name := HuntUI.label(broth.display_name, HuntUI.FONT)
	title.add_child(name)
	title.add_child(HuntUI.label(GameState.format_money(broth.price), HuntUI.FONT, HuntUI.GOLDEN_INK))
	info.add_child(title)
	var recipe := HBoxContainer.new()
	recipe.add_theme_constant_override("separation", 6)
	recipe.add_child(HuntUI.label("Công thức:", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	recipe.add_child(HuntUI.items_row(broth.ingredients, 32))
	info.add_child(recipe)
	row.add_child(info)

	var status: Label
	if unlocked:
		var pots := GameState.get_broth_count(broth.id)
		status = HuntUI.label("Có sẵn: %d nồi" % pots, HuntUI.FONT_SMALL, HuntUI.GOOD if pots > 0 else HuntUI.INK_SOFT)
	else:
		status = HuntUI.label("Mở từ ngày %d" % broth.unlock_day, HuntUI.FONT_SMALL, HuntUI.WARN)
		row.modulate = Color(1, 1, 1, 0.55) # Món chưa mở: mờ đi.
	status.custom_minimum_size = Vector2(150, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	return row


static func _dipping_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ic := HuntUI.texture_rect(HuntUI.ingredient_texture(id), 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var name := HuntUI.label(GameState.item_display_name(id), HuntUI.FONT_SMALL)
	name.custom_minimum_size = Vector2(170, 0)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var cfg: PrepConfig = Database.prep_config
	var parts: Array[String] = []
	parts.append("Thô %s" % _short(_dipping_price(cfg.dipping_price_mult(-1))))
	for q in GameState.QUALITY_NAMES.size():
		parts.append("%s %s" % [GameState.QUALITY_NAMES[q], _short(_dipping_price(cfg.dipping_price_mult(q)))])
	var prices := HuntUI.label(" · ".join(parts), HuntUI.FONT_SMALL, HuntUI.INK)
	prices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prices.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(prices)
	return row


## Làm tròn giống lúc tính tiền ở màn bán.
static func _dipping_price(mult: float) -> int:
	return roundi(_base_dipping_price() * mult / 1000.0) * 1000


static func _short(value: int) -> String:
	return "%dk" % (value / 1000) if value % 1000 == 0 else GameState.format_money(value)


static func _sell_constants() -> Dictionary:
	var script: Script = load(SELL_SCRIPT) if ResourceLoader.exists(SELL_SCRIPT) else null
	return script.get_script_constant_map() if script != null else {}


static func _base_dipping_price() -> int:
	return int(_sell_constants().get("DIPPING_PRICE", FALLBACK_DIPPING_PRICE))


static func _dipping_ids() -> Array:
	return _sell_constants().get("DIPPING_POOL", [])
