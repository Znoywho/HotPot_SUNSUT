class_name HuntSession
extends RefCounted
## Trạng thái một buổi sáng đi săn: đầu bếp (máu giữ giữa các trận), thú cưỡi,
## các thẻ trận, số trận thắng, chuỗi thắng, boss, đồ thu hoạch.

const CONFIG_PATH := "res://data/combatants/hunt_config.tres"

var config: HuntConfig
var day := 1
var player: Combatant
var mount: Combatant ## null nếu chưa có nâng cấp thú cưỡi.
var encounters: Array[Encounter] = []
var wins := 0
var streak := 0
var boss_defeated := false
var harvest := {} ## Nguyên liệu nhận được sáng nay.
var rerolls_used := 0 ## Số lần đổi bụi cỏ hôm nay (phiên săn tạo mới mỗi sáng).
var monster_pool: Array[CombatantData] = []
var boss_pool: Array[CombatantData] = []
var stat_multiplier := 1.0


## pool để trống -> lấy từ Database theo ngày. Truyền vào để test.
func _init(p_day: int, p_config: HuntConfig = null, pool: Array[CombatantData] = [], bosses: Array[CombatantData] = []) -> void:
	day = p_day
	config = p_config if p_config != null else load(CONFIG_PATH)
	monster_pool = pool if not pool.is_empty() else Database.monsters_for_day(day, false)
	boss_pool = bosses if not bosses.is_empty() else Database.monsters_for_day(day, true)
	stat_multiplier = GameState.monster_stat_multiplier()
	player = create_player()
	mount = create_mount()
	for i in config.encounter_choices:
		encounters.append(_unique_encounter())


# --- Đơn vị phe ta ---------------------------------------------------------

func create_player() -> Combatant:
	var chef := Combatant.from_data(Database.player, true)
	chef.max_hp += roundi(Database.upgrade_value("armor") + Database.upgrade_value("battle_robe"))
	chef.hp = chef.max_hp
	chef.damage += roundi(Database.upgrade_value("knife") + Database.upgrade_value("dragon_blade"))
	chef.crit_chance = config.base_crit_chance + Database.upgrade_value("sharp_mind")
	chef.crit_multiplier = config.base_crit_multiplier + Database.upgrade_value("hawk_eye")
	return chef


func create_mount() -> Combatant:
	var level := GameState.get_upgrade_level("mount")
	if level <= 0 or config.mount == null:
		return null
	var bonus := 1.0 + config.mount_bonus_per_level * (level - 1)
	return Combatant.from_data(config.mount, true, bonus)


## Đồng minh vào trận: thú cưỡi đứng trước (chịu đòn trước), rồi đầu bếp.
func allies() -> Array[Combatant]:
	var list: Array[Combatant] = []
	if mount != null and mount.is_alive():
		list.append(mount)
	list.append(player)
	return list


func can_fight() -> bool:
	return player.is_alive()


# --- Thẻ trận ---------------------------------------------------------------

func max_enemies() -> int:
	var list := config.max_enemies_by_milestone
	if list.is_empty():
		return 2
	return list[clampi(GameState.milestones_reached(), 0, list.size() - 1)]


func generate_encounter() -> Encounter:
	var e := Encounter.new()
	e.stat_multiplier = stat_multiplier
	if monster_pool.is_empty():
		return e
	var first: CombatantData = monster_pool.pick_random()
	if first.id in config.swarm_ids:
		for i in config.swarm_size:
			e.monsters.append(first)
		return e
	e.monsters.append(first)
	var count := randi_range(1, max_enemies())
	while e.monsters.size() < count:
		var next: CombatantData = monster_pool.pick_random()
		if next.id in config.swarm_ids:
			continue # Đàn chỉ đi riêng.
		e.monsters.append(next)
	return e


## Phí lần đổi bụi cỏ tiếp theo: 0 khi còn lượt miễn phí trong ngày.
func reroll_cost() -> int:
	return 0 if rerolls_used < config.free_rerolls_per_day else config.reroll_cost


func free_rerolls_left() -> int:
	return maxi(0, config.free_rerolls_per_day - rerolls_used)


## Đổi toàn bộ thẻ trận (khi không có nguyên liệu phù hợp). Trả về false nếu không đủ tiền.
func reroll_encounters() -> bool:
	var cost := reroll_cost()
	if cost > 0 and not GameState.spend_money(cost):
		return false
	rerolls_used += 1
	for i in encounters.size():
		encounters[i] = null
	for i in encounters.size():
		encounters[i] = _unique_encounter(i)
	return true


## Tạo thẻ mới không trùng với các thẻ đang hiện (thử vài lần, quái ít thì chấp nhận trùng).
func _unique_encounter(skip_index := -1) -> Encounter:
	var e := generate_encounter()
	for attempt in 8:
		var duplicate := false
		for i in encounters.size():
			if i != skip_index and encounters[i] != null and encounters[i].names() == e.names():
				duplicate = true
				break
		if not duplicate:
			break
		e = generate_encounter()
	return e


## Thay thẻ vừa đánh bằng thẻ mới.
func replace_encounter(index: int) -> void:
	if index >= 0 and index < encounters.size():
		encounters[index] = _unique_encounter(index)


func boss_unlocked() -> bool:
	return not boss_defeated and wins >= config.boss_unlock_wins and not boss_pool.is_empty()


func boss_encounter() -> Encounter:
	var e := Encounter.new()
	e.is_boss = true
	e.stat_multiplier = stat_multiplier
	if not boss_pool.is_empty():
		e.monsters.append(boss_pool.pick_random())
	return e


# --- Kết thúc trận ----------------------------------------------------------

## Ghi nhận kết quả, trả về đồ rơi (đã cộng vào kho GameState).
func finish_battle(controller: BattleController, encounter: Encounter) -> Dictionary:
	var drops := {}
	match controller.result:
		BattleController.Result.WIN:
			drops = roll_drops(controller.battle.enemies, encounter.is_boss)
			wins += 1
			streak += 1
			if encounter.is_boss:
				boss_defeated = true
			# Ăn vội miếng lẩu sau trận thắng.
			for c in [player, mount]:
				if c != null and c.is_alive():
					c.heal(roundi(c.max_hp * config.heal_after_win))
			for id in drops:
				GameState.add_item(id, drops[id])
				harvest[id] = int(harvest.get(id, 0)) + int(drops[id])
		_:
			streak = 0
	return drops


func current_drop_chance() -> float:
	var chance := config.drop_chance
	chance += config.knife_drop_bonus * GameState.get_upgrade_level("knife")
	chance += minf(config.streak_bonus_per_win * streak, config.streak_bonus_max)
	return clampf(chance, 0.0, 1.0)


## Hệ số lượng rơi: cấu hình chung x thưởng theo mốc ngày.
func drop_amount_multiplier() -> float:
	return config.drop_amount_multiplier * (1.0 + config.milestone_amount_bonus * GameState.milestones_reached())


## Tung đồ rơi cho mọi quái đã bị hạ (kể cả nấm con tách ra giữa trận).
func roll_drops(enemies: Array[Combatant], boss_fight: bool) -> Dictionary:
	var drops := {}
	var chance := current_drop_chance()
	var amount_mult := drop_amount_multiplier()
	for e in enemies:
		if e.is_alive() or e.data == null:
			continue
		var is_boss := e.data.is_boss
		for id in e.data.drops:
			if not is_boss and randf() >= chance:
				continue
			var item_id: String = id
			# Đồ hoàng kim (boss) giữ nguyên số lượng để còn quý.
			var mult := 1.0 if item_id.begins_with(GameState.GOLDEN_PREFIX) else amount_mult
			var amount := maxi(1, roundi(int(e.data.drops[id]) * mult))
			# Quái thường: hiếm khi rơi bản hoàng kim (giá x3).
			if not is_boss and not item_id.begins_with(GameState.GOLDEN_PREFIX) and randf() < config.golden_chance:
				var golden := GameState.GOLDEN_PREFIX + item_id
				drops[golden] = int(drops.get(golden, 0)) + 1
				amount -= 1
			if amount > 0:
				drops[item_id] = int(drops.get(item_id, 0)) + amount
	return drops


## Nguyên liệu còn thiếu cho các nồi lẩu hôm nay (mỗi loại 1 nồi) - để gợi ý săn.
func recipe_hints() -> Array[String]:
	var hints: Array[String] = []
	for broth in Database.broths_for_day(day):
		var parts: Array[String] = []
		for id in broth.ingredients:
			var have := GameState.get_item_count(id)
			parts.append("%s %d/%d" % [GameState.item_display_name(id), mini(have, int(broth.ingredients[id])), int(broth.ingredients[id])])
		hints.append("%s: %s" % [broth.display_name, ", ".join(parts)])
	return hints
