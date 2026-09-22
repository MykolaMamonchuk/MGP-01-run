# ОДНОТОННИЙ ПРОПС -> ОДНА ПОВЕРХНЯ, ОДИН СПІЛЬНИЙ МАТЕРІАЛ.
#
# Навіщо. 38 із 70 наших пропсів не мають текстур узагалі — це просто 2-7 однотонних
# матеріалів на об'єкт (house_red: балка, стіна, дах, вікно, двері). Разом вони дають 138
# поверхонь. Замір на Redmi 8A показав, що матеріальний стан коштує 60 із 192 одиниць ціни
# декору, тобто третину, і не залежить від роздільності.
#
# Що робить. Колір кожного матеріалу записує у ВЕРШИННІ кольори (по кутках, а не по
# вершинах: одна вершина може належати двом матеріалам, і по вершинах кольори змішались би),
# потім лишає один матеріал із білим базовим кольором. За glTF колір вершини множиться на
# базовий, тож біле множення дає РІВНО той самий вигляд.
#
# Чого НЕ робить. Текстурних пропсів не чіпає — там уже один матеріал, і їм потрібен атлас,
# а це окрема робота.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/atlas/flatten.py \
#       -- assets/props/house_red.glb assets/flat/house_red.glb
import bpy, sys, os

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))

def base_color(mat):
    if mat is None or not mat.use_nodes:
        return (1.0, 1.0, 1.0, 1.0)
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            c = n.inputs["Base Color"]
            if not c.is_linked:
                return tuple(c.default_value)
    return (1.0, 1.0, 1.0, 1.0)

textured = False
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for ob in meshes:
    for s in ob.material_slots:
        m = s.material
        if m is not None and m.use_nodes:
            if any(n.type == "TEX_IMAGE" and n.image for n in m.node_tree.nodes):
                textured = True
if textured:
    print("ПЛОСКО: %s має текстури — пропущено" % os.path.basename(src))
    raise SystemExit(0)

shared = bpy.data.materials.new("world_flat")
shared.use_nodes = True
for n in shared.node_tree.nodes:
    if n.type == "BSDF_PRINCIPLED":
        n.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        # Колір беремо з вершин: вузол атрибута -> базовий колір.
        attr = shared.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        shared.node_tree.links.new(attr.outputs["Color"], n.inputs["Base Color"])
        if "Specular IOR Level" in n.inputs:
            n.inputs["Specular IOR Level"].default_value = 0.0
        n.inputs["Roughness"].default_value = 1.0

for ob in meshes:
    me = ob.data
    cols = [base_color(s.material) for s in ob.material_slots] or [(1, 1, 1, 1)]
    # ПО КУТКАХ (CORNER), а не по вершинах: спільна вершина двох матеріалів інакше
    # дістала б один усереднений колір і шов поплив би.
    lay = me.color_attributes.get("Col") or me.color_attributes.new(
        name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly in me.polygons:
        c = cols[min(poly.material_index, len(cols) - 1)]
        for li in poly.loop_indices:
            lay.data[li].color = c
    me.materials.clear()
    me.materials.append(shared)

bpy.ops.object.select_all(action="DESELECT")
for ob in meshes:
    ob.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()

os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(dst), export_format="GLB",
                          export_vertex_color="MATERIAL", export_materials="EXPORT")
final = [o for o in bpy.context.scene.objects if o.type == "MESH"]
print("ПЛОСКО: %s -> %s  мешів %d, слотів %d" % (
    os.path.basename(src), os.path.basename(dst), len(final),
    sum(len(o.material_slots) for o in final)))
