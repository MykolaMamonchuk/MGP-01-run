#!/usr/bin/env python3
"""Порівняння НАШОГО ока з референсною текстурою — числами, а не «на око».

Навіщо. Підбирати вигляд ока за скріншотом «схоже / не схоже» виявилось безнадійним: я
дивився, казав «близько», а воно було геть інше. Цей скрипт міряє те саме на обох картинках
і показує різницю у відсотках, тож «схоже» стає перевіркою, а не думкою.

Що міряє (усе нормоване до діаметра ока, тож масштаб і кроп не важливі):
  iris/eye        — діаметр райдужки до діаметра ока
  pupil/iris      — площа темної (зіничної) частини до площі райдужки
  iris offset     — на скільки центр райдужки зсунутий від центру ока (частки діаметра)
  білок л/п, в/н  — скільки білка видно ліворуч проти праворуч і згори проти знизу. Саме це
                    ловить «райдужка з'їхала з білка»: центроїд такого зсуву НЕ бачить, бо
                    темна зіниця й тепла облямівка навколо неї врівноважують одна одну
  hi_big/iris     — діаметр більшого блика до діаметра райдужки, і де він сидить
  hi_small/iris   — те саме для меншого

Запуск:
    python3 tools/eye_similarity.py <наш_рендер.png> <референс.png>

Обидві картинки — квадратний кроп, де око займає більшу частину кадру, а решта — хутро.
Референс беремо з ОРИГІНАЛЬНОЇ текстури (docs/refs/models/fox/fox_meshy_Image_0.jpg),
там очі ще запечені — див. docs/tasks/rig.md.
"""
import sys
from PIL import Image


def classify(px):
    """Груба класифікація пікселя ока: 'white' | 'dark' | 'mid' | 'bg'."""
    r, g, b = px[0], px[1], px[2]
    mx, mn = max(r, g, b), min(r, g, b)
    # білок і блики — світле й майже без насиченості
    if r > 200 and g > 190 and b > 175 and (mx - mn) < 70:
        return "white"
    # зіниця — темне
    if mx < 110:
        return "dark"
    # райдужка — коричневе: помітно темніше за руде хутро й менш насичене
    if r < 190 and g < 150 and b < 130:
        return "mid"
    return "bg"


def measure(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    masks = {"white": [], "dark": [], "mid": []}
    for y in range(h):
        for x in range(w):
            k = classify(px[x, y])
            if k != "bg":
                masks[k].append((x, y))

    eye = masks["white"] + masks["dark"] + masks["mid"]
    if not eye:
        raise SystemExit("%s: ока не знайдено — перевір кроп/кольори" % path)

    def centroid(pts):
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))

    def diameter(pts):
        return 2.0 * (len(pts) / 3.14159265) ** 0.5

    eye_c = centroid(eye)
    eye_d = diameter(eye)

    iris = masks["dark"] + masks["mid"]
    iris_c = centroid(iris) if iris else eye_c
    iris_d = diameter(iris) if iris else 0.0

    # Блики — білі плями ВСЕРЕДИНІ райдужки. Радіус свідомо менший за саму райдужку
    # (0.42, а не 0.5): білок теж білий, і на межі він інакше затягувався в «блик».
    hi = [p for p in masks["white"]
          if ((p[0] - iris_c[0]) ** 2 + (p[1] - iris_c[1]) ** 2) ** 0.5 < iris_d * 0.42]
    blobs = split_blobs(hi)
    blobs.sort(key=len, reverse=True)

    # центр райдужки беремо ЗА ОХОПЛЮВАЛЬНОЮ РАМКОЮ, а не за центроїдом: центроїд темної
    # зіниці й теплої облямівки лягає майже в центр навіть тоді, коли вся райдужка з'їхала
    # з білка — на цьому вимір нас уже одного разу обдурив.
    iris_box = box_center(iris) if iris else eye_c
    eye_box = box_center(eye)
    # білок поза райдужкою: скільки його ліворуч/праворуч і згори/знизу від центру ока
    sclera = [p for p in masks["white"]
              if ((p[0] - iris_c[0]) ** 2 + (p[1] - iris_c[1]) ** 2) ** 0.5 > iris_d * 0.42]
    n = len(sclera) or 1
    left = sum(1 for p in sclera if p[0] < eye_box[0]) / n
    top = sum(1 for p in sclera if p[1] < eye_box[1]) / n

    out = {
        "iris/eye": iris_d / eye_d if eye_d else 0.0,
        "pupil/iris": len(masks["dark"]) / len(iris) if iris else 0.0,
        "iris dx": (iris_box[0] - eye_box[0]) / eye_d if eye_d else 0.0,
        "iris dy": (iris_box[1] - eye_box[1]) / eye_d if eye_d else 0.0,
        "білок ліворуч": left,
        "білок згори": top,
    }
    for i, name in enumerate(["hi_big", "hi_small"]):
        if i < len(blobs):
            c = centroid(blobs[i])
            out["%s/iris" % name] = diameter(blobs[i]) / iris_d if iris_d else 0.0
            out["%s dx" % name] = (c[0] - iris_c[0]) / iris_d if iris_d else 0.0
            out["%s dy" % name] = (c[1] - iris_c[1]) / iris_d if iris_d else 0.0
        else:
            out["%s/iris" % name] = 0.0
            out["%s dx" % name] = 0.0
            out["%s dy" % name] = 0.0
    return out


def box_center(pts):
    """Центр охоплювальної рамки — на відміну від центроїда, не залежить від того,
    як усередині розподілені темні й світлі частини."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return ((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0)


def split_blobs(points):
    """Розбити набір точок на зв'язні плями (проста заливка по сусідах)."""
    todo = set(points)
    blobs = []
    while todo:
        seed = todo.pop()
        blob = [seed]
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in todo:
                        todo.discard(n)
                        blob.append(n)
                        stack.append(n)
        if len(blob) > 20:        # дрібний шум по краях не рахуємо за блик
            blobs.append(blob)
    return blobs


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    ours, ref = measure(sys.argv[1]), measure(sys.argv[2])
    print("%-14s %8s %8s %9s" % ("параметр", "наше", "референс", "різниця"))
    print("-" * 44)
    worst = 0.0
    for key in ref:
        o, r = ours[key], ref[key]
        # для відносних розмірів різниця у відсотках, для зсувів — в абсолютних частках
        diff = abs(o - r)
        worst = max(worst, diff)
        print("%-14s %8.3f %8.3f %9.3f" % (key, o, r, diff))
    print("-" * 44)
    print("найбільше розходження: %.3f" % worst)


if __name__ == "__main__":
    main()
