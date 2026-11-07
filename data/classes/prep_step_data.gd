class_name PrepStepData
extends Resource
## Một bước sơ chế (vd "Khía chữ thập"). Mỗi bước dùng 1 trong 5 kiểu thao tác chung (scenes/cook/prep_actions/).
## Điểm bước: 100 - penalty × số lỗi (thang 0..100), đổi sang Hoàn hảo / Ổn / Hỏng theo data/prep/prep_config.tres.

const HOLD_WASH := "hold_wash" ## Giữ để rửa/ngâm đủ lâu (thả trong vùng xanh; quá lâu bị trừ).
const TAP_TARGETS := "tap_targets" ## Chạm đúng các điểm (cuống, túi mực, lá úa...); chạm trượt bị trừ.
const DRAG_PULL := "drag_pull" ## Kéo một bộ phận ra theo mũi tên; kéo quá nhanh thì đứt.
const SWIPE_CUT := "swipe_cut" ## Vuốt theo đường chấm để cắt/khía/thái; lệch đường bị trừ.
const TIMED_STAGE := "timed_stage" ## Bấm "Xong!" khi kim nằm trong vùng xanh (chần, ướp, ngâm, để ráo).

@export var title := "" ## Tên bước hiện trên bảng, vd "Khía chữ thập".
@export_enum("hold_wash", "tap_targets", "drag_pull", "swipe_cut", "timed_stage", "scrub", "roll_ball", "skewer") var kind: String = "hold_wash"
@export_multiline var hint := "" ## Hướng dẫn ngắn dưới tên bước.
@export var duration := 1.5 ## Giây: thời gian giữ cần thiết (hold_wash) hoặc chu kỳ kim chạy (timed_stage).
@export var count := 1 ## Số điểm chạm (tap_targets) / số lần kéo (drag_pull) / số đường cắt (swipe_cut).
@export var difficulty := 1.0 ## > 1 khó hơn: vùng xanh hẹp hơn, điểm chạm nhỏ hơn, dễ đứt hơn, đường cắt khắt khe hơn.
@export var penalty := 20 ## Điểm bị trừ mỗi lỗi (thang 100).
@export var optional := false ## Bước tùy chọn: có nút "Bỏ qua".
@export var cut := false ## Bước dùng dao (cắt/thái/khía): nâng cấp Dao bén làm dễ hơn.
@export_enum("board", "sink", "pot", "bowl", "basket") var prop: String = "board" ## Dụng cụ vẽ dưới nguyên liệu.
@export_enum("slices", "cross") var pattern: String = "slices" ## swipe_cut: các nhát song song hay hình chữ thập.
