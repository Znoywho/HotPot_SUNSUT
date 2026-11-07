class_name HuntConfig
extends Resource
## Số liệu cân bằng của buổi săn (khu săn, chiêu đầu bếp, đồ rơi, thú cưỡi).
## Chỉnh trong Inspector: data/combatants/hunt_config.tres

@export_group("Khu săn")
@export var encounter_choices := 3 ## Số thẻ trận hiện cùng lúc.
@export var max_enemies_by_milestone: Array[int] = [2, 2, 3, 3] ## Số quái tối đa / trận theo mốc ngày (0, 5, 10, 15+).
@export var swarm_ids: Array[String] = ["cherry_tomato_swarm"] ## Quái luôn đi theo đàn.
@export var swarm_size := 3
@export var boss_unlock_wins := 3 ## Thắng bao nhiêu trận thì mở boss (1 lần / buổi sáng).
@export var free_rerolls_per_day := 3 ## Đổi bụi cỏ miễn phí mỗi ngày.
@export var reroll_cost := 50000 ## Phí mỗi lần đổi sau khi hết lượt miễn phí.
@export var heal_after_win := 0.15 ## "Ăn vội miếng lẩu": thắng trận thì đầu bếp + thú cưỡi hồi % máu tối đa.

@export_group("Đầu bếp")
@export var base_crit_chance := 0.05
@export var base_crit_multiplier := 1.5

@export_group("Chiêu: Thái lát")
@export var slice_hits := 2
@export var slice_damage_ratio := 0.6
@export var slice_cooldown := 3

@export_group("Chiêu: Hất lẩu nóng")
@export var splash_damage := 8
@export var splash_burn_turns := 2
@export var splash_cooldown := 4

@export_group("Đồ rơi")
@export var drop_chance := 0.9 ## Tỷ lệ rơi mỗi loại nguyên liệu của quái thường (boss luôn rơi).
@export var drop_amount_multiplier := 3.0 ## Nhân lượng rơi của mọi quái (2 -> 6, 1 -> 3). Mỗi nồi lẩu tốn 2–3 nguyên liệu.
@export var knife_drop_bonus := 0.03 ## + tỷ lệ rơi mỗi cấp Dao bén.
@export var milestone_amount_bonus := 0.25 ## + lượng rơi mỗi mốc ngày (x1.25, x1.5...).
@export var golden_chance := 0.03 ## Quái thường: tỷ lệ 1 nguyên liệu biến thành bản hoàng kim.
@export var streak_bonus_per_win := 0.05 ## Chuỗi thắng: + tỷ lệ rơi mỗi trận thắng liên tiếp.
@export var streak_bonus_max := 0.2

@export_group("Thú cưỡi")
@export var mount: CombatantData ## Thú cưỡi (mở khi có nâng cấp "mount").
@export var mount_bonus_per_level := 0.25 ## + máu/dame thú cưỡi mỗi cấp trên cấp 1.

@export_group("Nhịp trận")
@export var action_delay := 0.45 ## Giây chờ giữa các hành động (chia cho tốc độ x2).
