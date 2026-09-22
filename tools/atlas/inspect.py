# Перепис пропса перед атласуванням: скільки матеріалів, які текстури, який розмір у світі.
# Розмір потрібен для ЩІЛЬНОСТІ ТЕКСЕЛІВ: площа в атласі ділиться за розміром об'єкта, а не
# порівну, інакше квітка дістане стільки ж, скільки будинок.
import bpy, sys, os, json

argv = sys.argv[sys.argv.index("--") + 1:]
out = []
for src in argv:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))
    mats, texs, verts, tris = set(), {}, 0, 0
    dims = [0.0, 0.0, 0.0]
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        verts += len(ob.data.vertices)
        tris += len(ob.data.polygons)
        dims = [max(a, b) for a, b in zip(dims, ob.dimensions)]
        for slot in ob.material_slots:
            m = slot.material
            if m is None:
                continue
            mats.add(m.name)
            if not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None:
                    texs[n.image.name] = list(n.image.size)
    out.append({
        "файл": os.path.basename(src),
        "матеріалів": len(mats),
        "вершин": verts,
        "граней": tris,
        "розмір": [round(d, 2) for d in dims],
        "текстури": texs,
    })
print("АТЛАСДАНІ " + json.dumps(out, ensure_ascii=False))
