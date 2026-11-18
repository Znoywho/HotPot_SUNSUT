shader_type canvas_item;
// Tô chữ logo dải màu theo chiều dọc (vàng trên, cam dưới); viền chữ giữ nguyên màu viền.
// grad_from / grad_to: toạ độ y (px trong Label) nơi dải màu bắt đầu / kết thúc.

uniform vec4 top_color : source_color = vec4(1.0, 0.88, 0.45, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.95, 0.5, 0.15, 1.0);
uniform vec4 outline_color : source_color = vec4(0.17, 0.1, 0.08, 1.0);
uniform float grad_from = 20.0;
uniform float grad_to = 70.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Lượt vẽ viền có COLOR = màu viền; lượt vẽ chữ có COLOR = trắng (font_color).
	bool is_outline = distance(COLOR.rgb, outline_color.rgb) < 0.05;
	float t = clamp((local_y - grad_from) / max(grad_to - grad_from, 1.0), 0.0, 1.0);
	vec3 fill = mix(top_color.rgb, bottom_color.rgb, t);
	COLOR = vec4(is_outline ? COLOR.rgb : fill, tex.a * COLOR.a);
}
