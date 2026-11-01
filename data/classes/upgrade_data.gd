class_name UpgradeData
extends Resource
## Một nâng cấp trong cửa hàng. Cấp 0 = chưa mua.
## costs[i] = giá để lên cấp i + 1  ->  số cấp tối đa = costs.size()
## values[i] = giá trị hiệu ứng ở cấp i (values[0] là giá trị lúc chưa nâng).

enum Category { KITCHEN, COMBAT, RESTAURANT }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.KITCHEN
@export var costs: Array[int] = []
@export var values: Array[float] = []
@export var evolves_into: String = "" ## id nâng cấp mở khóa khi max cấp (vd Bếp hoàng kim).


func max_level() -> int:
	return costs.size()


## Giá lên cấp tiếp theo, -1 nếu đã max.
func cost_for_next(current_level: int) -> int:
	if current_level >= costs.size():
		return -1
	return costs[current_level]


func value_at(level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(level, 0, values.size() - 1)]
