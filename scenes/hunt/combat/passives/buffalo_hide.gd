extends Passive
## Trâu nước (thú cưỡi) – Da dày: giảm 2 sát thương mỗi đòn đánh (ít nhất vẫn mất 1).

const FLAT_REDUCTION := 2


func modify_incoming_damage(_holder: Combatant, _battle: Battle, attacker: Combatant, amount: int) -> int:
	if attacker == null or amount <= 0:
		return amount
	return maxi(1, amount - FLAT_REDUCTION)
