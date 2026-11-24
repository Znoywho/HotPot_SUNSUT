shader_type canvas_item;
// "Impact frame" kiểu anime cho cú kết liễu boss / bò tót nổ: cả màn chỉ còn 2 màu theo độ sáng
// (tối / kem), khung sau đảo ngược (invert = true). Chỉ hiện 2 khung rất ngắn (BattleJuice.impact_frame).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform bool invert = false;
uniform float threshold = 0.42;
uniform vec4 dark_color : source_color = vec4(0.07, 0.04, 0.05, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	bool light = invert ? (l <= threshold) : (l > threshold);
	COLOR = light ? light_color : dark_color;
}
