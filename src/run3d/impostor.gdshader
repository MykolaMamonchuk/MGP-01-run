// Спрайт-замінник, знятий з КІЛЬКОХ боків. Дощечка довертається до камери, а з атласу
// береться той бік, під яким на предмет дивляться саме зараз.
//
// Навіщо. Звичайний білборд — це одна картинка на всі напрямки: обходиш предмет, а він
// показує те саме. Для куща з густою кроною це видно одразу — він «обертається» разом з
// оком. Вісім боків прибирають це коштом восьми картинок, і все одно виходить у кілька
// кілобайтів проти мегабайтів геометрії з листям.
//
// Чому взагалі не геометрія: у куща тисячі дрібних граней-листочків, і саме вони, а не
// силует, коштують дорого. Для решти пропсів (бочка, ящик, паркан) це не так — там
// геометрія дешева, і вони лишаються справжніми 3D-моделями.
shader_type spatial;
render_mode cull_disabled, unshaded, depth_prepass_alpha;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform int frames = 8;

varying flat float frame_index;

void vertex() {
	// Дощечка стоїть вертикально й довертається до камери ЛИШЕ навколо вертикалі: нахиляти
	// її слідом за камерою не можна, бо кущ відірветься від землі.
	vec3 origin = MODEL_MATRIX[3].xyz;
	// масштаб інстанса треба зберегти вручну: складання нового базису його б викинуло, і
	// всі кущі стали б однакового розміру
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);

	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	to_cam.y = 0.0;
	vec3 fwd = normalize(length(to_cam) > 0.0001 ? to_cam : vec3(0.0, 0.0, 1.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 up = vec3(0.0, 1.0, 0.0);

	vec3 world = origin + right * (VERTEX.x * sx) + up * (VERTEX.y * sy);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);

	// Під яким кутом на предмет дивляться — відносно ЙОГО власного розвороту. Саме тому
	// беремо різницю двох кутів, а не абсолютний: кущ, поставлений із поворотом, має
	// показувати відповідний бік, а не той самий, що й сусід.
	vec3 own = normalize(vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z));
	float a = atan(fwd.x, fwd.z) - atan(own.x, own.z);
	float t = fract(a / TAU + 0.5 / float(frames));
	frame_index = floor(t * float(frames));
}

void fragment() {
	// UV однієї клітинки атласу. Відступ у півпікселя з країв — інакше при згладжуванні
	// в кадр підтікає сусідній бік смугою.
	float w = 1.0 / float(frames);
	float u = (frame_index + clamp(UV.x, 0.002, 0.998)) * w;
	vec4 c = texture(atlas, vec2(u, UV.y));
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
