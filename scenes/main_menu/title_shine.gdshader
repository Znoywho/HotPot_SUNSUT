shader_type canvas_item;
// Ánh kim chạy qua logo pixel: một dải sáng xiên lướt từ trái sang phải rồi nghỉ, lặp lại.
// Chỉ phủ lên phần ruột chữ (màu sáng), không phủ viền nâu / bóng đỏ; dải sáng bám theo lưới điểm ảnh.

uniform float period = 3.5;      // giây cho một vòng (lướt + nghỉ)
uniform float sweep = 0.9;       // giây dải sáng chạy hết logo
uniform float band_width = 0.03; // nửa bề rộng dải sáng (theo bề ngang logo)
uniform float slant = 0.35;      // độ xiên của dải sáng
uniform float strength = 0.6;    // độ sáng cộng thêm ở lõi dải

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Bám lưới điểm ảnh của ảnh gốc để dải sáng cũng vuông vức như pixel art.
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE) * TEXTURE_PIXEL_SIZE;
	float t = mod(TIME, period) / sweep;                       // > 1: đang nghỉ
	float center = mix(-band_width - slant, 1.0 + band_width, t);
	float d = abs(px.x + px.y * slant - center);
	// Lõi sáng mảnh + quầng mờ hai bên (giống vệt sáng trên kim loại).
	float core = 1.0 - step(band_width * 0.35, d);
	float halo = (1.0 - smoothstep(band_width * 0.35, band_width, d)) * 0.45;
	float band = max(core, halo);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float is_fill = step(0.55, lum);                            // ruột chữ sáng; viền / bóng tối thì bỏ qua
	float glint = (t <= 1.0) ? band * is_fill * strength : 0.0;
	COLOR = vec4(tex.rgb + vec3(glint), tex.a);
}
