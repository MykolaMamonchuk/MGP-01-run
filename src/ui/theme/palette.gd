## ЄДИНЕ ДЖЕРЕЛО КОЛЬОРІВ ГРИ (дизайн-токени).
## Правило: у жодному іншому .gd не має бути літерала "#RRGGBB" — лише Palette.ІМ'Я.
## Це стереже тест tests/test_palette.gd.
##
## Файл має три шари, і кожен використовує лише попередній:
##   1) ШКАЛА  — сирі відтінки, назва описує вигляд (GOLD, WOOD), не призначення;
##   2) РОЛІ   — призначення (BTN_PRIMARY, TEXT_HINT, WORLD_GROUND); беруться зі шкали;
##   3) НАБОРИ — готові градієнти/списки для частинок і веселки.
## Змінюєте вигляд гри — правите ролі; додаєте новий відтінок — спершу у шкалу.
##
## Кольори з data/*.json (світи, герої, предмети) — це дані, а не токени:
## читайте їх через Palette.of(значення, ЗАПАСНИЙ_ТОКЕН), щоб запасний варіант теж був звідси.
class_name Palette
extends RefCounted

# ─────────────────────────────── 1. ШКАЛА ───────────────────────────────

# жовті / золоті / кремові
const SUN := Color("#FFEE58")
const LEMON := Color("#FFF176")
const LEMON_PALE := Color("#FFF59D")
const HONEY := Color("#FDD835")
const GOLD := Color("#FFD54F")
const GOLD_BRIGHT := Color("#FFD740")
const GOLD_DEEP := Color("#F9A825")
const AMBER := Color("#FFCA28")
const AMBER_DEEP := Color("#FFB300")
const AMBER_DARK := Color("#FF8F00")
const CREAM := Color("#FFF8E1")
const CREAM_WARM := Color("#FFF3C4")
const CREAM_STONE := Color("#FFF3D6")
const SAND := Color("#F5E6B8")
const SAND_DEEP := Color("#FFE0A3")

# помаранчеві / червоні
const ORANGE := Color("#FFA726")
const APRICOT := Color("#FFB84D")
const PEACH := Color("#FFC59A")
const PEACH_DEEP := Color("#F7B58A")
const CORAL := Color("#FF8A65")
const CORAL_DEEP := Color("#FF7043")
const CORAL_PALE := Color("#FF9E80")
const EMBER := Color("#D84315")
const RED := Color("#EF5350")
const RED_BRIGHT := Color("#FF5252")
const RED_PALE := Color("#FF8A80")
const RED_DARK := Color("#C62828")

# рожеві / фіолетові
const PINK := Color("#F06292")
const PINK_DEEP := Color("#EC407A")
const PINK_BRIGHT := Color("#FF80AB")
const PINK_PALE := Color("#F8BBD0")
const PURPLE := Color("#AB47BC")
const ORCHID := Color("#CE93D8")
const MAGENTA := Color("#E040FB")
const LAVENDER := Color("#B39DDB")
const INDIGO := Color("#5C6BC0")
const INDIGO_DEEP := Color("#283593")

# зелені
const GREEN := Color("#66BB6A")
const GREEN_DEEP := Color("#43A047")
const GREEN_STEM := Color("#388E3C")
const GREEN_FOREST := Color("#2E7D32")
const GREEN_PALE := Color("#A5D6A7")
const MINT := Color("#69F0AE")
const LIME := Color("#C6FF00")
const GRASS := Color("#7CC46B")
const GRASS_SIDE := Color("#6DB35E")
const GRASS_DARK := Color("#5FA553")

# сині / бірюзові
const BLUE := Color("#42A5F5")
const BLUE_LIGHT := Color("#90CAF9")
const BLUE_PALE := Color("#B3E5FC")
const BLUE_MIST := Color("#E3F2FD")
const BLUE_HAZE := Color("#E1F5FE")
const SKY := Color("#9BDDFF")
const SKY_SEA := Color("#6EC1F5")
const ICE := Color("#8ED1FC")
const AZURE := Color("#40C4FF")
const WATER := Color("#4FC3F7")
const WATER_DEEP := Color("#29B6F6")
const CYAN := Color("#26C6DA")
const CYAN_PALE := Color("#80DEEA")

# дерево / нейтральні
const WOOD := Color("#8D6E63")
const WOOD_LIGHT := Color("#A1887F")
const WOOD_MID := Color("#795548")
const WOOD_DARK := Color("#5D4037")
const ESPRESSO := Color("#3E2723")
const SLATE := Color("#90A4AE")
const SLATE_DEEP := Color("#607D8B")
const SLATE_DARK := Color("#37474F")
const SLATE_PALE := Color("#ECEFF1")
const STEEL := Color("#B0BEC5")
const STEEL_PALE := Color("#CFD8DC")
const GREY := Color("#9E9E9E")
const GREY_DARK := Color("#616161")
const INK := Color("#263238")
const INK_SOFT := Color("#222831")
const WHITE := Color.WHITE
const CLEAR := Color(0, 0, 0, 0)

# ─────────────────────────────── 2. РОЛІ ────────────────────────────────

# текст
const TEXT := INK                        ## звичайна підпис-мітка на світлому
const TEXT_LIGHT := CREAM                ## підпис на темному/кольоровому тлі
const TEXT_TITLE := WHITE                ## заголовок з обведенням
const TEXT_OUTLINE := ESPRESSO           ## обведення заголовка
const TEXT_HINT := LEMON                 ## підказка «Тапни!»
const TEXT_SHADOW := Color(0, 0, 0, 0.35)

# кнопки (одна роль = один намір, не «синя кнопка»)
const BTN_PRIMARY := GREEN               ## головна дія: Біжимо!, Далі!, Обрати
const BTN_NAV := BLUE                    ## навігація: ‹ ›, Мапа, вкладки
const BTN_HEROES := ORANGE               ## герої / купити
const BTN_SHOP := PURPLE                 ## крамниця
const BTN_BACK := WOOD                   ## назад
const BTN_SETTINGS := SLATE              ## службова кнопка

# поверхні
const PANEL := CREAM                     ## паперова панель, картка предмета
const SHADOW := Color(0, 0, 0, 0.25)     ## тінь кнопки/панелі
const STICK := Color(1, 1, 1, 0.9)       ## джойстик під пальцем
const STICK_KNOB := APRICOT

# значення й стани
const STAR := GOLD
const STAR_EDGE := GOLD_DEEP
const HEART := RED_BRIGHT
const HEART_EMPTY := Color(0.6, 0.6, 0.6, 0.7)
const LOCKED := GREY                     ## закритий рівень/герой
const ITEM_EQUIPPED := GREEN             ## рамка: одягнуто
const ITEM_OWNED := BLUE_LIGHT           ## рамка: куплено
const ITEM_PLAIN := STEEL_PALE           ## рамка: ще не куплено
const TAB_ACTIVE := CREAM
const PROGRESS := GREEN                  ## дуга прогресу в жесті

# спалахи-повідомлення HUD
const FLASH_REWARD := GOLD               ## +зірочки, новий рівень
const FLASH_GO := MINT                   ## Біжимо!
const FLASH_COUNT := LEMON               ## 3-2-1
const FLASH_RETRY := CORAL               ## Ще раз!, Фініш близько!
const FLASH_WIDTH := CYAN_PALE           ## Ширше!/Вужче!
const LEVEL_DONE := CORAL_DEEP           ## «Ура! Рівень N»

# мапа світів
const MAP_SEA := SKY_SEA
const MAP_ISLAND_EDGE := WOOD
const MAP_ISLAND_SAND := SAND
const MAP_STONE := CREAM_STONE
const MAP_LABEL := ESPRESSO
const MAP_PAPER := CREAM
const MAP_BADGE_FLASH := RED_PALE       ## плашка ціни блимає: «не вистачає зірочок»
const MAP_BADGE_BG := Color(0.24, 0.15, 0.14, 0.92)
const MAP_BADGE_EDGE := Color(0, 0, 0, 0.35)
const MAP_NODE_AHEAD := Color(0.75, 0.7, 0.68, 0.55)   ## камінці стежки за поточним вузлом
const LOCK_BODY := CREAM
const LOCK_HOLE := GREY_DARK
const MARKER_SHADOW := Color(0, 0, 0, 0.2)
const EYE_WHITE := WHITE

# ілюстрації іконок (src/ui/components/icons.gd) — назва каже, ЩО малюємо, а не яким відтінком
const ICON_EDGE := ESPRESSO              ## спільна темна обвідка іконок
const ICON_PAPER := CREAM                ## аркуш мапи, крапки характеристик
const ICON_METAL := SLATE_PALE           ## шестірня
const ICON_METAL_HOLE := SLATE_DEEP
const ICON_ADULT := INDIGO
const ICON_KID := CORAL
const ICON_HAND := WHITE
const ICON_HAND_EDGE := SLATE_DARK
const ICON_MOON := CREAM_WARM
const ICON_MOON_BACK := Color(0.05, 0.05, 0.2, 1.0)
const ICON_SIGN := WATER                 ## щит станції
const ICON_SIGN_DOT := WHITE
const ICON_POLE := WOOD
const ICON_TREE_TRUNK := WOOD_MID
const ICON_TREE_CROWN := GREEN_FOREST
const ICON_TREE_LEAF := GREEN_DEEP
const ICON_SUN := SUN
const ICON_WAVE := WATER_DEEP
const ICON_BEACH := SAND_DEEP
const ICON_MEADOW := GRASS
const ICON_STEM := GREEN_STEM
const ICON_PETAL := PINK
const ICON_FLOWER_EYE := LEMON
const ICON_GESTURE := LEMON               ## пальчик/стрілка підказки жесту
const ICON_MISSING := STEEL               ## перекреслене коло «нема воксела»
const ICON_GLASS := BLUE_PALE             ## скельця окулярів
const ICON_SCARF := RED
const ICON_SCARF_KNOT := RED_DARK
const ICON_HAT_BAND := RED
const ICON_MAP_START := GREEN             ## кружечок «звідки» на мапі-глифі
const ICON_MAP_END := RED                 ## кружечок «куди»
const ICON_MAP_PATH := WOOD
const ICON_FLAG := RED                    ## прапорець «пройдено»
const ICON_EVENT := CYAN                  ## промінчики події
const ICON_EVENT_CORE := WHITE

# характеристики героя (GDD v1.3 §5)
const STAT_HEART := RED
const STAT_MAGNET_N := RED                ## північний полюс магніта
const STAT_MAGNET_S := BLUE               ## південний
const STAT_MAGNET_TIP := STEEL            ## сірі наконечники
const STAT_SPEED := GOLD                  ## блискавка
const STAT_LUCK := ORCHID                 ## чотирикутна зірка
const STAT_DOT_EMPTY := Color(1, 1, 1, 0.25)

# 3D: герой
const HERO_DEFAULT := APRICOT            ## запасний колір героя (data/heroes.json)
const HERO_EYE := INK_SOFT
const HERO_CHEEK := RED_PALE
const HERO_MOUTH := WOOD_DARK
const HERO_SHIELD := AZURE
const HERO_GLOW := LEMON                 ## Ліхтарик
const HERO_GHOST := GREY                 ## невразливість після удару
const FRIEND_DEFAULT := ICE

# 3D: світ (запасні значення для data/worlds/*.json)
const WORLD_GROUND := GRASS
const WORLD_GROUND_DARK := GRASS_DARK
const WORLD_SIDE := GRASS_SIDE
const WORLD_ACCENT := PINK               ## акцент світу: двері Розвилки, вузли мапи
const WORLD_WATER := WATER
const WORLD_WATER_DARK := WATER_DEEP
const SKY_DAY := SKY
const SKY_EVENING := PEACH_DEEP
const SKY_NIGHT := INDIGO_DEEP
const SUN_EVENING := PEACH
const GROUND_TINT_NONE := WHITE          ## сезон без підфарбовування

# 3D: об'єкти траси
const TIER2_PLATFORM := WOOD_LIGHT
const TIER2_EDGE := WOOD
const TIER2_RAIL := GOLD
const GATE_POST := WOOD
const GATE_POST_ALT := WOOD_LIGHT
const GATE_CAP := GOLD
const GATE_FLAG_LEFT := MINT
const GATE_FLAG_RIGHT := AZURE
const GATE_CHECKER := RED_BRIGHT
const GATE_CHECKER_ALT := WHITE
const OBSTACLE_STRIPE := RED
const OBSTACLE_STRIPE_ALT := WHITE
const SPLASH_WATER := BLUE_LIGHT
const SPLASH_GRASS := GREEN_PALE
const PICKUP_DEFAULT := WHITE            ## запасний колір пікапа (data/pickups.json)

# ─────────────────────────────── 3. НАБОРИ ──────────────────────────────

## Веселка (rainbow3d): шість смуг згори вниз.
const RAINBOW: Array[Color] = [RED_BRIGHT, ORANGE, SUN, GREEN, BLUE, PURPLE]

## Кольори літер заголовка меню — по одній на літеру «Біжи-біжи».
const TITLE_LETTERS: Array[Color] = [CORAL_DEEP, AMBER, GREEN, BLUE, PURPLE, PINK_DEEP, CYAN, ORANGE, WOOD]

## Сектори колеса призів.
const WHEEL_SECTORS: Array[Color] = [BLUE, GREEN, AMBER, RED, CYAN, ORANGE, PURPLE, PINK_DEEP]

## Градієнти частинок (FX._ramp).
const RAMP_CONFETTI: Array[Color] = [RED_BRIGHT, GOLD_BRIGHT, MINT, AZURE, MAGENTA, CORAL_PALE]
const RAMP_SPARKLE: Array[Color] = [WHITE, LEMON_PALE, GOLD]
const RAMP_HEARTS: Array[Color] = [PINK_BRIGHT, PINK_PALE]

## Градієнти атмосфери світу/сезону за видом (FX.ambient).
const RAMP_AMBIENT := {
	"petals": [PINK_PALE, WHITE, PINK],
	"leaves": [AMBER_DARK, EMBER, HONEY],
	"snow": [WHITE, BLUE_MIST],
	"glints": [WHITE, BLUE_PALE],
	"fireflies": [LEMON_PALE, LIME],
	"rain": [BLUE_PALE, BLUE_HAZE],
	"stars": [WHITE, LEMON_PALE, LAVENDER],
}

# ────────────────────────────── 4. ПОМІЧНИКИ ────────────────────────────

## Колір із даних: рядок "#RRGGBB" з JSON або запасний токен, якщо ключа/значення нема.
## Некоректний рядок теж дає запасний — дані з диска не мають ронити гру.
static func of(value: Variant, fallback: Color) -> Color:
	if typeof(value) == TYPE_STRING and Color.html_is_valid(String(value)):
		return Color(String(value))
	if value is Color:
		return value
	return fallback
