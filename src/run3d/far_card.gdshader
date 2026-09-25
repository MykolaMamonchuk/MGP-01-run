// КАРТКА ДАЛЕКОЇ ХАТИ: знімок хати під кутом ігрової камери (src/debug/far_card_capture).
// Світло вже вмальоване в картинку, тож тут його немає — лише текстура й відсікання краю.
// Шейдерний, а не звичайний матеріал, НАВМИСНО: траса після підміни сітки наново розставляє
// матеріалам декору світло на вершину й випромінення (Track.apply_decor_shading), і
// звичайний матеріал картки став би освітленим. Шейдерні вона не чіпає.
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
}
