// Вода для режиму «Хвиля»: синусоїдні хвилі у вершинному шейдері, без фізики.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.31, 0.76, 0.97, 1.0);
uniform vec4 color_light : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float scroll = 0.0;
uniform float amplitude = 0.12;

varying float crest;
varying vec2 wpos;
varying float shore;

void vertex() {
	float z = VERTEX.z - scroll;
	// Дві хвилі з несумірними періодами замість однієї: одна дає правильний ритм, але
	// повторюється надто помітно — на довгому каналі око одразу ловить, що це синус.
	float w = sin(z * 1.6 + TIME * 1.1) * amplitude
		+ sin(z * 0.73 - TIME * 0.62 + VERTEX.x * 0.8) * amplitude * 0.55;
	VERTEX.y += w;
	crest = clamp(w / amplitude, -1.0, 1.0);
	wpos = vec2(VERTEX.x, z);
	// Плита каналу — одиничний PlaneMesh, розтягнутий на ширину води, тож VERTEX.x лежить
	// у межах ±0,5 незалежно від того, який канал широкий. Звідси й береться «наскільки
	// далеко від берега»: у референсі вода біля берега світліша, ніби мілко, і саме це
	// відрізняє річку від рівної синьої плями.
	shore = 1.0 - smoothstep(0.18, 0.50, abs(VERTEX.x));
}

void fragment() {
	// глибина: середина темніша, край світліший
	vec3 deep = color.rgb * 0.82;
	vec3 c = mix(deep, color.rgb, shore * 0.55 + 0.45);
	c = mix(c, color_light.rgb, shore * 0.30);
	// гребені — м'яко, без чисто білого: від нього вода виглядає пластиковою
	c = mix(c, color_light.rgb, smoothstep(0.55, 1.0, crest) * 0.35);
	// рідкі довгі відблиски впоперек течії, як на референсі
	float streak = smoothstep(0.86, 1.0, sin(wpos.y * 2.1 + wpos.x * 0.9 + TIME * 0.9));
	c = mix(c, color_light.rgb, streak * 0.18);
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
