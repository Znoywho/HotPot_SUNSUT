class_name PoisonEffect
extends StatusEffect
## Độc: mất 2% máu tối đa mỗi lượt.
## TODO(Hải): override on_turn_start(target, battle):
##   target.take_damage(battle, null, maxi(1, roundi(target.max_hp * 0.02)))
