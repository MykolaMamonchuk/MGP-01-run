"""Тимчасово вмикає прапорець `strip_probe` у ПЕВНОМУ пресеті й (для Android) підставляє
відлагоджувальний ключ.

Навіщо окремий файл. Це вже двічі ламалось у рядку команди: спершу ключі лишились у
export_presets.cfg, потім заміна `custom_features` обмежилась першим входженням — а перший
пресет у файлі це Web, тож прапорець пішов не в ту збірку, APK зібрався без проби, і телефон
п'ять хвилин міряв порожнечу. Пресет тепер називають ЯВНО.

    python3 tools/probe_build.py on Android    # перед експортом
    python3 tools/probe_build.py off           # одразу після

`off` повертає файл із резервної копії, тож пароль не може лишитись у git навіть якщо
експорт упаде.
"""
import io
import os
import shutil
import sys

CFG = "export_presets.cfg"
BAK = "/tmp/export_presets.bak.cfg"


def section(text: str, preset: str) -> tuple[int, int]:
	"""Межі блоку пресета за його ім'ям: від рядка name= до наступного name= або кінця."""
	start = text.index('name="%s"' % preset)
	nxt = text.find('\nname="', start + 1)
	return start, len(text) if nxt < 0 else nxt


def main() -> int:
	if sys.argv[1] == "off":
		if os.path.exists(BAK):
			shutil.copyfile(BAK, CFG)
			os.remove(BAK)
			print("пресети повернуто")
		return 0

	preset = sys.argv[2]
	shutil.copyfile(CFG, BAK)
	s = io.open(CFG, encoding="utf-8").read()
	a, b = section(s, preset)
	block = s[a:b]
	if 'custom_features="debug_hud"' not in block:
		print("НЕ ЗНАЙДЕНО debug_hud у пресеті %s" % preset)
		return 1
	block = block.replace('custom_features="debug_hud"', 'custom_features="debug_hud,strip_probe"')
	if preset == "Android":
		ks = os.path.expanduser("~/Library/Application Support/Godot/keystores/debug.keystore")
		anchor = 'package/unique_name='
		block = block.replace(anchor, 'keystore/release="%s"\nkeystore/release_user="androiddebugkey"\nkeystore/release_password="android"\n%s' % (ks, anchor), 1)
	io.open(CFG, "w", encoding="utf-8").write(s[:a] + block + s[b:])
	print("проба увімкнена в пресеті %s" % preset)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
