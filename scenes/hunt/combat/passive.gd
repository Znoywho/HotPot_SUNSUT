class_name Passive
extends RefCounted
## Nội tại. Mỗi loại quái có 1 script kế thừa class này và override hook cần dùng.
## Tham số holder = đơn vị sở hữu nội tại. Giữ trạng thái riêng (vd đã kích hoạt chưa) trong biến của script con.


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	pass


## Đầu lượt của holder, trước khi hành động.
func on_turn_start(_holder: Combatant, _battle: Battle) -> void:
	pass


## Sau khi holder đánh trúng target (damage = máu target thực sự mất).
func on_hit_dealt(_holder: Combatant, _battle: Battle, _target: Combatant, _damage: int) -> void:
	pass


## Sửa sát thương holder sắp nhận. Trả về 0 để né đòn.
func modify_incoming_damage(_holder: Combatant, _battle: Battle, _attacker: Combatant, amount: int) -> int:
	return amount


## Sau khi holder nhận sát thương.
func on_damaged(_holder: Combatant, _battle: Battle, _attacker: Combatant, _amount: int) -> void:
	pass


## Khi máu holder về 0. Trả về true để HỦY cái chết (nhớ đặt lại holder.hp > 0).
func on_death(_holder: Combatant, _battle: Battle) -> bool:
	return false
