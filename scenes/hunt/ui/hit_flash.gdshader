shader_type canvas_item;
// Nháy màu cho sprite trong trận: trúng đòn (trắng rồi đỏ), quái báo trước đòn (đỏ), hồi sinh (vàng).
// Trộn màu sprite với flash_color theo flash (0..1), giữ nguyên độ trong nên viền hình vẫn sắc.
// Lớp animation con (SpriteFrameLayer) đặt use_parent_material = true để nháy cùng.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
