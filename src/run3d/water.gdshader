// Вода для режиму «Хвиля»: синусоїдні хвилі у вершинному шейдері, без фізики.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.31, 0.76, 0.97, 1.0);
uniform vec4 color_light : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float scroll = 0.0;
uniform float amplitude = 0.12;

varying float crest;
varying vec2 wpos;

void vertex() {
	float z = VERTEX.z - scroll;
	float w = sin(z * 1.6 + TIME * 2.0) * amplitude + sin(z * 0.7 - TIME * 1.1 + VERTEX.x * 0.8) * amplitude * 0.6;
	VERTEX.y += w;
	crest = clamp(w / amplitude, -1.0, 1.0);
	wpos = vec2(VERTEX.x, z);
}

void fragment() {
	vec3 c = mix(color.rgb, color_light.rgb, smoothstep(0.3, 1.0, crest));
	// піна на гребенях + тонкі відблиски, що біжать
	// М'якші й рідші відблиски. Було: smoothstep(0.96, 1.0) — вузьке вікно дає СМУГУ з
	// різким краєм, і на ігровій відстані вона вмикається-вимикається між кадрами, читаючись
	// як миготіння. Ширше вікно робить блиск плавним, а менша сила прибирає чисто білий
	// колір, від якого вода виглядала як пластик.
	float foam = smoothstep(0.72, 1.0, crest);
	float streak = smoothstep(0.80, 1.0, sin(wpos.y * 3.0 + wpos.x * 1.6 + TIME * 1.6));
	c = mix(c, color_light.rgb, clamp(foam * 0.55 + streak * 0.22, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
}
