// Глянцевий матеріал ригнутих героїв (арт-вектор low-poly toy → glossy toy, вересень 2026).
// Окремий від voxel.gdshader навмисно: довкілля лишається матовим вокселем, а герої —
// glossy vinyl-toy (справжній specular/roughness замість emission-«пуху»).
shader_type spatial;
render_mode cull_disabled;

uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
// Дефолти дають м'який глянець «вінілової іграшки»: не дзеркало (roughness=1 було в
// вокселя), але й не пластик-крейда — специфічний highlight читається на круглих формах.
uniform float roughness_value : hint_range(0.0, 1.0) = 0.35;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec3 srgb = COLOR.rgb;
	vec3 base = pow(srgb, vec3(2.2));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = base;
	EMISSION = rim_color.rgb * rim * rim_strength;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = specular_value;
}
