extends Passive
## Tôm hùm giáp: vỏ cứng, giảm 4 sát thương mỗi đòn đánh (ít nhất vẫn mất 1).
## Không giảm sát thương hiệu ứng (độc, đốt, nổ...) -> khắc chế bằng hiệu ứng.

const FLAT_REDUCTION := 4


func modify_incoming_damage(_holder: Combatant, _battle: Battle, attacker: Combatant, amount: int) -> int:
	if attacker == null or amount <= 0:
		return amount
	return maxi(1, amount - FLAT_REDUCTION)
