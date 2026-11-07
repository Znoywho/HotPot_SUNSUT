extends Node
## Danh sách dữ liệu game (autoload: Database).
## Thêm file .tres mới (quái, nước cốt, nâng cấp) thì nhớ thêm vào đây.

var player: CombatantData = preload("res://data/combatants/player.tres")

var monsters: Array[CombatantData] = [
	preload("res://data/combatants/tomato_warrior.tres"),
	preload("res://data/combatants/mushroom_healer.tres"),
	preload("res://data/combatants/mad_bull.tres"),
	preload("res://data/combatants/jumping_shrimp.tres"),
	preload("res://data/combatants/greens_mage.tres"),
	preload("res://data/combatants/enoki_archer.tres"),
	preload("res://data/combatants/boss_tomato_king.tres"),
	# Quái chủ đề lẩu (Hải).
	preload("res://data/combatants/water_spinach_vine.tres"),
	preload("res://data/combatants/cherry_tomato_swarm.tres"),
	preload("res://data/combatants/bouncy_beef_ball.tres"),
	preload("res://data/combatants/armored_lobster.tres"),
	preload("res://data/combatants/splitting_mushroom.tres"),
	preload("res://data/combatants/angry_chili.tres"),
	preload("res://data/combatants/tentacle_squid.tres"),
	preload("res://data/combatants/shy_clam.tres"),
	preload("res://data/combatants/napa_cabbage.tres"),
	preload("res://data/combatants/sleepy_shiitake.tres"),
	preload("res://data/combatants/beef_enoki_roll.tres"),
	preload("res://data/combatants/boss_beef_lord.tres"),
	preload("res://data/combatants/boss_hotpot_golem.tres"),
]

var broths: Array[BrothData] = [
	preload("res://data/broths/tomato_broth.tres"),
	preload("res://data/broths/mushroom_broth.tres"),
	preload("res://data/broths/spicy_broth.tres"),
	preload("res://data/broths/seafood_broth.tres"),
	preload("res://data/broths/royal_broth.tres"),
]

var upgrades: Array[UpgradeData] = [
	preload("res://data/upgrades/pot.tres"),
	preload("res://data/upgrades/stove.tres"),
	preload("res://data/upgrades/knife.tres"),
	preload("res://data/upgrades/armor.tres"),
	preload("res://data/upgrades/furniture.tres"),
	preload("res://data/upgrades/staff.tres"),
	preload("res://data/upgrades/cold_storage.tres"),
]


## Sơ chế nguyên liệu (data/prep/): quy trình từng nguyên liệu + số liệu chấm điểm / chất lượng.
var prep_config: PrepConfig = preload("res://data/prep/prep_config.tres")
var prep_recipes: Array[PrepRecipeData] = [
	preload("res://data/prep/tomato.tres"),
	preload("res://data/prep/mushroom.tres"),
	preload("res://data/prep/shiitake.tres"),
	preload("res://data/prep/enoki.tres"),
	preload("res://data/prep/beef.tres"),
	preload("res://data/prep/beef_ball.tres"),
	preload("res://data/prep/beef_roll.tres"),
	preload("res://data/prep/shrimp.tres"),
	preload("res://data/prep/squid.tres"),
	preload("res://data/prep/clam.tres"),
	preload("res://data/prep/greens.tres"),
	preload("res://data/prep/napa_cabbage.tres"),
	preload("res://data/prep/water_spinach.tres"),
	preload("res://data/prep/chili.tres"),
]


## Quy trình sơ chế của 1 nguyên liệu (bỏ tiền tố prepped_ / golden_: bản hoàng kim dùng chung quy trình). null nếu không có.
func prep_recipe_for(id: String) -> PrepRecipeData:
	var base := id.trim_prefix(GameState.PREPPED_PREFIX).trim_prefix(GameState.GOLDEN_PREFIX)
	for r in prep_recipes:
		if r.ingredient_id == base:
			return r
	return null


func monsters_for_day(day: int, bosses: bool) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for m in monsters:
		if m.is_boss == bosses and m.min_day <= day:
			result.append(m)
	return result


func broths_for_day(day: int) -> Array[BrothData]:
	var result: Array[BrothData] = []
	for b in broths:
		if b.unlock_day <= day:
			result.append(b)
	return result


func get_broth(id: String) -> BrothData:
	for b in broths:
		if b.id == id:
			return b
	return null


func get_upgrade(id: String) -> UpgradeData:
	for u in upgrades:
		if u.id == id:
			return u
	return null


## Giá trị hiệu ứng của nâng cấp ở cấp hiện tại (vd knife -> +dame).
func upgrade_value(id: String) -> float:
	var upgrade := get_upgrade(id)
	if upgrade == null:
		return 0.0
	return upgrade.value_at(GameState.get_upgrade_level(id))
