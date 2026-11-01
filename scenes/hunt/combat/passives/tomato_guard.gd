extends Passive
## Chiến binh cà chua: dưới 25% máu thì nhận giáp bằng 10% máu tối đa (1 lần/trận).
## TODO(Hải): override on_damaged(): nếu chưa kích hoạt và holder.hp < holder.max_hp * 0.25
##   -> holder.armor += roundi(holder.max_hp * 0.1), đánh dấu đã kích hoạt, battle.add_log(...).
