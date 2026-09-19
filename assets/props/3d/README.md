# Вихідні моделі для запікання — у гру НЕ йдуть

Тут лежать важкі моделі з генератора, з яких запікаються ігрові пропси
(`tools/prop_bake.py`). `bush_flower_1.glb` — 104 299 граней і 25 МБ; у грі замість нього
`assets/props/bush_flower_1.glb` на **200 граней і 0,12 МБ**, і різниці не видно.

Поряд лежить `.gdignore`: Godot цю теку не імпортує взагалі, тож вихідники не потрапляють ні
в кеш імпорту, ні в збірку. Для запікання це не заважає — Blender читає файли з диска.

Перезапекти:

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/prop_bake.py -- \
      --in assets/props/3d/bush_flower_1.glb --out assets/props/bush_flower_1.glb \
      --shape sphere --segments 20 --rings 10 --size 512 --cage 0.06 --box 0.633x0.500x0.634
