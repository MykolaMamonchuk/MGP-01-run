# Класифікує ВСЮ бібліотеку пропсів на два види:
#   "однотонний" — кілька матеріалів, кожен просто колір, текстур нема. Такому атлас НЕ
#                  потрібен: колір запікається у вершини, і всі такі пропси гри можуть
#                  ділити ОДИН матеріал.
#   "текстурний" — має картинки. Для спільного матеріалу потрібен атлас.
import bpy, sys, os, json

out = []
for src in sys.argv[sys.argv.index("--") + 1:]:
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))
    except Exception:
        continue
    mats, texs, verts, slots = set(), set(), 0, 0
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        verts += len(ob.data.vertices)
        slots += len(ob.material_slots)
        for s in ob.material_slots:
            m = s.material
            if m is None:
                continue
            mats.add(m.name)
            if m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image is not None:
                        texs.add(n.image.name)
    out.append({"f": os.path.basename(src), "m": len(mats), "s": slots,
                "t": len(texs), "v": verts})
print("КЛАС " + json.dumps(out))
