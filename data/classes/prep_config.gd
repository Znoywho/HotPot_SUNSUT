class_name PrepConfig
extends Resource
## Số liệu cân bằng của hệ thống sơ chế (data/prep/prep_config.tres).
## Chất lượng: 0 = Kém, 1 = Thường, 2 = Thượng hạng (GameState.QUALITY_NAMES).

@export_group("Chấm điểm")
@export var perfect_score := 85 ## Điểm bước >= mức này: Hoàn hảo (2).
@export var ok_score := 50 ## >= mức này: Ổn (1); thấp hơn: Hỏng (0).
@export var premium_average := 1.6 ## Trung bình các bước (Hoàn hảo 2, Ổn 1, Hỏng 0) >= mức này: Thượng hạng.
@export var normal_average := 0.9 ## >= mức này: Thường; thấp hơn: Kém.
@export var ruin_fails := 3 ## Số bước Hỏng >= mức này: hỏng nặng, mất cả lượt nguyên liệu.
@export var optional_skip_grade := 1 ## Bỏ qua bước tùy chọn tính như "Ổn".

@export_group("Lượt sơ chế")
@export var session_max := 5 ## Mỗi lượt minigame sơ chế tối đa bấy nhiêu phần cùng lúc.

@export_group("Sơ chế nhanh")
@export var quick_quality := 0 ## Chất lượng của "Sơ chế nhanh tất cả" và của phụ bếp.
@export var quick_seconds_per_unit := 0.35 ## Thời gian sơ chế nhanh cho mỗi phần (giờ trong ngày vẫn chạy).
@export var quick_max_seconds := 6.0 ## Sơ chế nhanh tối đa bấy nhiêu giây dù nhiều đồ.

@export_group("Ảnh hưởng của chất lượng")
@export var cook_time_by_quality := PackedFloat32Array([1.1, 1.0, 0.85]) ## Hệ số thời gian nấu nước cốt (Kém, Thường, Thượng hạng).
@export var raw_cook_time := 1.25 ## Nấu bằng đồ chưa sơ chế: chậm hơn.
@export var raw_star_risk := 0.2 ## Nấu bằng đồ chưa sơ chế: xác suất khách chê, mất sao.
@export var raw_star_loss := 0.5
@export var dipping_price_by_quality := PackedFloat32Array([0.85, 1.0, 1.2]) ## Hệ số giá đồ nhúng (Kém, Thường, Thượng hạng).
@export var raw_dipping_price := 0.7 ## Đồ nhúng bán thô, chưa sơ chế.

@export_group("Dao bén")
@export var knife_ease_per_level := 0.12 ## Mỗi cấp Dao bén giảm độ khó các bước cắt/thái bấy nhiêu (tỉ lệ).
@export var knife_ease_max := 0.5

@export_group("Thao tác")
@export var hold_zone := 0.35 ## hold_wash: vùng xanh dài bằng tỉ lệ này của thời gian giữ (chia cho độ khó).
@export var tap_radius := 42.0 ## tap_targets: bán kính điểm chạm (px, chia cho độ khó, tối thiểu 24).
@export var pull_distance := 150.0 ## drag_pull: kéo xa bấy nhiêu px là ra.
@export var pull_max_speed := 1100.0 ## drag_pull: kéo nhanh hơn (px/giây, chia cho độ khó) thì đứt.
@export var swipe_tolerance := 30.0 ## swipe_cut: lệch trung bình tối đa so với đường chấm (px, chia cho độ khó).
@export var stage_zone := 0.22 ## timed_stage: bề rộng vùng xanh (tỉ lệ thanh, chia cho độ khó).
@export var stage_max_misses := 3 ## timed_stage: trượt bấy nhiêu lần thì bước kết thúc.


## Điểm bước (0..100) -> 2 Hoàn hảo / 1 Ổn / 0 Hỏng.
func grade_of(score: int) -> int:
	if score >= perfect_score:
		return 2
	return 1 if score >= ok_score else 0


## Trung bình điểm các bước -> chất lượng cuối.
func quality_of(average: float) -> int:
	if average >= premium_average:
		return 2
	return 1 if average >= normal_average else 0


func cook_time_mult(quality: int) -> float:
	return cook_time_by_quality[clampi(quality, 0, cook_time_by_quality.size() - 1)]


func dipping_price_mult(quality: int) -> float:
	if quality < 0:
		return raw_dipping_price
	return dipping_price_by_quality[clampi(quality, 0, dipping_price_by_quality.size() - 1)]
