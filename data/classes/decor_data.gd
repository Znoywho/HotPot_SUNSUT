class_name DecorData
extends Resource
## Một món đồ trang trí ở tab Trang trí của cửa hàng: mua một lần, mỗi chỗ trong quán (slot) đặt 1 món.
## Hình vẽ bằng DecorArt theo slot + style. Món đang đặt cộng tip_bonus vào tỉ lệ tip ở màn bán.

@export var id: String = ""
@export var slot: String = "" ## clock / painting / shelf / cat / corner / door (xem DecorArt.BOX)
@export var style: String = "" ## Kiểu vẽ trong DecorArt cho slot này.
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 0
@export var tip_bonus: float = 0.01 ## 0.01 = +1% tip khi món đang đặt trong quán.
