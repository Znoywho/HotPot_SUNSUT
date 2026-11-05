class_name ChefSkill
extends RefCounted
## Một hành động của đầu bếp trong trận (đánh thường, chiêu...).
## Chiêu dùng xong phải chờ `cooldown` lượt của đầu bếp mới dùng lại.

var id := ""
var display_name := ""
var description := "" ## Hiện sẵn trên nút (không dùng tooltip).
var cooldown := 0
var cooldown_left := 0
var needs_target := true


func is_ready() -> bool:
	return cooldown_left <= 0


## Gọi đầu mỗi lượt của đầu bếp.
func tick() -> void:
	cooldown_left = maxi(0, cooldown_left - 1)


func execute(controller: BattleController, user: Combatant, target: Combatant) -> void:
	_use(controller, user, target)
	cooldown_left = cooldown


func _use(_controller: BattleController, _user: Combatant, _target: Combatant) -> void:
	pass
