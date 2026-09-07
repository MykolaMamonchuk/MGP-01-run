// Обведення «вивернутою оболонкою»: копія меша, роздута по нормалі, чорна, без освітлення, лицьові грані відсічені.
// Godot 4 не має multipass — тому обведення це окремий MeshInstance3D-дубль із цим матеріалом (Obstacle3D).
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform float grow : hint_range(0.0, 0.2) = 0.03;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
