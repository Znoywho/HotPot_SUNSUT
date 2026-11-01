class_name CombatantData
extends Resource
## Chỉ số gốc của một đơn vị chiến đấu: quái, boss, người chơi, (sau này) nhân viên, thú cưỡi.
## Tạo file .tres mới trong data/combatants/ rồi thêm vào autoload/database.gd.

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 100
@export var damage: int = 10
@export var speed: int = 10 ## Tốc đánh: càng cao càng được hành động sớm và nhiều.
@export var passive: Script ## Script kế thừa Passive (để trống nếu không có nội tại).
@export var drops: Dictionary = {} ## id nguyên liệu -> số lượng rơi khi bị hạ.
@export var is_boss := false
@export var min_day := 1 ## Bắt đầu xuất hiện từ ngày này.
