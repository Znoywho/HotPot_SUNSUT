extends Passive
## Người chơi – Linh hồn đầu bếp: lần thua đầu tiên được hồi 100 máu, nhân đôi dame và tốc đánh.
## TODO(Hải): override on_death(): nếu chưa dùng -> holder.hp = mini(100, holder.max_hp),
##   holder.damage *= 2, holder.speed *= 2, đánh dấu đã dùng, return true.
##   Chốt với nhóm: 'lần đầu' tính theo trận, theo buổi săn hay cả game?
