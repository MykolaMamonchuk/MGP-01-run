// «Пух»: вершинні кольори + м'який rim-highlight по контуру. Один матеріал на всі вокселі.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

// v2: rim був 0.28 — на дрібній сітці (воксель 4 см) граней багато, і біла облямівка
// з'їдала колір: герой виглядав вицвілим. 0.18 лишає «пух», але albedo веде.
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	// Вершинний колір — це hex із палітри (sRGB), а ALBEDO чекає лінійний простір:
	// без переведення всі вокселі виходили блідими й «вибіленими» (герої персикові замість рудих).
	vec3 srgb = mix(COLOR.rgb, tint.rgb, tint_strength);
	vec3 base = pow(srgb, vec3(2.2));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = base;
	EMISSION = rim_color.rgb * rim * rim_strength;
	ROUGHNESS = 1.0;   // повністю матово, без металу — колір із палітри, а не відблиск
	METALLIC = 0.0;
}
