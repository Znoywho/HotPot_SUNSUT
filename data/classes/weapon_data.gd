class_name WeaponData
extends Resource
## Một vũ khí trong tab Vũ khí của cửa hàng: mua một lần, chọn 1 cái để cầm khi đi săn.
## Chỉ số cộng thẳng vào đầu bếp khi vào trận (HuntSession.create_player), cộng chung với nâng cấp Dao / Giáp.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 0 ## 0 = có sẵn từ đầu.
@export var damage_bonus: int = 0
@export var speed_bonus: int = 0 ## Âm = vung chậm hơn (tới lượt ít hơn).
@export var crit_chance_bonus: float = 0.0 ## 0.05 = +5% chí mạng.
