class_name PrepRecipeData
extends Resource
## Quy trình sơ chế 1 nguyên liệu (data/prep/<id>.tres). Bản hoàng kim (golden_<id>) dùng chung quy trình bản thường.

@export var ingredient_id := ""
@export var steps: Array[PrepStepData] = []
