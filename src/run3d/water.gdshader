// Стилізована вода каналу.
//
// Чому власний, а не готовий зі спільноти. Переглянув godotshaders.com (Stylized Toon Water,
// Low poly water, Toon Water 4.4+) і itch (EmaceArt, Binbun). Найкращі з них вимагають
// текстур шуму й хвиль і працюють у режимі додавання (blend_add, unshaded) — для нашого
// непрозорого каналу це дало б світіння замість води, а зайві текстури суперечать тому, що
// ми щойно з пакета вичищали. Тому взято ІДЕЇ, які там працюють, і зроблено без текстур:
//   - колір смугами за глибиною, а не плавним градієнтом (це і є «стилізованість»);
//   - піна вздовж берега, де вода мілка;
//   - рідкі блискітки на гребенях.
//
// Плита каналу — одиничний PlaneMesh, розтягнутий на ширину води, тож VERTEX.x лежить у
// межах ±0,5 незалежно від того, який канал широкий. Звідси й береться «наскільки далеко
// від берега».
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.31, 0.76, 0.97, 1.0);
uniform vec4 color_light : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float scroll = 0.0;
uniform float amplitude = 0.12;
uniform float bands = 3.0;          // скільки сходинок кольору від берега до середини
uniform float foam_width = 0.14;    // ширина пінної смуги біля берега, у частках півширини

varying float crest;
varying vec2 wpos;
varying float shore;                // 0 — середина каналу, 1 — самий берег

void vertex() {
	float z = VERTEX.z - scroll;
	// Дві хвилі з несумірними періодами: з одним синусом на довгому каналі око одразу
	// ловить повтор.
	float w = sin(z * 1.6 + TIME * 1.1) * amplitude
		+ sin(z * 0.73 - TIME * 0.62 + VERTEX.x * 0.8) * amplitude * 0.55;
	VERTEX.y += w;
	crest = clamp(w / amplitude, -1.0, 1.0);
	wpos = vec2(VERTEX.x, z);
	shore = clamp(abs(VERTEX.x) * 2.0, 0.0, 1.0);
}

void fragment() {
	// СМУГИ ЗА ГЛИБИНОЮ. Плавний градієнт читається як пластик; сходинки — як мальована
	// вода. Беремо глибину, округлюємо до кількох рівнів і за ними змішуємо два кольори.
	float depth = 1.0 - shore;                       // 1 у середині, 0 біля берега
	float step_d = floor(depth * bands) / max(bands - 1.0, 1.0);
	vec3 deep = color.rgb * 0.78;
	vec3 c = mix(color_light.rgb * 0.92, deep, clamp(step_d, 0.0, 1.0));

	// ПІНА БІЛЯ БЕРЕГА: вузька світла смуга, що ледь коливається — без неї вода виглядає
	// приклеєною до берега.
	float edge = 1.0 - smoothstep(1.0 - foam_width, 1.0, shore + sin(wpos.y * 2.4 + TIME * 0.7) * 0.02);
	c = mix(c, color_light.rgb, (1.0 - edge) * 0.55);

	// БЛИСКІТКИ на гребенях — рідкі й м'які. Вузьке вікно дає смугу з різким краєм, і на
	// відстані вона вмикається-вимикається між кадрами, читаючись як миготіння.
	float spark = smoothstep(0.88, 1.0, sin(wpos.y * 2.1 + wpos.x * 0.9 + TIME * 0.9))
		* smoothstep(0.4, 1.0, crest);
	c = mix(c, color_light.rgb, spark * 0.22);

	ALBEDO = c;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
}
