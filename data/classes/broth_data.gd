class_name BrothData
extends Resource
## Một loại nước cốt lẩu.

@export var id: String = ""
@export var display_name: String = ""
@export var ingredients: Dictionary = {} ## id nguyên liệu -> số lượng cần cho 1 nồi.
@export var cook_time := 10.0 ## Giây để nấu 1 nồi ở bếp cấp 0.
@export var price: int = 100_000 ## Giá bán 1 nồi.
@export var unlock_day := 1 ## Mở khóa từ ngày (mốc 5, 10, 15...).
