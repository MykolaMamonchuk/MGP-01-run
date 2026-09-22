"""Тимчасово перетворює збірку Android на СТЕНД: головною сценою стає tools/bench/bench.tscn,
а тека tools/ перестає виключатись з експорту.

Окремий файл із тієї самої причини, що й probe_build.py: складання таких змін прямо в рядку
команди вже двічі тихо ламало заміри. Тут обидва файли беруться з резервних копій, тож
`off` повертає все навіть якщо експорт упав.

    python3 tools/bench_build.py on
    python3 tools/bench_build.py off
"""
import io
import os
import shutil
import sys

CFG = "export_presets.cfg"
PRJ = "project.godot"
BAK_CFG = "/tmp/bench_presets.bak.cfg"
BAK_PRJ = "/tmp/bench_project.bak.godot"
SCENE = "res://tools/bench/bench.tscn"
GDIGNORE = "tools/.gdignore"
GDIGNORE_OFF = "tools/.gdignore.off"


def main() -> int:
	if sys.argv[1] == "off":
		for bak, dst in ((BAK_CFG, CFG), (BAK_PRJ, PRJ)):
			if os.path.exists(bak):
				shutil.copyfile(bak, dst)
				os.remove(bak)
		if os.path.exists(GDIGNORE_OFF):
			os.rename(GDIGNORE_OFF, GDIGNORE)
		print("стенд вимкнено, файли повернуто")
		return 0

	shutil.copyfile(CFG, BAK_CFG)
	shutil.copyfile(PRJ, BAK_PRJ)
	# tools/.gdignore робить усю теку НЕВИДИМОЮ для рушія — тож у збірку вона не потрапляє
	# взагалі, і головна сцена стенда просто не знаходиться. На Маку це не видно: там файли
	# лежать на диску й завантажуються без імпорту.
	if os.path.exists(GDIGNORE):
		os.rename(GDIGNORE, GDIGNORE_OFF)

	prj = io.open(PRJ, encoding="utf-8").read()
	if "run/main_scene=" in prj:
		import re
		prj = re.sub(r'run/main_scene="[^"]*"', 'run/main_scene="%s"' % SCENE, prj)
	else:
		prj = prj.replace("[application]", '[application]\n\nrun/main_scene="%s"' % SCENE, 1)
	io.open(PRJ, "w", encoding="utf-8").write(prj)

	s = io.open(CFG, encoding="utf-8").read()
	i = s.index('name="Android"')
	j = s.find('\nname="', i + 1)
	j = len(s) if j < 0 else j
	blk = s[i:j].replace("tools/*,", "").replace(",tools/*", "")
	ks = os.path.expanduser("~/Library/Application Support/Godot/keystores/debug.keystore")
	blk = blk.replace("package/unique_name=",
		'keystore/release="%s"\nkeystore/release_user="androiddebugkey"\n'
		'keystore/release_password="android"\npackage/unique_name=' % ks, 1)
	io.open(CFG, "w", encoding="utf-8").write(s[:i] + blk + s[j:])
	print("стенд увімкнено: головна сцена %s, tools/ у збірці" % SCENE)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
