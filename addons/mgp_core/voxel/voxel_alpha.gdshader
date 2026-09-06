// Напівпрозорий варіант «пуху» — для Хмаринки. Окремий шейдер, щоб решта вокселів лишалась непрозорою (дешево).
shader_type spatial;
render_mode cull_disabled, specular_disabled, blend_mix, depth_prepass_alpha;

uniform float alpha : hint_range(0.0, 1.0) = 0.7;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = COLOR.rgb;
	EMISSION = vec3(1.0) * rim * rim_strength;
	ALPHA = alpha;
	ROUGHNESS = 0.9;
}
