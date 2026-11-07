extends Node
## Trạng thái toàn cục của một lượt chơi (autoload: GameState).
## Mọi scene đọc/ghi dữ liệu qua đây, KHÔNG giữ trạng thái lâu dài trong scene.

signal money_changed(new_value: int)
signal inventory_changed
signal stars_changed(new_value: float)

const START_MONEY := 500_000
const FIRST_DAY_KPI := 300_000 ## TODO(nhóm): doc chưa ghi KPI ngày 1 -> chốt con số.
const KPI_GROWTH_PERCENT := 110 ## KPI ngày sau = doanh thu ngày trước + 10%.
const CUSTOMER_PENALTY := 0.05 ## Bị trừ sao -> khách ngày sau giảm 5%.
const MIN_CUSTOMER_MULTIPLIER := 0.2
const START_STARS := 3.0
const START_TABLES_FLOOR1 := 4
const MAX_TABLES_FLOOR1 := 15
const MAX_TABLES_FLOOR2 := 12
const MILESTONE_EVERY := 5 ## Mốc ngày 5, 10, 15...
const MAX_MONSTER_BONUS := 1.0 ## Quái mạnh thêm tối đa +100%.

const INGREDIENT_NAMES := {
	"tomato": "Cà chua",
	"mushroom": "Nấm",
	"beef": "Thịt bò",
	"shrimp": "Tôm",
	"greens": "Rau cải",
	"enoki": "Nấm kim châm",
	# Đồ nhúng (phần săn rơi ra).
	"beef_ball": "Bò viên",
	"squid": "Mực",
	"clam": "Nghêu",
	"napa_cabbage": "Cải thảo",
	"water_spinach": "Rau muống",
	"beef_roll": "Bò cuộn",
	"shiitake": "Nấm hương",
	"chili": "Ớt",
}
const GOLDEN_PREFIX := "golden_" ## vd "golden_tomato" = cà chua hoàng kim.
const GOLDEN_PRICE_MULTIPLIER := 3.0
const SHELF_DAYS := 3 ## Nguyên liệu / nước cốt giữ được tối đa 3 ngày (tính cả ngày nhập).

var money: int
var day: int
var kpi_target: int
var today_revenue: int
var stars: float
var stars_lost_today: int
var customer_multiplier: float
var inventory: Dictionary ## id nguyên liệu (String) -> tổng số lượng (chỉ đọc; tính từ item_batches)
var broths: Dictionary ## id nước cốt (String) -> tổng số nồi (chỉ đọc; tính từ broth_batches)
## Kho chia theo ngày nhập: id -> Array[{day, count, expired}].
## expired = lô đã quá hạn nhưng chủ quán chọn "bán tiếp".
var item_batches: Dictionary
var broth_batches: Dictionary
var upgrades: Dictionary ## id nâng cấp (String) -> cấp hiện tại
var tables_floor1: int
var tables_floor2: int


func _ready() -> void:
	reset_new_game()


func reset_new_game() -> void:
	money = START_MONEY
	day = 1
	kpi_target = FIRST_DAY_KPI
	today_revenue = 0
	stars = START_STARS
	stars_lost_today = 0
	customer_multiplier = 1.0
	inventory = {}
	broths = {}
	item_batches = {}
	broth_batches = {}
	upgrades = {}
	tables_floor1 = START_TABLES_FLOOR1
	tables_floor2 = 0
	money_changed.emit(money)
	inventory_changed.emit()
	stars_changed.emit(stars)


# --- Tiền -------------------------------------------------------------------

## Cộng tiền. count_as_revenue = true nếu là tiền bán hàng (được tính vào KPI).
func add_money(amount: int, count_as_revenue := true) -> void:
	money += amount
	if count_as_revenue:
		today_revenue += amount
	money_changed.emit(money)


func can_afford(amount: int) -> bool:
	return money >= amount


func spend_money(amount: int) -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	return true


func format_money(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped + "đ"


# --- Kho nguyên liệu --------------------------------------------------------

func get_item_count(id: String) -> int:
	return inventory.get(id, 0)


## from_day: ngày nhập (mặc định hôm nay). expired: lô đã quá hạn.
func add_item(id: String, count := 1, from_day := -1, expired := false) -> void:
	_batch_add(item_batches, id, count, from_day, expired)
	_sync_totals()
	inventory_changed.emit()


func has_items(requirements: Dictionary) -> bool:
	for id in requirements:
		if get_item_count(id) < int(requirements[id]):
			return false
	return true


## Trừ nguyên liệu theo công thức (lấy lô cũ nhất trước). Thiếu thì trả về false và không trừ gì.
func consume_items(requirements: Dictionary) -> bool:
	return consume_items_info(requirements)["ok"]


## Như consume_items nhưng cho biết ngày nhập cũ nhất đã dùng và có dùng lô hết hạn không.
## Trả về {ok, oldest_day, expired}.
func consume_items_info(requirements: Dictionary) -> Dictionary:
	if not has_items(requirements):
		return {"ok": false, "oldest_day": day, "expired": false}
	var oldest := day
	var any_expired := false
	for id in requirements:
		var r := _batch_take(item_batches, id, int(requirements[id]))
		oldest = mini(oldest, int(r["oldest_day"]))
		any_expired = any_expired or bool(r["expired"])
	_sync_totals()
	inventory_changed.emit()
	return {"ok": true, "oldest_day": oldest, "expired": any_expired}


func item_display_name(id: String) -> String:
	if id.begins_with(GOLDEN_PREFIX):
		var base := id.trim_prefix(GOLDEN_PREFIX)
		return "%s hoàng kim" % INGREDIENT_NAMES.get(base, base)
	return INGREDIENT_NAMES.get(id, id)


func describe_items(items: Dictionary) -> String:
	if items.is_empty():
		return "(trống)"
	var parts: Array[String] = []
	for id in items:
		parts.append("%s x%d" % [item_display_name(id), int(items[id])])
	return ", ".join(parts)


# --- Nước cốt ---------------------------------------------------------------

## from_day: ngày tính hạn (= ngày nhập nguyên liệu cũ nhất đã nấu). expired: nấu từ đồ hết hạn.
func add_broth(id: String, count := 1, from_day := -1, expired := false) -> void:
	_batch_add(broth_batches, id, count, from_day, expired)
	_sync_totals()
	inventory_changed.emit()


func get_broth_count(id: String) -> int:
	return broths.get(id, 0)


func take_broth(id: String) -> bool:
	return take_broth_info(id)["ok"]


## Lấy 1 nồi (lô cũ nhất trước). Trả về {ok, expired}.
func take_broth_info(id: String) -> Dictionary:
	if get_broth_count(id) <= 0:
		return {"ok": false, "expired": false}
	var r := _batch_take(broth_batches, id, 1)
	_sync_totals()
	inventory_changed.emit()
	return {"ok": true, "expired": r["expired"]}


# --- Hạn sử dụng ------------------------------------------------------------

## Số ngày còn dùng được của 1 lô (3 = nhập hôm nay, 1 = hôm nay là ngày cuối, <= 0 = quá hạn).
func days_left(batch: Dictionary) -> int:
	return int(batch["day"]) + SHELF_DAYS - day


func item_batch_list(id: String) -> Array:
	return item_batches.get(id, [])


func broth_batch_list(id: String) -> Array:
	return broth_batches.get(id, [])


## Các lô vừa quá hạn mà chủ quán chưa quyết định: [{kind: "item"/"broth", id, day, count}].
func newly_expired() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in ["item", "broth"]:
		var store: Dictionary = item_batches if kind == "item" else broth_batches
		for id in store:
			for batch in store[id]:
				if not batch["expired"] and days_left(batch) <= 0:
					result.append({"kind": kind, "id": id, "day": int(batch["day"]), "count": int(batch["count"])})
	return result


## keep = true: giữ lại bán tiếp (có rủi ro bị khách phát hiện); false: bỏ đi.
func resolve_expired(kind: String, id: String, from_day: int, keep: bool) -> void:
	var store: Dictionary = item_batches if kind == "item" else broth_batches
	var list: Array = store.get(id, [])
	for i in range(list.size() - 1, -1, -1):
		var batch: Dictionary = list[i]
		if int(batch["day"]) == from_day and not batch["expired"]:
			if keep:
				batch["expired"] = true
			else:
				list.remove_at(i)
	_merge_batches(list)
	if list.is_empty():
		store.erase(id)
	_sync_totals()
	inventory_changed.emit()


## Số lượng đồ hết hạn đang giữ trong kho (nguyên liệu + nồi).
func expired_stock_count() -> int:
	var n := 0
	for store in [item_batches, broth_batches]:
		for id in store:
			for batch in store[id]:
				if batch["expired"]:
					n += int(batch["count"])
	return n


## Tiêu hủy toàn bộ đồ hết hạn (vd bị thanh tra tịch thu). Trả về số lượng đã hủy.
func discard_expired_stock() -> int:
	var n := 0
	for store in [item_batches, broth_batches]:
		for id in store.keys():
			var list: Array = store[id]
			for i in range(list.size() - 1, -1, -1):
				if list[i]["expired"]:
					n += int(list[i]["count"])
					list.remove_at(i)
			if list.is_empty():
				store.erase(id)
	_sync_totals()
	inventory_changed.emit()
	return n


func _batch_add(store: Dictionary, id: String, count: int, from_day: int, expired: bool) -> void:
	if count <= 0:
		return
	var d := day if from_day < 0 else from_day
	var list: Array = store.get(id, [])
	list.append({"day": d, "count": count, "expired": expired})
	_merge_batches(list)
	store[id] = list


## Lấy count đơn vị: lô hết hạn / cũ nhất trước. Trả về {oldest_day, expired}.
func _batch_take(store: Dictionary, id: String, count: int) -> Dictionary:
	var list: Array = store.get(id, [])
	var oldest := day
	var any_expired := false
	var need := count
	while need > 0 and not list.is_empty():
		var batch: Dictionary = list[0]
		var used := mini(need, int(batch["count"]))
		oldest = mini(oldest, int(batch["day"]))
		any_expired = any_expired or bool(batch["expired"])
		batch["count"] = int(batch["count"]) - used
		need -= used
		if int(batch["count"]) <= 0:
			list.remove_at(0)
	if list.is_empty():
		store.erase(id)
	return {"oldest_day": oldest, "expired": any_expired}


## Gộp lô cùng ngày + cùng trạng thái, sắp xếp: hết hạn trước, rồi ngày cũ trước.
func _merge_batches(list: Array) -> void:
	list.sort_custom(func(a, b):
		if a["expired"] != b["expired"]:
			return a["expired"]
		return int(a["day"]) < int(b["day"]))
	var i := 1
	while i < list.size():
		var prev: Dictionary = list[i - 1]
		var cur: Dictionary = list[i]
		if int(prev["day"]) == int(cur["day"]) and prev["expired"] == cur["expired"]:
			prev["count"] = int(prev["count"]) + int(cur["count"])
			list.remove_at(i)
		else:
			i += 1


func _sync_totals() -> void:
	inventory = _totals(item_batches)
	broths = _totals(broth_batches)


func _totals(store: Dictionary) -> Dictionary:
	var result := {}
	for id in store:
		var n := 0
		for batch in store[id]:
			n += int(batch["count"])
		if n > 0:
			result[id] = n
	return result


# --- Nâng cấp ---------------------------------------------------------------

func get_upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)


func set_upgrade_level(id: String, level: int) -> void:
	upgrades[id] = level


# --- Quán / sao -------------------------------------------------------------

func lose_star(amount := 0.5) -> void:
	stars = maxf(0.0, stars - amount)
	stars_lost_today += 1
	stars_changed.emit(stars)


func add_star(amount: float) -> void:
	stars = minf(5.0, stars + amount)
	stars_changed.emit(stars)


# --- Kết thúc ngày / tiến trình ---------------------------------------------

func is_kpi_reached() -> bool:
	return today_revenue >= kpi_target


## KPI cho ngày mai, tính bằng số nguyên để không bị sai số (làm tròn lên).
func next_kpi() -> int:
	return ceili(today_revenue * KPI_GROWTH_PERCENT / 100.0 - 0.000001)


## Gọi khi đạt KPI: tính KPI mới, áp phạt sao, sang ngày mới.
func advance_to_next_day() -> void:
	kpi_target = next_kpi()
	if stars_lost_today > 0:
		customer_multiplier = maxf(MIN_CUSTOMER_MULTIPLIER, customer_multiplier - CUSTOMER_PENALTY)
	today_revenue = 0
	stars_lost_today = 0
	day += 1
	# Nước cốt + nguyên liệu thừa được giữ sang ngày sau, tối đa SHELF_DAYS ngày (xem newly_expired()).


func milestones_reached() -> int:
	return floori(day / float(MILESTONE_EVERY))


func is_milestone_day() -> bool:
	return day % MILESTONE_EVERY == 0


## Hệ số máu/dame quái: +10% mỗi mốc 5 ngày, cộng dồn tối đa +100%.
func monster_stat_multiplier() -> float:
	return 1.0 + minf(0.1 * milestones_reached(), MAX_MONSTER_BONUS)


# --- Save / load ------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"money": money,
		"day": day,
		"kpi_target": kpi_target,
		"stars": stars,
		"customer_multiplier": customer_multiplier,
		"inventory": inventory,
		"broths": broths,
		"item_batches": item_batches,
		"broth_batches": broth_batches,
		"upgrades": upgrades,
		"tables_floor1": tables_floor1,
		"tables_floor2": tables_floor2,
	}


func load_from_dict(data: Dictionary) -> void:
	reset_new_game()
	money = int(data.get("money", START_MONEY))
	day = int(data.get("day", 1))
	kpi_target = int(data.get("kpi_target", FIRST_DAY_KPI))
	stars = float(data.get("stars", START_STARS))
	customer_multiplier = float(data.get("customer_multiplier", 1.0))
	# Save mới có lô theo ngày; save cũ chỉ có tổng số -> coi như nhập hôm nay.
	item_batches = _to_batches(data.get("item_batches", null), data.get("inventory", {}))
	broth_batches = _to_batches(data.get("broth_batches", null), data.get("broths", {}))
	_sync_totals()
	upgrades = _to_int_dict(data.get("upgrades", {}))
	tables_floor1 = int(data.get("tables_floor1", START_TABLES_FLOOR1))
	tables_floor2 = int(data.get("tables_floor2", 0))
	money_changed.emit(money)
	inventory_changed.emit()
	stars_changed.emit(stars)


func _to_batches(source: Variant, totals: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for id in source:
			var list: Array = []
			for b in source[id]:
				if b is Dictionary:
					list.append({"day": int(b.get("day", day)), "count": int(b.get("count", 0)), "expired": bool(b.get("expired", false))})
			_merge_batches(list)
			if not list.is_empty():
				result[str(id)] = list
		return result
	var counts := _to_int_dict(totals)
	for id in counts:
		if counts[id] > 0:
			result[id] = [{"day": day, "count": counts[id], "expired": false}]
	return result


## JSON đọc số thành float -> đổi lại về int.
func _to_int_dict(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key in source:
			result[str(key)] = int(source[key])
	return result
