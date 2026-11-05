extends Passive
## Boss Vua Cà Chua – Nước sốt hồi sinh: đầu mỗi lượt hồi 1% máu tối đa.
## 3% thì người chơi gốc không thể thắng (test 0/300 trận) vì boss xuất hiện từ ngày 1.

const REGEN_RATIO := 0.01


func on_turn_start(holder: Combatant, battle: Battle) -> void:
	if holder.hp >= holder.max_hp:
		return
	var before := holder.hp
	holder.heal(maxi(1, roundi(holder.max_hp * REGEN_RATIO)))
	battle.add_log("%s hồi %d máu nhờ nước sốt (còn %d/%d)" % [holder.display_name, holder.hp - before, holder.hp, holder.max_hp])
