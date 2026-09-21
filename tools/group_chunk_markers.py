#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""group_chunk_markers.py — розкласти маркери чанка по ТЕКАХ за роллю.

Навіщо. Маркери лежали в чанку пласким списком під коренем LevelLayout. Поки їх два-три
десятки, це ще читається; замороженого рівня виходить ~900 маркерів на чанк, і пласким
списком автор у ньому не знайде нічого. Тека на роль («Декор», «Перешкоди», …) згортається
одним кліком, і видно структуру, а не стрічку імен.

Що робить із кожним levels/level_XX/chunk_NN.tscn:
  1. читає роль кожного маркера (рядок role = "..."; його може НЕ БУТИ — Godot не пише
     властивість, що дорівнює типовій, тобто маркер без role це decor);
  2. створює під коренем по вузлу-теці Node3D на кожну ВЖИВАНУ роль — у позиції 0,0,0,
     без transform і без скрипта (порожніх тек не створює);
  3. переносить маркери під свої теки, зберігаючи їхній порядок усередині ролі.

Чому гра від цього не міняється:
  * LevelTimeline._collect() обходить дерево РЕКУРСИВНО, тож вкладення він переживе;
  * маркер віддає z із marker.position, тобто з ЛОКАЛЬНОЇ позиції — доки тека стоїть у
    0,0,0, координати маркерів лишаються тими самими числами (саме тому теці НЕ МОЖНА
    дописувати transform: зсунута тека мовчки поїде всім рівнем);
  * порядок усередині кожного масиву ролі теж не міняється: _collect() спершу проходить
    дітей теки «Декор», потім «Перешкоди» — тобто відносний порядок decor-маркерів між
    собою той самий, що й у пласкому списку.

Запуск:
    python3 tools/group_chunk_markers.py            # переписати всі чанки
    python3 tools/group_chunk_markers.py --dry      # лише показати, що зміниться

Перевірка вбудована: скрипт звіряє набір маркерів (тіло блоку) до і після й відмовляється
писати, якщо він розійшовся хоч на один рядок. Сторож у тестах —
tests/test_level_chunk_groups.gd.
"""
import argparse
import glob
import re

# Ролі — ті самі, що LevelTimeline.ROLE_KEYS, у тому ж порядку. Іменем теки в сцені бачить
# автор рівня, тож воно українське, як і решта проєкту.
ROLE_FOLDERS = [
    ("decor", "Декор"),
    ("obstacle", "Перешкоди"),
    ("pickup", "Пікапи"),
    ("gold", "Золото"),
    ("building", "Будівлі"),
    ("landmark", "Орієнтири"),
    ("wall_near", "Стіни"),
]
FOLDER_BY_ROLE = dict(ROLE_FOLDERS)
FOLDER_NAMES = set(FOLDER_BY_ROLE.values())

NODE_HEAD_RE = re.compile(r'^\[node .*?\]$', re.M)
ROLE_RE = re.compile(r'^role = "([^"]*)"$', re.M)
PARENT_RE = re.compile(r'parent="([^"]*)"')
INDEX_RE = re.compile(r' index="\d+"')


def split_nodes(text):
    """Текст сцени → (шапка, [(рядок-заголовок, тіло), …]) у порядку файлу."""
    heads = list(NODE_HEAD_RE.finditer(text))
    if not heads:
        raise ValueError("у сцені немає жодного вузла")
    header = text[: heads[0].start()]
    blocks = []
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        blocks.append((m.group(0), text[m.end(): end]))
    return header, blocks


def role_of(body):
    """Роль маркера. Немає рядка role — значить типова, тобто decor."""
    m = ROLE_RE.search(body)
    return m.group(1) if m else "decor"


def group(text):
    """Перекладені по теках сцена. None — тут уже все розкладено."""
    header, blocks = split_nodes(text)
    root_head, root_body = blocks[0]
    if PARENT_RE.search(root_head):
        raise ValueError("перший вузол сцени не корінь")

    markers = []
    for head, body in blocks[1:]:
        parent = PARENT_RE.search(head)
        if parent is None:
            raise ValueError("вузол без parent=: %s" % head)
        if parent.group(1) != ".":
            return None                      # уже згруповано — не чіпаємо
        markers.append((head, body))
    if not markers:
        return None

    by_role = {}
    for head, body in markers:
        r = role_of(body)
        if r not in FOLDER_BY_ROLE:
            raise ValueError("невідома роль %r — її немає в LevelTimeline.ROLE_KEYS" % r)
        by_role.setdefault(r, []).append((head, body))

    out = [header.rstrip("\n"), root_head + "\n" + root_body.strip("\n")]
    for role, folder in ROLE_FOLDERS:
        if role not in by_role:
            continue                         # порожніх тек не створюємо
        # Тека — голий Node3D у 0,0,0: без transform (Godot не пише одиничний) і без скрипта.
        out.append('[node name="%s" type="Node3D" parent="."]' % folder)
        for head, body in by_role[role]:
            # index="N" був порядковим номером серед дітей КОРЕНЯ; усередині теки порядок
            # задає сам порядок рядків у файлі, тож номер стає зайвим і брехливим.
            head = INDEX_RE.sub("", head)
            head = head.replace('parent="."', 'parent="%s"' % folder, 1)
            out.append(head + "\n" + body.strip("\n"))
    return "\n\n".join(out) + "\n"


def markers_by_role(text):
    """{роль: [тіло, …]} у порядку файлу — цим звіряємо «до» і «після».

    Порядок УСЕРЕДИНІ ролі й є тим, що зобов'язана зберегти перекладка: саме в ньому
    LevelTimeline._collect() наповнює масив цієї ролі, і від нього залежить, що дістанеться
    грі при однакових z. Порядок МІЖ ролями значення не має — його перекладка й міняє.
    """
    _, blocks = split_nodes(text)
    out = {}
    for head, body in blocks[1:]:
        name = re.search(r'name="([^"]*)"', head).group(1)
        if name in FOLDER_NAMES and "script" not in body:
            continue                         # сама тека — не маркер
        out.setdefault(role_of(body), []).append(body.strip())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    files = sorted(glob.glob("levels/level_*/chunk_*.tscn"))
    if not files:
        raise SystemExit("чанків не знайдено — запускати з кореня проєкту")
    changed = 0
    for path in files:
        text = open(path, encoding="utf-8").read()
        out = group(text)
        if out is None:
            continue
        before = markers_by_role(text)
        after = markers_by_role(out)
        if before != after:
            raise SystemExit("%s: набір маркерів розійшовся — нічого не записано" % path)
        changed += 1
        if a.dry:
            print("%-34s %s" % (path, ", ".join(
                "%s %d" % (folder, len(before[role]))
                for role, folder in ROLE_FOLDERS if role in before)))
            continue
        open(path, "w", encoding="utf-8").write(out)
    print("%s: %d файлів із %d" % ("показано" if a.dry else "переписано", changed, len(files)))


main()
