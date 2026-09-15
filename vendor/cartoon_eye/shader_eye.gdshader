shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 sclera_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 rim_color : source_color = vec4(0.20, 0.13, 0.10, 1.0);
uniform vec4 iris_color : source_color = vec4(0.42, 0.24, 0.15, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.10, 0.055, 0.04, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float eye_width : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float eye_height : hint_range(0.5, 1.6, 0.01) = 1.0;

uniform float iris_size : hint_range(0.2, 0.95, 0.01) = 0.67;
uniform float pupil_size : hint_range(0.1, 0.9, 0.01) = 0.55;

uniform vec2 gaze = vec2(0.0, 0.0);

uniform vec2 big_highlight_pos = vec2(-0.28, -0.28);
uniform float big_highlight_size : hint_range(0.01, 0.35, 0.01) = 0.13;

uniform vec2 small_highlight_pos = vec2(0.30, 0.28);
uniform float small_highlight_size : hint_range(0.005, 0.2, 0.005) = 0.055;

uniform float rim_size : hint_range(0.0, 0.15, 0.005) = 0.035;
uniform float blink : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float softness : hint_range(0.001, 0.08, 0.001) = 0.018;
// На скільки МЕТРІВ підсунути око до камери при перевірці глибини (див. vertex()).
uniform float depth_bias : hint_range(0.0, 0.05, 0.001) = 0.005;

float ellipse_sdf(vec2 p, vec2 radius) {
    vec2 q = p / radius;
    return length(q) - 1.0;
}

// Око — ПЛАСКИЙ квад, а голова опукла: власна випуклість очниці моделі (у лиса вона лишилась
// від запечених очей) пробиває цей квад і визирає просто крізь райдужку/зіницю. Зсуваємо
// вершини трохи ДО КАМЕРИ у просторі виду — око виграє цю локальну боротьбу за глибину, але
// й далі чесно ховається за мордою чи вухом, коли голова відвертається. Саме тому не
// depth_test_disabled: той світив би оком навіть крізь потилицю.
void vertex() {
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    view_pos.z += depth_bias;
    VERTEX = (inverse(MODELVIEW_MATRIX) * view_pos).xyz;
}

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    p.x /= eye_width;
    p.y /= eye_height;

    // Vertical closing from top + bottom.
    float open_amount = max(0.03, 1.0 - blink);
    vec2 eye_p = vec2(p.x, p.y / open_amount);

    float outer_d = ellipse_sdf(eye_p, vec2(0.95, 0.95));
    float inner_d = ellipse_sdf(eye_p, vec2(0.95 - rim_size, 0.95 - rim_size));

    float outer_alpha = 1.0 - smoothstep(0.0, softness, outer_d);
    float inner_alpha = 1.0 - smoothstep(0.0, softness, inner_d);

    vec3 color = rim_color.rgb;
    color = mix(color, sclera_color.rgb, inner_alpha);

    vec2 max_gaze = vec2(0.22, 0.16);
    vec2 iris_center = clamp(gaze, vec2(-1.0), vec2(1.0)) * max_gaze;

    vec2 ip = eye_p - iris_center;
    float iris_d = ellipse_sdf(ip, vec2(iris_size, iris_size * 1.06));
    float iris_mask = 1.0 - smoothstep(0.0, softness, iris_d);

    // Subtle iris shading.
    float iris_light = clamp(0.5 + (-ip.y * 0.35) + (-ip.x * 0.10), 0.0, 1.0);
    vec3 shaded_iris = iris_color.rgb * mix(0.72, 1.18, iris_light);
    color = mix(color, shaded_iris, iris_mask);

    float pupil_d = ellipse_sdf(ip, vec2(
        iris_size * pupil_size,
        iris_size * pupil_size * 1.10
    ));
    float pupil_mask = 1.0 - smoothstep(0.0, softness, pupil_d);
    color = mix(color, pupil_color.rgb, pupil_mask * iris_mask);

    vec2 bh = ip - big_highlight_pos;
    float big_h = 1.0 - smoothstep(
        big_highlight_size,
        big_highlight_size + softness,
        length(vec2(bh.x, bh.y * 0.82))
    );

    vec2 sh = ip - small_highlight_pos;
    float small_h = 1.0 - smoothstep(
        small_highlight_size,
        small_highlight_size + softness,
        length(sh)
    );

    float highlights = max(big_h, small_h) * iris_mask;
    color = mix(color, highlight_color.rgb, highlights);

    // Fully disappear at complete blink.
    float blink_visibility = 1.0 - smoothstep(0.96, 1.0, blink);

    ALBEDO = color;
    ALPHA = outer_alpha * blink_visibility;
}
