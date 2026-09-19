#!/usr/bin/env bash
# Запустити гру з мостом MCP — і гарантовано прибрати міст за собою.
#
#   tools/bridge-run.sh
#
# Міст (mcp_bridge.gd + автозавантаження MCPBridge) відкриває в процесі гри локальний сокет,
# через який агент може читати дерево сцени, геометрію HUD і знімати справжні кадри з UI —
# те, чого headless не вміє, бо 2D він не малює взагалі.
#
# ЧОМУ ЦЕ СКРИПТ, А НЕ ІНСТРУКЦІЯ. Міст НЕ має лишатися в репозиторії: захисту від релізної
# збірки в ньому немає, і забутий міст поїде в магазин із відкритим портом. Тут прибирання
# висить на `trap`, тож воно стається навіть після Ctrl-C чи падіння гри. Забути неможливо.
# Стереже ще й tests/test_no_dev_bridge_shipped.gd — поки міст стоїть, той тест червоний.
#
# ЧОМУ ПОРТ ПРИБИТИЙ. Без GODOT_MCP_BRIDGE_PORT гра обирає стартовий порт випадково в
# 9081-9090, а MCP-клієнт без запису в реєстрі інстансів стукає в 9081 — і вони не
# зустрічаються («Bridge secret not found»). Реєстр заповнюється, лише коли гру запускає сам
# сервер; при запуску руками його немає.

set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$PROJECT/project.godot"
BRIDGE_DEST="$PROJECT/mcp_bridge.gd"
AUTOLOAD_LINE='MCPBridge="*res://mcp_bridge.gd"'

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${GODOT_MCP_BRIDGE_PORT:-9081}"

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
say() { printf '\033[36m%s\033[0m\n' "$*"; }

[ -x "$GODOT" ] || die "Godot не знайдено: $GODOT (задайте змінною GODOT=)"
[ -f "$CONFIG" ] || die "project.godot не знайдено: $CONFIG"

# Джерело мосту — у розпакованому npx-кеші пакета. Шлях містить хеш, тому шукаємо.
BRIDGE_SRC="$(find "$HOME/.npm/_npx" -path '*/godot-mcp-enhanced/build/scripts/mcp_bridge.gd' \
	-maxdepth 6 2>/dev/null | head -1 || true)"
[ -n "$BRIDGE_SRC" ] || die "Не знайшов mcp_bridge.gd у кеші npx. Спершу хоч раз викличте godot-mcp-enhanced."

cleanup() {
	local rc=$?
	say "→ прибираю міст"
	# Рядок автозавантаження
	if grep -q '^MCPBridge=' "$CONFIG"; then
		sed -i '' '/^MCPBridge="\*res:\/\/mcp_bridge\.gd"$/d' "$CONFIG"
	fi
	rm -f "$BRIDGE_DEST"
	rm -f "$PROJECT"/.godot/mcp_bridge_*.secret

	# Прибирання — головна обіцянка цього скрипта, тож перевіряємо її, а не сподіваємось.
	local left=""
	grep -q '^MCPBridge=' "$CONFIG" && left="рядок у project.godot"
	[ -f "$BRIDGE_DEST" ] && left="${left:+$left і }файл mcp_bridge.gd"
	if [ -n "$left" ]; then
		printf '\033[31mУВАГА: не вдалося прибрати %s — зробіть це руками, інакше міст поїде в білд!\033[0m\n' "$left" >&2
		exit 1
	fi
	say "✓ міст прибрано, репозиторій чистий"
	exit $rc
}
trap cleanup EXIT INT TERM

# Лишки від попереднього разу (наприклад, після kill -9) прибираємо мовчки.
sed -i '' '/^MCPBridge="\*res:\/\/mcp_bridge\.gd"$/d' "$CONFIG"

say "→ ставлю міст (порт $PORT)"
cp "$BRIDGE_SRC" "$BRIDGE_DEST"

# Дописуємо рядок останнім у секції [autoload] — тобто перед наступною секцією або в кінець.
awk -v line="$AUTOLOAD_LINE" '
	/^\[autoload\]/ { inside = 1; print; next }
	inside && /^\[/  { print line; print ""; inside = 0; done = 1 }
	{ print }
	END { if (inside && !done) print line }
' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

grep -q '^MCPBridge=' "$CONFIG" || die "не зміг дописати автозавантаження в $CONFIG"

say "→ запускаю гру. Міст зникне, щойно закриєте вікно."
GODOT_MCP_BRIDGE_PORT="$PORT" "$GODOT" --path "$PROJECT" "$@"
