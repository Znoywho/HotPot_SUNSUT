class_name Encounter
extends RefCounted
## Một thẻ trận trên khu săn: danh sách quái sẽ gặp.

enum Difficulty { EASY, MEDIUM, HARD }

var monsters: Array[CombatantData] = []
var is_boss := false
var stat_multiplier := 1.0


func create_enemies() -> Array[Combatant]:
	var list: Array[Combatant] = []
	for m in monsters:
		list.append(Combatant.from_data(m, false, stat_multiplier))
	return list


## Đồ rơi dự kiến (tối đa, chưa tính tỷ lệ), đã nhân hệ số lượng rơi.
func expected_drops(amount_multiplier := 1.0) -> Dictionary:
	var drops := {}
	for m in monsters:
		for id in m.drops:
			var golden := String(id).begins_with(GameState.GOLDEN_PREFIX)
			var amount := maxi(1, roundi(int(m.drops[id]) * (1.0 if golden else amount_multiplier)))
			drops[id] = int(drops.get(id, 0)) + amount
	return drops


## Độ khó so với sức đầu bếp: tổng (máu x dame) của quái / (máu x dame) của đầu bếp.
func difficulty(player: Combatant) -> Difficulty:
	var threat := 0.0
	for m in monsters:
		threat += m.max_hp * stat_multiplier * m.damage * stat_multiplier
	var power := maxf(1.0, player.max_hp * player.damage)
	var ratio := threat / power
	if ratio < 0.45:
		return Difficulty.EASY
	if ratio < 0.9:
		return Difficulty.MEDIUM
	return Difficulty.HARD


static func difficulty_name(d: Difficulty) -> String:
	return ["Dễ", "Vừa", "Khó"][d]


func names() -> String:
	var counts := {}
	var order: Array[String] = []
	for m in monsters:
		if not counts.has(m.display_name):
			order.append(m.display_name)
		counts[m.display_name] = int(counts.get(m.display_name, 0)) + 1
	var parts: Array[String] = []
	for n in order:
		parts.append(n if counts[n] == 1 else "%s x%d" % [n, counts[n]])
	return " + ".join(parts)
