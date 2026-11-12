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
const MAX_TABLES_FLOOR1 := 10 ## Bằng giá trị cao nhất của nâng cấp "Thêm bàn" (data/upgrades/tables.tres).
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
const PREPPED_PREFIX := "prepped_" ## Tên hiển thị / đồ nhúng: "prepped_squid" = mực đã sơ chế (kho vẫn lưu theo id thô).
const QUALITY_NAMES := ["Kém", "Thường", "Thượng hạng"] ## Chất lượng đồ đã sơ chế: 0, 1, 2.
const SHELF_DAYS := 3 ## Nguyên liệu / nước cốt giữ được tối đa 3 ngày (tính cả ngày nhập), chưa tính Kho lạnh.

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
## Nguyên liệu đã sơ chế (thái, rửa, bóc vỏ...), cùng cấu trúc lô. Chỉ nấu được bằng đồ đã sơ chế.
## Đồ đã sơ chế chỉ giữ được trong ngày: sang ngày mới là bỏ hết (xem advance_to_next_day).
var prepped: Dictionary ## id -> tổng số phần đã sơ chế (chỉ đọc; tính từ prepped_batches)
var prepped_batches: Dictionary
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
	prepped = {}
	prepped_batches = {}
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
	if id.begins_with(PREPPED_PREFIX):
		return "%s đã sơ chế" % item_display_name(id.trim_prefix(PREPPED_PREFIX))
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


# --- Nguyên liệu đã sơ chế ---------------------------------------------------

func get_prepped_count(id: String) -> int:
	return prepped.get(id, 0)


func prepped_batch_list(id: String) -> Array:
	return prepped_batches.get(id, [])


## Sơ chế count phần: chuyển từ kho thô sang kho đã sơ chế với chất lượng quality (0 Kém, 1 Thường, 2 Thượng hạng).
## Giữ ngày nhập và cờ hết hạn của lô thô (không làm mới hạn). Trả về số phần sơ chế được.
func prep_items(id: String, count := 1, quality := 1) -> int:
	var n := mini(count, get_item_count(id))
	if n <= 0:
		return 0
	var r := _batch_take(item_batches, id, n)
	for piece in r["pieces"]:
		_batch_add(prepped_batches, id, int(piece["count"]), int(piece["day"]), bool(piece["expired"]), quality)
	_sync_totals()
	inventory_changed.emit()
	return n


## Sơ chế hỏng nặng: mất count phần thô. Trả về số phần đã mất.
func ruin_items(id: String, count: int) -> int:
	var n := mini(count, get_item_count(id))
	if n <= 0:
		return 0
	_batch_take(item_batches, id, n)
	_sync_totals()
	inventory_changed.emit()
	return n


## Số phần đã sơ chế theo chất lượng: [Kém, Thường, Thượng hạng].
func prepped_quality_counts(id: String) -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	for batch in prepped_batches.get(id, []):
		result[clampi(int(batch.get("q", 1)), 0, 2)] += int(batch["count"])
	return result


## Trả đồ đã sơ chế vào kho (vd nồi chưa chín bị nhấc ra thì hoàn nguyên liệu).
func add_prepped(id: String, count := 1, from_day := -1, expired := false, quality := 1) -> void:
	_batch_add(prepped_batches, id, count, from_day, expired, quality)
	_sync_totals()
	inventory_changed.emit()


func has_prepped(requirements: Dictionary) -> bool:
	for id in requirements:
		if get_prepped_count(id) < int(requirements[id]):
			return false
	return true


## Trừ đồ đã sơ chế theo công thức (lô cũ nhất trước). Thiếu thì không trừ gì.
## Trả về {ok, oldest_day, expired, taken}; taken = {id: [{day, count, expired}]} để hoàn lại nếu cần.
func consume_prepped_info(requirements: Dictionary) -> Dictionary:
	if not has_prepped(requirements):
		return {"ok": false, "oldest_day": day, "expired": false, "taken": {}}
	var oldest := day
	var any_expired := false
	var taken := {}
	for id in requirements:
		var r := _batch_take(prepped_batches, id, int(requirements[id]))
		oldest = mini(oldest, int(r["oldest_day"]))
		any_expired = any_expired or bool(r["expired"])
		taken[id] = r["pieces"]
	_sync_totals()
	inventory_changed.emit()
	return {"ok": true, "oldest_day": oldest, "expired": any_expired, "taken": taken}


## Hoàn lại đúng các phần đã lấy bằng consume_prepped_info().
func refund_prepped(taken: Dictionary) -> void:
	for id in taken:
		for piece in taken[id]:
			_batch_add(prepped_batches, id, int(piece["count"]), int(piece["day"]), bool(piece["expired"]), int(piece.get("q", 1)))
	_sync_totals()
	inventory_changed.emit()


## Đủ nguyên liệu nấu 1 mẻ nếu tính cả đồ đã sơ chế lẫn đồ thô.
func can_cook(requirements: Dictionary) -> bool:
	for id in requirements:
		if get_prepped_count(id) + get_item_count(id) < int(requirements[id]):
			return false
	return true


## Lấy nguyên liệu nấu 1 mẻ: ưu tiên đồ đã sơ chế, thiếu thì lấy đồ thô (bị phạt khi nấu).
## Trả về {ok, expired, quality, raw_units, taken}; quality = chất lượng trung bình của phần đã sơ chế
## (-1 nếu toàn đồ thô); taken = {"prepped": {id: pieces}, "raw": {id: pieces}} để hoàn lại bằng refund_cook().
func consume_for_cook(requirements: Dictionary) -> Dictionary:
	if not can_cook(requirements):
		return {"ok": false, "expired": false, "quality": -1.0, "raw_units": 0, "taken": {}}
	var any_expired := false
	var q_sum := 0.0
	var q_n := 0
	var raw_units := 0
	var taken := {"prepped": {}, "raw": {}}
	for id in requirements:
		var need := int(requirements[id])
		var from_prepped := mini(need, get_prepped_count(id))
		if from_prepped > 0:
			var r := _batch_take(prepped_batches, id, from_prepped)
			any_expired = any_expired or bool(r["expired"])
			taken["prepped"][id] = r["pieces"]
			for piece in r["pieces"]:
				q_sum += float(piece.get("q", 1)) * int(piece["count"])
				q_n += int(piece["count"])
		if need > from_prepped:
			var r2 := _batch_take(item_batches, id, need - from_prepped)
			any_expired = any_expired or bool(r2["expired"])
			taken["raw"][id] = r2["pieces"]
			raw_units += need - from_prepped
	_sync_totals()
	inventory_changed.emit()
	return {"ok": true, "expired": any_expired, "quality": (q_sum / q_n) if q_n > 0 else -1.0,
		"raw_units": raw_units, "taken": taken}


## Hoàn lại đúng các phần đã lấy bằng consume_for_cook().
func refund_cook(taken: Dictionary) -> void:
	var prepped_part: Dictionary = taken.get("prepped", {})
	var raw_part: Dictionary = taken.get("raw", {})
	for id in prepped_part:
		for piece in prepped_part[id]:
			_batch_add(prepped_batches, id, int(piece["count"]), int(piece["day"]), bool(piece["expired"]), int(piece.get("q", 1)))
	for id in raw_part:
		for piece in raw_part[id]:
			_batch_add(item_batches, id, int(piece["count"]), int(piece["day"]), bool(piece["expired"]))
	_sync_totals()
	inventory_changed.emit()


## Lấy 1 phần đồ nhúng để bán (dành cho màn bán): ưu tiên đồ đã sơ chế, không có thì bán đồ thô.
## Trả về {ok, quality (-1 = thô), price_mult (nhân với giá gốc; bản hoàng kim nhân thêm GOLDEN_PRICE_MULTIPLIER), expired}.
func take_dipping(id: String) -> Dictionary:
	var cfg: PrepConfig = Database.prep_config
	if get_prepped_count(id) > 0:
		var r := _batch_take(prepped_batches, id, 1)
		var piece: Dictionary = r["pieces"][0]
		var q := int(piece.get("q", 1))
		_sync_totals()
		inventory_changed.emit()
		return {"ok": true, "quality": q, "price_mult": cfg.dipping_price_mult(q), "expired": bool(r["expired"])}
	if get_item_count(id) > 0:
		var r2 := _batch_take(item_batches, id, 1)
		_sync_totals()
		inventory_changed.emit()
		return {"ok": true, "quality": -1, "price_mult": cfg.dipping_price_mult(-1), "expired": bool(r2["expired"])}
	return {"ok": false, "quality": -1, "price_mult": 0.0, "expired": false}


# --- Nước cốt ---------------------------------------------------------------

## from_day: ngày tính hạn (mặc định hôm nay = ngày nấu). expired: nấu từ đồ hết hạn / quá hạn giữ bán tiếp.
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

## Số ngày giữ được đồ: 3 ngày + số ngày cộng thêm từ nâng cấp Kho lạnh.
func shelf_days() -> int:
	return SHELF_DAYS + int(Database.upgrade_value("cold_storage"))


## Số ngày còn dùng được của 1 lô (shelf_days() = nhập hôm nay, 1 = hôm nay là ngày cuối, <= 0 = quá hạn).
func days_left(batch: Dictionary) -> int:
	return int(batch["day"]) + shelf_days() - day


func item_batch_list(id: String) -> Array:
	return item_batches.get(id, [])


func broth_batch_list(id: String) -> Array:
	return broth_batches.get(id, [])


## Các lô vừa quá hạn mà chủ quán chưa quyết định: [{kind: "item"/"prepped"/"broth", id, day, count}].
func newly_expired() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in ["item", "prepped", "broth"]:
		var store := _store_of(kind)
		for id in store:
			for batch in store[id]:
				if not batch["expired"] and days_left(batch) <= 0:
					result.append({"kind": kind, "id": id, "day": int(batch["day"]), "count": int(batch["count"])})
	return result


## keep = true: giữ lại bán tiếp (có rủi ro bị khách phát hiện); false: bỏ đi.
func resolve_expired(kind: String, id: String, from_day: int, keep: bool) -> void:
	var store := _store_of(kind)
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


## Số lượng đồ hết hạn đang giữ trong kho (nguyên liệu thô, đã sơ chế và nồi).
func expired_stock_count() -> int:
	var n := 0
	for store in [item_batches, prepped_batches, broth_batches]:
		for id in store:
			for batch in store[id]:
				if batch["expired"]:
					n += int(batch["count"])
	return n


## Tiêu hủy toàn bộ đồ hết hạn (vd bị thanh tra tịch thu). Trả về số lượng đã hủy.
func discard_expired_stock() -> int:
	var n := 0
	for store in [item_batches, prepped_batches, broth_batches]:
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


func _store_of(kind: String) -> Dictionary:
	match kind:
		"prepped":
			return prepped_batches
		"broth":
			return broth_batches
	return item_batches


## quality >= 0 chỉ dùng cho kho đã sơ chế (khóa "q" trong lô).
func _batch_add(store: Dictionary, id: String, count: int, from_day: int, expired: bool, quality := -1) -> void:
	if count <= 0:
		return
	var d := day if from_day < 0 else from_day
	var list: Array = store.get(id, [])
	var batch := {"day": d, "count": count, "expired": expired}
	if quality >= 0:
		batch["q"] = quality
	list.append(batch)
	_merge_batches(list)
	store[id] = list


## Lấy count đơn vị: lô hết hạn / cũ nhất trước. Trả về {oldest_day, expired, pieces}.
## pieces = các phần đã lấy theo lô [{day, count, expired}] (dùng để chuyển kho hoặc hoàn lại).
func _batch_take(store: Dictionary, id: String, count: int) -> Dictionary:
	var list: Array = store.get(id, [])
	var oldest := day
	var any_expired := false
	var pieces: Array = []
	var need := count
	while need > 0 and not list.is_empty():
		var batch: Dictionary = list[0]
		var used := mini(need, int(batch["count"]))
		oldest = mini(oldest, int(batch["day"]))
		any_expired = any_expired or bool(batch["expired"])
		var piece := {"day": int(batch["day"]), "count": used, "expired": bool(batch["expired"])}
		if batch.has("q"):
			piece["q"] = int(batch["q"])
		pieces.append(piece)
		batch["count"] = int(batch["count"]) - used
		need -= used
		if int(batch["count"]) <= 0:
			list.remove_at(0)
	if list.is_empty():
		store.erase(id)
	return {"oldest_day": oldest, "expired": any_expired, "pieces": pieces}


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
		if int(prev["day"]) == int(cur["day"]) and prev["expired"] == cur["expired"] and int(prev.get("q", -1)) == int(cur.get("q", -1)):
			prev["count"] = int(prev["count"]) + int(cur["count"])
			list.remove_at(i)
		else:
			i += 1


func _sync_totals() -> void:
	inventory = _totals(item_batches)
	prepped = _totals(prepped_batches)
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
	# Nước cốt, nguyên liệu thô và đồ đã sơ chế thừa được giữ sang ngày sau, tối đa shelf_days() ngày
	# tính từ ngày nhập lô thô (sơ chế không làm mới hạn; xem newly_expired()).


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
		"prepped_batches": prepped_batches,
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
	prepped_batches = _to_batches(data.get("prepped_batches", null), {})
	_sync_totals()
	upgrades = _to_int_dict(data.get("upgrades", {}))
	tables_floor1 = mini(int(data.get("tables_floor1", START_TABLES_FLOOR1)), MAX_TABLES_FLOOR1)
	# Save cũ mua bàn kiểu cũ (chưa có nâng cấp "tables"): đổi số bàn đã mua thành cấp nâng cấp.
	if not upgrades.has("tables") and tables_floor1 > START_TABLES_FLOOR1:
		upgrades["tables"] = tables_floor1 - START_TABLES_FLOOR1
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
					var batch := {"day": int(b.get("day", day)), "count": int(b.get("count", 0)), "expired": bool(b.get("expired", false))}
					if b.has("q"):
						batch["q"] = int(b["q"])
					list.append(batch)
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
