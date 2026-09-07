// Смугаста «небезпечна» плитка під перешкодою: дві фарби, смуги вздовж x (у локальних координатах меша).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color_a : source_color = vec4(0.93, 0.26, 0.26, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float stripe_width = 0.15;

varying float local_x;

void vertex() {
	local_x = VERTEX.x;
}

void fragment() {
	float s = step(0.5, fract(local_x / max(stripe_width, 0.01)));
	ALBEDO = mix(color_a.rgb, color_b.rgb, s);
}
