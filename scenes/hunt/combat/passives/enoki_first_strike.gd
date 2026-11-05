extends Passive
## Nấm kim châm cung thủ: luôn đánh trước ở lượt đầu.


func on_battle_start(holder: Combatant, _battle: Battle) -> void:
	# Đầy ATB ngay từ đầu, cao hơn mức đầy để thắng các đơn vị khác cũng vừa đầy.
	holder.atb = Battle.ATB_FULL + 1.0
