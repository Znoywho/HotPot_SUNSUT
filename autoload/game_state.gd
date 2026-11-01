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
}
const GOLDEN_PREFIX := "golden_" ## vd "golden_tomato" = cà chua hoàng kim.
const GOLDEN_PRICE_MULTIPLIER := 3.0

var money: int
var day: int
var kpi_target: int
var today_revenue: int
var stars: float
var stars_lost_today: int
var customer_multiplier: float
var inventory: Dictionary ## id nguyên liệu (String) -> số lượng
var broths: Dictionary ## id nước cốt (String) -> số nồi đã nấu
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


func add_item(id: String, count := 1) -> void:
	inventory[id] = get_item_count(id) + count
	inventory_changed.emit()


func has_items(requirements: Dictionary) -> bool:
	for id in requirements:
		if get_item_count(id) < int(requirements[id]):
			return false
	return true


## Trừ nguyên liệu theo công thức. Thiếu thì trả về false và không trừ gì.
func consume_items(requirements: Dictionary) -> bool:
	if not has_items(requirements):
		return false
	for id in requirements:
		inventory[id] -= int(requirements[id])
		if inventory[id] <= 0:
			inventory.erase(id)
	inventory_changed.emit()
	return true


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

func add_broth(id: String, count := 1) -> void:
	broths[id] = get_broth_count(id) + count
	inventory_changed.emit()


func get_broth_count(id: String) -> int:
	return broths.get(id, 0)


func take_broth(id: String) -> bool:
	if get_broth_count(id) <= 0:
		return false
	broths[id] -= 1
	if broths[id] <= 0:
		broths.erase(id)
	inventory_changed.emit()
	return true


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
	# TODO(nhóm): nước cốt thừa có giữ sang ngày sau không? Hiện tại đang giữ.


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
	inventory = _to_int_dict(data.get("inventory", {}))
	broths = _to_int_dict(data.get("broths", {}))
	upgrades = _to_int_dict(data.get("upgrades", {}))
	tables_floor1 = int(data.get("tables_floor1", START_TABLES_FLOOR1))
	tables_floor2 = int(data.get("tables_floor2", 0))
	money_changed.emit(money)
	inventory_changed.emit()
	stars_changed.emit(stars)


## JSON đọc số thành float -> đổi lại về int.
func _to_int_dict(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key in source:
			result[str(key)] = int(source[key])
	return result
