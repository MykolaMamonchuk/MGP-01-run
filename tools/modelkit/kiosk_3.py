# -*- coding: utf-8 -*-
"""Кіоск за малюнком kiosk_3.jpg: той самий кіоск, що kiosk_2 (на малюнку він піксель у піксель
той самий), плюс табличка-мольберт ліворуч: восьмикутна помаранчево-брунатна дошка з вушком
угорі, світлі «букви» (напис SOIP у грі однаково не прочитати) і три ніжки — дві розведені
спереду й одна ззаду. Камінці й доріжку на підставці не робимо: підставку відрізає crop."""
import math

from kit import box, prism, soften
import kiosk_common as kc
import kiosk_2 as base

AZ = base.AZ      # кут камери заміру (refs/kiosk_3.json) — той самий, що в kiosk_2

# Палітра кіоска — спільна з kiosk_2 (це той самий кіоск); своє — лише мольберт.
PAL = dict(base.PAL, **{
    "easel_hi": "#D88048", "easel": "#C06C3C", "easel_lo": "#9A5230",
    "letter": "#F4EEE0",
})


def materials(k):
    m = base.materials(k)
    m["easel"] = k.mat_gradient("easel", [(0.0, "easel_lo"), (0.4, "easel"), (1.0, "easel_hi")], 0.0, 0.32, 0.15, 8.0)
    m["letter"] = k.mat_gradient("letter", [(0.0, "letter"), (1.0, "letter")], 0.0, 1.0, 0.0)
    return m


def easel(m, bev, fine=True):
    """Мольберт (лицем до −Y, у (0,0), ніжки на z=0)."""
    obs = []
    w, h, z0, c = 0.25, 0.18, 0.19, 0.04
    prof = [(-w / 2 + c, z0), (w / 2 - c, z0), (w / 2, z0 + c), (w / 2 - 0.012, z0 + h / 2), (w / 2, z0 + h - c),
            (w / 2 - c, z0 + h), (-w / 2 + c, z0 + h), (-w / 2, z0 + h - c), (-w / 2 + 0.012, z0 + h / 2), (-w / 2, z0 + c)]
    board = prism("easel_board", m["easel"], prof, -0.015, 0.015)
    soften(board, 0.008, bev)
    obs.append(board)
    obs.append(box("easel_tab", m["easel"], (0.0, 0.0, z0 + h + 0.012), (0.07, 0.026, 0.026)))
    # «SOIP» — чотири світлі брусочки
    for x in ((-0.066, -0.022, 0.022, 0.066) if fine else ()):
        obs.append(box("easel_letter", m["letter"], (x, -0.018, z0 + h / 2), (0.03, 0.006, 0.075)))
    # ніжки: дві спереду розведені, одна ззаду навскоси
    for sx in (-1, 1):
        leg = box("easel_leg", m["easel"], (sx * 0.04, 0.0, 0.11), (0.026, 0.02, 0.24),
                  rot=(0, math.radians(-sx * 12), 0))
        obs.append(leg)
    obs.append(box("easel_leg_back", m["easel"], (0.0, 0.055, 0.15), (0.024, 0.02, 0.31), rot=(math.radians(-20), 0, 0)))
    return obs


def build(m, k):
    info = base.build(m, k) or {}
    bev = min(2, k.DET["bev"])
    ex, ey = kc.cam_xy(AZ, -0.52, 0.23)
    kc.place(easel(m, bev, k.DET["bev"] > 1), (ex, ey), math.radians(AZ - 18))   # трохи відвернута ліворуч, як на малюнку
    return info
