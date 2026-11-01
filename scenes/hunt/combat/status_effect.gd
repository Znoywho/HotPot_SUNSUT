class_name StatusEffect
extends RefCounted
## Hiệu ứng trạng thái kéo dài nhiều lượt (độc, đốt...). Kích hoạt đầu lượt của mục tiêu.

var turns_left := 1


func _init(duration := 1) -> void:
	turns_left = duration


func on_turn_start(_target: Combatant, _battle: Battle) -> void:
	pass
