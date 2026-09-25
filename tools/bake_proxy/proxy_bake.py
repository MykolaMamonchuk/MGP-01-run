## ЗАПЕЧЕНА ОБОЛОНКА ДЛЯ ВАЖКОЇ МОДЕЛІ (Blender, без вікна).
##
## Навіщо. Хати house_terra* мають по 8-11 тисяч вершин, і відколи тіні вимкнено, а декор
## світиться на вершину, сітка стала коштувати мілісекунди (25.09: proxy600 -3,1 мс на
## масштабі 0,80 при заміні всіх хат, proxy1200 -2,1). Проста ідея — спростити модель —
## НЕ працює: вона складається з сотень окремих шматочків (кожна черепиця своя оболонка), і
## спрощення розриває дах на клапті. Тому форму будуємо ЗАНОВО, а вигляд переносимо картинкою:
##   1. AO запікається ОДИН РАЗ на оригіналі й домножується на його колір — ДО появи
##      оболонок, бо AO рахує затінення від усієї сцени, і оболонки, що огортають будинок,
##      затуляли б йому небо (так друга оболонка вийшла сіро-бурою замість кремової);
##   2. voxel remesh дає суцільну оболонку, спрощення суцільної — чисте. «Voxel» тут — лише
##      назва алгоритму Blender: він тимчасово кладе сітку на ґратку, щоб зібрати з неї ОДНУ
##      замкнену поверхню. На виході звичайна low-poly оболонка з запеченою текстурою, а НЕ
##      кубики: воксельного вигляду в грі немає й не буде (стиль свідомо не воксельний);
##   3. нова UV-розгортка й запікання кольору оригіналу на оболонку (selected-to-active).
##
## Запуск:
##   /Applications/Blender.app/Contents/MacOS/Blender --background \
##       --python tools/bake_proxy/proxy_bake.py -- <вхід.glb> <тека_виходу> <тека_знімків>
## Виходить <назва>_proxy1200.glb і _proxy600.glb плюс знімки з ігрового ракурсу.
## Дослід 25.09, другий підхід: НОВА проста оболонка + запікання ВСЬОГО вигляду з повної
## моделі. Спрощення самої моделі рве дах, бо вона складається з сотень окремих шматочків
## (кожна черепиця — своя оболонка). Тут форму будуємо заново (voxel remesh дає суцільну
## оболонку), спрощуємо ЇЇ (суцільна спрощується чисто), розгортаємо UV і запікаємо на неї
## колір і AO повної моделі. Деталь стає картинкою, геометрія лишається цілою.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

src, outdir, shotdir = sys.argv[-3], sys.argv[-2], sys.argv[-1]
# Ім'я виходу — від вхідного файлу, щоб той самий скрипт працював для всіх хат.
BASE = os.path.splitext(os.path.basename(src))[0]
os.makedirs(outdir, exist_ok=True); os.makedirs(shotdir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
high = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]; high.name = "HIGH"
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
w = bpy.data.worlds.new("W"); sc.world = w; w.light_settings.distance = 0.2
def tris(o): return sum(len(p.vertices) - 2 for p in o.data.polygons)

# AO ЗАПІКАЄТЬСЯ ОДИН РАЗ НА ОРИГІНАЛІ, ДО ПОЯВИ ОБОЛОНОК. AO рахує затінення від УСІЄЇ
# геометрії сцени, а оболонки огортають будинок і затуляють йому небо: друга оболонка
# запікалась у сцені, де вже стояла перша, і стіни виходили сіро-бурими замість кремових.
# Тому AO множимо в колір оригіналу в його власній UV, а на оболонки переносимо вже готовий
# колір — у ньому затінення немає, і сусідні оболонки на нього не впливають.
_hm = high.data.materials[0]; _hn = _hm.node_tree
# Текстуру кольору беремо за ПІДКЛЮЧЕННЯМ до базового кольору матеріалу, а не за назвою:
# у house_terra_6 вона звалась baked_color, а в house_terra_6_optimize — texture_0, і пошук
# за словом «color» падав з IndexError.
def _base_color_tex(nt):
    for l in nt.links:
        if l.to_socket.name == "Base Color" and l.from_node.type == 'TEX_IMAGE' and l.from_node.image:
            return l.from_node
    return [n for n in nt.nodes if n.type == 'TEX_IMAGE' and n.image
            and 'normal' not in n.image.name and 'metallic' not in n.image.name][0]
_col = _base_color_tex(_hn)
_W, _H = _col.image.size
_ao = bpy.data.images.new("ao_src", _W, _H, alpha=False)
_aon = _hn.nodes.new('ShaderNodeTexImage'); _aon.image = _ao
for n in _hn.nodes: n.select = False
_aon.select = True; _hn.nodes.active = _aon
bpy.ops.object.select_all(action='DESELECT'); high.select_set(True)
bpy.context.view_layer.objects.active = high
sc.cycles.samples = 64; sc.render.bake.margin = 8
bpy.ops.object.bake(type='AO')
_c = np.array(_col.image.pixels[:], dtype=np.float32).reshape(_H, _W, 4)
_a = np.array(_ao.pixels[:], dtype=np.float32).reshape(_H, _W, 4)[..., :1]
_c[..., :3] *= (0.3 + 0.7 * _a)
_pre = bpy.data.images.new("color_ao", _W, _H, alpha=True); _pre.pixels = _c.ravel().tolist()
_col.image = _pre
_hn.nodes.remove(_aon)
print("AO оригіналу: середнє %.3f" % float(_a.mean()))
def activate(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o

def proxy(target, voxel):
    o = high.copy(); o.data = high.data.copy(); o.name = "proxy%d" % target
    sc.collection.objects.link(o); activate(o)
    o.data.materials.clear()
    r = o.modifiers.new("vox", 'REMESH'); r.mode = 'VOXEL'; r.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier="vox")
    d = o.modifiers.new("dec", 'DECIMATE'); d.decimate_type = 'COLLAPSE'
    d.use_collapse_triangulate = True; d.ratio = min(1.0, target / max(tris(o), 1))
    bpy.ops.object.modifier_apply(modifier="dec")
    # UV з нуля: оболонка нова, старої розгортки в неї немає
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    # плаский колір граней: у грі декор світиться на вершину, а грані в нас розщеплені
    for p in o.data.polygons: p.use_smooth = False
    return o

def bake_onto(low, size, voxel):
    img_c = bpy.data.images.new(low.name + "_c", size, size, alpha=False)
    img_a = bpy.data.images.new(low.name + "_a", size, size, alpha=False)
    m = bpy.data.materials.new(low.name + "_m"); m.use_nodes = True; low.data.materials.append(m)
    nt = m.node_tree; tex = nt.nodes.new('ShaderNodeTexImage')
    bsdf = nt.nodes["Principled BSDF"]; nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    for img, kind in ((img_c, 'DIFFUSE'),):
        tex.image = img
        for n in nt.nodes: n.select = False
        tex.select = True; nt.nodes.active = tex
        bpy.ops.object.select_all(action='DESELECT'); high.select_set(True); low.select_set(True)
        bpy.context.view_layer.objects.active = low
        sc.cycles.samples = 48; sc.render.bake.margin = 6
        # Промінь запікання мусить дістати до поверхні оригіналу, а грубіша оболонка лежить
        # далі від неї: відстань масштабується з розміром вокселя, а не стала.
        # Грубіше спрощення лягає ПІД черепицю й стіни, тож промінь мусить стартувати вище:
        # інакше він влучає в споди черепиці (темні смуги) і звороти рам (темні стіни).
        ext = 0.06 if len(low.data.polygons) > 900 else 0.16
        kw = dict(type=kind, use_selected_to_active=True, cage_extrusion=ext, max_ray_distance=ext * 2.5)
        if kind == 'DIFFUSE': kw["pass_filter"] = {'COLOR'}
        bpy.ops.object.bake(**kw)
    c = np.array(img_c.pixels[:], dtype=np.float32).reshape(size, size, 4)
    fin = bpy.data.images.new(low.name + "_tex", size, size, alpha=False)
    fin.pixels = c.ravel().tolist(); fin.file_format = 'JPEG'
    fin.filepath_raw = os.path.join(outdir, "%s_%s.jpg" % (BASE, low.name)); fin.save()
    tex.image = fin
    return low

res = []
for target, voxel in ((1200, 0.04), (600, 0.04)):
    lo = bake_onto(proxy(target, voxel), 1024, voxel)
    res.append(lo)
    print("ОБОЛОНКА %-9s трикутників %5d  вершин %5d" % (lo.name, tris(lo), len(lo.data.vertices)))
    activate(lo)
    bpy.ops.export_scene.gltf(filepath=os.path.join(outdir, "%s_%s.glb" % (BASE, lo.name)),
        use_selection=True, export_format='GLB', export_image_format='JPEG')

sc.cycles.samples = 24; sc.render.resolution_x = 320; sc.render.resolution_y = 380
w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.85, 0.95, 1)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", 'SUN')); sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(35)); sun.data.energy = 3
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); sc.collection.objects.link(cam); sc.camera = cam
ctr = Vector((0, 0, high.dimensions.z * 0.5))
allv = [high] + res
for o in allv: o.hide_render = True
for o in res:
    o.hide_render = False
    for vname, yaw, dist, h in (("бік", 45, 4.2, 1.4), ("вздовж", 75, 5.5, 1.8)):
        y = math.radians(yaw)
        cam.location = ctr + Vector((math.sin(y) * dist, -math.cos(y) * dist, h))
        cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(shotdir, "%s_%s.png" % (o.name, vname))
        bpy.ops.render.render(write_still=True)
    o.hide_render = True
print("ГОТОВО")
