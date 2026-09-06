// «Пух»: вершинні кольори + м'який rim-highlight по контуру. Один матеріал на всі вокселі.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform float rim_strength : hint_range(0.0, 1.0) = 0.28;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec3 base = mix(COLOR.rgb, tint.rgb, tint_strength);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = base;
	EMISSION = rim_color.rgb * rim * rim_strength;
	ROUGHNESS = 0.9;
}
