shader_type canvas_item;
// canvas_ui_phase_bubbles.gdshader (Lê Thiên Hạo, S16 v2: chuyển cảnh giữa các buổi).
// "Sôi sùng sục": bọt sôi pixel trồi từ đáy màn, phình to rồi nhập lại phủ kín (progress 0 -> 1);
// đổi màn xong thì bọt vỡ từ dưới lên, lộ màn mới (progress 1 -> 2).
// Gắn vào gốc PhaseTransition; mọi node con đặt use_parent_material = true nên cùng bị che theo
// MỘT mặt nạ tính bằng toạ độ màn hình: trời, đồi, chữ... cùng hiện trong bọt.
// Nền tảng: renderer Compatibility (WebGL 2), máy tính + điện thoại.
// Chi phí mỗi pixel: 9 bọt lân cận (vòng lặp cố định, không đọc texture trong vòng lặp),
// không discard, không rẽ nhánh theo pixel (chỉ step / smoothstep / mix).
// Toạ độ vị trí lên tới ~2000 đơn vị nên giữ độ chính xác mặc định (highp), không dùng mediump.

group_uniforms Progress;
/** 0..1: bọt phồng dần rồi phủ kín; 1..2: bọt vỡ dần lộ màn mới. */
uniform float progress : hint_range(0.0, 2.0) = 0.0;

group_uniforms Layout;
/** Kích thước vùng nhìn thấy theo đơn vị canvas (vd 1280x720); mọi cỡ bên dưới tính theo đơn vị này. */
uniform vec2 screen_size = vec2(1280.0, 720.0);
/** Cỡ một ô lưới bọt; mỗi ô có đúng một bọt. */
uniform float cell_size : hint_range(32.0, 400.0) = 112.0;
/** Cỡ một điểm ảnh art (sprite phóng 4 lần): mép bọt bám lưới này nên răng cưa kiểu pixel. */
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
/** 1 nếu SCREEN_UV.y tăng từ dưới lên (tuỳ renderer), 0 nếu tăng từ trên xuống. */
uniform float uv_y_up : hint_range(0.0, 1.0, 1.0) = 0.0;

group_uniforms Timing;
/** Bọt hàng dưới phồng sớm hơn hàng trên bao nhiêu (theo thang progress). */
uniform float rise_spread : hint_range(0.0, 1.0) = 0.55;
/** Trễ ngẫu nhiên thêm cho mỗi bọt (theo thang progress). */
uniform float jitter : hint_range(0.0, 1.0) = 0.25;
/** Một bọt phồng (hoặc vỡ) hết trong bao nhiêu (theo thang progress). */
uniform float grow_span : hint_range(0.05, 1.0) = 0.35;

group_uniforms Look;
/** Viền sáng 1 điểm ảnh quanh khối bọt đang phồng / quanh lỗ đang vỡ; bọt đang vỡ cũng ngả dần về màu này. */
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.82, 0.9);
/** Đốm bóng góc trên-trái của bọt đang phồng. */
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
group_uniforms;

// Tâm bọt nằm trong [0.35, 0.65] của ô: điểm xa tâm gần nhất nhất là góc ô, cách 0.65·√2 ≈ 0.92 ô,
// nên bán kính 0.95 ô luôn phủ kín màn khi mọi bọt đã phồng hết.
const float CENTER_MIN = 0.35;
const float CENTER_RANGE = 0.30;
const float MAX_RADIUS = 0.95;
// Bọt trồi lên bao nhiêu ô khi phồng. Ràng buộc: bán kính lúc vọt (0.95·1.1) + RISE + 0.65 ≤ 2 ô,
// để mọi pixel bọt phủ tới đều nằm trong vùng 3×3 ô quanh pixel đó (bọt không bị cắt thẳng).
const float RISE = 0.3;
const float BACK_C1 = 1.70158;      // độ vọt của easing back-out (~10%)
const float HIGHLIGHT_OFFSET = 0.42; // đốm bóng lệch về góc trên-trái, tính theo bán kính
const float HIGHLIGHT_RADIUS = 0.12;
const float RIM_FADE_FROM = 0.7;    // viền mờ dần từ 70% độ phồng: phủ kín thì không còn đường viền nào
const float SHINE_FADE_FROM = 0.2;  // đốm bóng chỉ có ở bọt mới nhú (mép bọt đang dâng), tắt hẳn khi phồng được 55%
const float SHINE_FADE_TO = 0.55;
const float EPS = 0.0001;

// Hash 2D -> 3 số ngẫu nhiên trong [0, 1) cho mỗi ô (không cần texture nhiễu).
vec3 hash3(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yxz + 33.33);
	return fract((q.xxy + q.yzz) * q.zyx);
}

// Easing back-out: f(t) = 1 + (c1 + 1)(t − 1)³ + c1(t − 1)², đi 0 -> 1, vọt quá ~10% rồi về 1.
float ease_out_back(float t) {
	float m = t - 1.0;
	return 1.0 + (BACK_C1 + 1.0) * m * m * m + BACK_C1 * m * m;
}

void fragment() {
	// Vị trí pixel theo đơn vị canvas (y tăng từ trên xuống), bám lưới điểm ảnh art.
	vec2 uv = vec2(SCREEN_UV.x, mix(SCREEN_UV.y, 1.0 - SCREEN_UV.y, uv_y_up));
	vec2 pos = (floor(uv * screen_size / pixel_size) + 0.5) * pixel_size;
	vec2 cell = floor(pos / cell_size);
	// Thang thời gian của một pha: bọt cuối cùng (trễ nhất) phồng / vỡ xong đúng lúc pha kết thúc.
	float span = rise_spread + jitter + grow_span;
	float t_in = clamp(progress, 0.0, 1.0) * span;
	float t_out = clamp(progress - 1.0, 0.0, 1.0) * span;

	float covered = 0.0;   // có bọt nào phủ pixel này không
	float layers = 0.0;    // bao nhiêu bọt cùng phủ (chồng nhau)
	float edge = 0.0;      // pixel nằm trên mép ngoài bọt đang phồng / mép lỗ bọt đang vỡ
	float min_burst = 1.0; // bọt "còn nguyên" nhất đang phủ pixel này vỡ được bao nhiêu
	float shine = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			vec3 rnd = hash3(c);
			vec2 home = (c + CENTER_MIN + CENTER_RANGE * rnd.xy) * cell_size;
			// Hàng dưới phồng trước: 0 ở đáy màn, 1 ở đỉnh; kẹp lại để hàng ngoài màn không trễ hơn hàng đỉnh.
			float height01 = clamp(1.0 - home.y / screen_size.y, 0.0, 1.0);
			float delay = height01 * rise_spread + rnd.z * jitter;
			float grow = clamp((t_in - delay) / grow_span, 0.0, 1.0);
			float burst = clamp((t_out - delay) / grow_span, 0.0, 1.0);
			vec2 center = home - vec2(0.0, RISE * cell_size * grow); // trồi lên khi phồng
			float radius = MAX_RADIUS * cell_size * ease_out_back(grow);
			float hole = radius * burst * (2.0 - burst); // lỗ vỡ nở từ tâm ra (ease-out quad)
			float d = length(pos - center);
			float alive = step(EPS, radius) * (1.0 - step(1.0 - EPS, burst));
			float body = step(d, radius) * step(hole, d) * alive;
			covered = max(covered, body);
			layers += body;
			// Viền 1 điểm ảnh: mép ngoài lúc đang phồng, mép lỗ lúc đang vỡ.
			float growing = 1.0 - smoothstep(RIM_FADE_FROM, 1.0, grow);
			float outer = step(radius - pixel_size, d) * growing;
			float inner = step(d, hole + pixel_size) * step(EPS, burst);
			edge = max(edge, body * max(outer, inner));
			min_burst = min(min_burst, mix(1.0, burst, body));
			// Đốm bóng góc trên-trái lúc bọt còn nhỏ.
			vec2 spot = center - vec2(HIGHLIGHT_OFFSET * radius);
			float shine_on = 1.0 - smoothstep(SHINE_FADE_FROM, SHINE_FADE_TO, grow);
			shine = max(shine, body * shine_on * step(length(pos - spot), HIGHLIGHT_RADIUS * radius));
		}
	}
	// Chỉ vẽ viền ở chỗ một bọt duy nhất phủ: mép ngoài của cả khối bọt, không kẻ chằng chịt bên trong.
	float rim = edge * step(layers, 1.5);
	// Bọt đang vỡ ngả dần về màu viền như màng xà phòng (theo bọt còn nguyên nhất đang phủ pixel).
	float film = covered * min_burst;
	COLOR.rgb = mix(COLOR.rgb, rim_color.rgb, max(rim, film) * rim_color.a);
	COLOR.rgb = mix(COLOR.rgb, highlight_color.rgb, shine * highlight_color.a);
	COLOR.a *= covered;
}
