extends Passive
## Bò tót điên: bị đánh thì tích nội năng, khi chết phát nổ gây 5 dame lên toàn bộ kẻ địch.
## TODO(Hải): on_damaged() -> tích nội năng (doc chưa ghi nội năng dùng làm gì, chốt với nhóm).
##   on_death() -> với mỗi c trong battle.opponents_of(holder): c.take_damage(battle, null, 5); return false.
