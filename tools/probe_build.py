"""Тимчасово вмикає прапорець `strip_probe` у ПЕВНОМУ пресеті й (для Android) підставляє
відлагоджувальний ключ.

Навіщо окремий файл. Це вже двічі ламалось у рядку команди: спершу ключі лишились у
export_presets.cfg, потім заміна `custom_features` обмежилась першим входженням — а перший
пресет у файлі це Web, тож прапорець пішов не в ту збірку, APK зібрався без проби, і телефон
п'ять хвилин міряв порожнечу. Пресет тепер називають ЯВНО.

    python3 tools/probe_build.py on Android    # перед експортом
    python3 tools/probe_build.py keys Android  # звичайна гра, лише ключ
    python3 tools/probe_build.py sweep Android # прогін усіх рівнів підряд
    python3 tools/probe_build.py off           # одразу після

`off` повертає файл із резервної копії, тож пароль не може лишитись у git навіть якщо
експорт упаде.
"""
import io
import os
import shutil
import subprocess
import sys

CFG = "export_presets.cfg"
BAK = "/tmp/export_presets.bak.cfg"


def section(text: str, preset: str) -> tuple[int, int]:
	"""Межі блоку пресета за його ім'ям: від рядка name= до наступного name= або кінця."""
	start = text.index('name="%s"' % preset)
	nxt = text.find('\nname="', start + 1)
	return start, len(text) if nxt < 0 else nxt


GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
PROBES = {
	"strip_probe": "src/ui/strip_probe.gd",
	"sweep": "src/ui/sweep_probe.gd",
}


def probe_parses(path: str) -> bool:
	"""Чи компілюється сценарій проби.

	Навіщо. Поламаний `strip_probe.gd` НЕ валить експорт: APK збирається, ставиться,
	запускається — і мовчки не міряє нічого. Рушій пише «Parse error» лише в журнал
	телефона, а журнал на цьому пристрої прокручується за хвилини. Один раз через це
	згорів цілий прогін: варіанти правили руками, кома лишилась зайва, і телефон п'ять
	хвилин показував меню замість заміру.

	Код виходу в `--check-only` завжди 0, тож дивимось саме на текст.
	"""
	if not os.path.exists(GODOT):
		print("УВАГА: Godot не знайдено за %s, синтаксис проби не перевірено" % GODOT)
		return True
	out = subprocess.run([GODOT, "--headless", "--check-only", "--script", path],
		capture_output=True, text=True)
	text = out.stdout + out.stderr
	if "SCRIPT ERROR" in text or "Parse Error" in text:
		print("ПРОБА НЕ КОМПІЛЮЄТЬСЯ — збірка не має сенсу:")
		for line in text.splitlines():
			if "ERROR" in line or "Error" in line:
				print("   " + line.strip())
		return False
	return True


def print_plan(path: str) -> None:
	"""Надрукувати, ЩО саме проба збирається міряти.

	Навіщо. Правка списку варіантів редактором один раз тихо не лягла (не збігся анкер), а
	збірка все одно поїхала — і телефон п'ятнадцять хвилин міряв варіанти від попереднього
	досліду на чужому рівні. Помилку видно було тільки в кінці, по назвах у журналі. Тепер
	план друкується ПЕРЕД збіркою, і розбіжність видно одразу.
	"""
	try:
		text = io.open(path, encoding="utf-8").read()
	except OSError:
		return
	for key in ("const POINTS", "const VARIANTS"):
		i = text.find(key)
		if i < 0:
			continue
		end = text.find("\n]", i)
		end = text.find("\n", i) if end < 0 else end + 2
		print("   " + text[i:end].replace("\n", "\n   "))


def main() -> int:
	if sys.argv[1] == "off":
		if os.path.exists(BAK):
			shutil.copyfile(BAK, CFG)
			os.remove(BAK)
			print("пресети повернуто")
		return 0

	# `keys` — те саме, але БЕЗ проби: звичайна збірка гри, лише з ключем для підпису.
	# Потрібна, щоб міряти те, що справді побачить дитина, а не сценарій заміру.
	only_keys = sys.argv[1] == "keys"
	# `sweep` — прогін усіх рівнів підряд (src/ui/sweep_probe.gd), інший прапорець збірки.
	feature = "sweep" if sys.argv[1] == "sweep" else "strip_probe"
	preset = sys.argv[2]
	if not only_keys and not probe_parses(PROBES[feature]):
		return 1
	shutil.copyfile(CFG, BAK)
	s = io.open(CFG, encoding="utf-8").read()
	a, b = section(s, preset)
	block = s[a:b]
	if 'custom_features="debug_hud"' not in block:
		print("НЕ ЗНАЙДЕНО debug_hud у пресеті %s" % preset)
		return 1
	if not only_keys:
		block = block.replace('custom_features="debug_hud"',
			'custom_features="debug_hud,%s"' % feature)
	if preset == "Android":
		ks = os.path.expanduser("~/Library/Application Support/Godot/keystores/debug.keystore")
		anchor = 'package/unique_name='
		block = block.replace(anchor, 'keystore/release="%s"\nkeystore/release_user="androiddebugkey"\nkeystore/release_password="android"\n%s' % (ks, anchor), 1)
	io.open(CFG, "w", encoding="utf-8").write(s[:a] + block + s[b:])
	print("ключ підставлено в %s" % preset if only_keys else "проба увімкнена в пресеті %s" % preset)
	if not only_keys:
		print_plan(PROBES[feature])
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
