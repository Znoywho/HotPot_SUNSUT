class_name BasicAttackSkill
extends ChefSkill
## Đánh thường 1 mục tiêu.


func _init() -> void:
	id = "basic"
	display_name = "Đánh thường"
	description = "Đánh 1 mục tiêu"


func _use(controller: BattleController, user: Combatant, target: Combatant) -> void:
	controller.attack(user, target)
