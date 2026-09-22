# Спрощує меш моделі для ТЕСТУ З СИЛУЕТОМ: та сама модель, те саме місце, той самий
# матеріал і тінь — міняється ЛИШЕ кількість вершин. Це чистіший доказ, ніж вимикати цілий
# шар забудови, бо там разом із вершинами зникають і матеріал, і виклики, і заповнення.
#
# Запуск:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/lod/decimate.py \
#       -- assets/props/house_terra_6.glb assets/lod/house_terra_6_lod1.glb 0.25
#
# Складає результат в assets/lod/, а НЕ в assets/props/: у другій теці кожен файл має бути
# видом із data/props.json, і сторож tests/test_prop_budget.gd це перевіряє. Спрощений
# будинок — не новий вид, а той самий будинок меншою ціною.
#
# Це інструмент ЗАМІРУ, а не готовий конвеєр LOD: збіг вершин задається часткою граней, а
# розгортка при сильному спрощенні пливе. Для продукту потрібні справжні LOD-моделі.
import bpy, sys, os

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst, ratio = argv[0], argv[1], float(argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))

before = after = 0
for ob in list(bpy.context.scene.objects):
    if ob.type != "MESH":
        continue
    before += len(ob.data.polygons)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
    after += len(ob.data.polygons)

bpy.ops.export_scene.gltf(filepath=os.path.abspath(dst), export_format="GLB")
print("ЛОД: %s -> %s  граней %d -> %d (частка %.3f)" % (src, dst, before, after, ratio))
