# Usage: python tools/make_sphere_emblems.py ov_data/gfx/spheres   (needs Pillow)
"""The own set of the emblems of the spheres (ov_data/gfx/spheres): white figures on a transparent ground, 256x256, drawn at 4x and scaled down.
The game tints them (the shield in the colour of the sphere, the emblem in a colour of the palette)."""
import math
import os
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1]
S = 1024  # drawing size
W = (255, 255, 255, 255)
os.makedirs(os.path.join(OUT, 'emblems'), exist_ok=True)


def new():
    return Image.new('RGBA', (S, S), (0, 0, 0, 0))


def save(im, name):
    im.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, name))


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rotate(pts, cx, cy, deg):
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in pts]


# ---- the shield (the ground of an emblem of the own set)
def shield_points(margin):
    left, right, top = 150 + margin, S - 150 - margin, 110 + margin
    pts = [(left, top), (S / 2, top + 40), (right, top)]
    # the sides go down and curve to the point
    for i in range(0, 41):
        t = i / 40
        x = right - (right - S / 2) * (t ** 2.2)
        y = top + 420 + (S - 90 - margin - top - 420) * math.sin(t * math.pi / 2)
        pts.append((x, y))
    for i in range(40, -1, -1):
        t = i / 40
        x = left + (S / 2 - left) * (t ** 2.2)
        y = top + 420 + (S - 90 - margin - top - 420) * math.sin(t * math.pi / 2)
        pts.append((x, y))
    return pts


im = new()
ImageDraw.Draw(im).polygon(shield_points(0), fill=W)
save(im, 'shield.png')
im = new()
ImageDraw.Draw(im).polygon(shield_points(34), fill=W)
save(im, 'shield_inner.png')

C = S / 2
CY = S / 2 + 10


def emblem(name, draw_fn):
    im = new()
    draw_fn(ImageDraw.Draw(im), im)
    save(im, os.path.join('emblems', name + '.png'))


emblem('01_star', lambda d, im: d.polygon(star_points(C, CY, 260, 105), fill=W))


def cross(d, im):
    t = 90
    d.rectangle((C - t, CY - 280, C + t, CY + 280), fill=W)
    d.rectangle((C - 250, CY - t - 60, C + 250, CY + t - 60), fill=W)


emblem('02_cross', cross)


def crescent(d, im):
    d.ellipse((C - 260, CY - 260, C + 260, CY + 260), fill=W)
    d.ellipse((C - 160, CY - 250, C + 300, CY + 210), fill=(0, 0, 0, 0))
    d.polygon(star_points(C + 140, CY - 40, 95, 38, rot=-90), fill=W)


emblem('03_crescent_star', crescent)


def sun(d, im):
    for i in range(16):
        a = math.radians(i * 22.5)
        a1, a2 = a - math.radians(6), a + math.radians(6)
        r1, r2 = 170, 300 if i % 2 == 0 else 250
        d.polygon([(C + r1 * math.cos(a1), CY + r1 * math.sin(a1)), (C + r2 * math.cos(a), CY + r2 * math.sin(a)),
                   (C + r1 * math.cos(a2), CY + r1 * math.sin(a2))], fill=W)
    d.ellipse((C - 160, CY - 160, C + 160, CY + 160), fill=W)


emblem('04_sun', sun)


def gear(d, im):
    teeth = 12
    pts = []
    for i in range(teeth * 4):
        a = math.radians(i * 360 / (teeth * 4))
        r = 285 if (i % 4) in (1, 2) else 225
        pts.append((C + r * math.cos(a), CY + r * math.sin(a)))
    d.polygon(pts, fill=W)
    d.ellipse((C - 95, CY - 95, C + 95, CY + 95), fill=(0, 0, 0, 0))


emblem('05_gear', gear)


def anchor(d, im):
    d.ellipse((C - 70, CY - 330, C + 70, CY - 190), outline=W, width=42)
    d.rectangle((C - 30, CY - 200, C + 30, CY + 250), fill=W)
    d.rectangle((C - 170, CY - 150, C + 170, CY - 100), fill=W)
    d.arc((C - 250, CY - 50, C + 250, CY + 290), 20, 160, fill=W, width=55)
    d.polygon([(C - 270, CY + 60), (C - 190, CY + 40), (C - 250, CY + 140)], fill=W)
    d.polygon([(C + 270, CY + 60), (C + 190, CY + 40), (C + 250, CY + 140)], fill=W)


emblem('06_anchor', anchor)


def crown(d, im):
    base = CY + 150
    pts = [(C - 280, base), (C - 300, CY - 170), (C - 150, CY - 20), (C, CY - 230), (C + 150, CY - 20), (C + 300, CY - 170), (C + 280, base)]
    d.polygon(pts, fill=W)
    d.rectangle((C - 290, base + 25, C + 290, base + 95), fill=W)
    for x, y in ((C - 300, CY - 190), (C, CY - 255), (C + 300, CY - 190)):
        d.ellipse((x - 42, y - 42, x + 42, y + 42), fill=W)


emblem('07_crown', crown)


def tower(d, im):
    d.rectangle((C - 170, CY - 160, C + 170, CY + 290), fill=W)
    for i in range(4):
        x = C - 170 + i * 95
        d.rectangle((x, CY - 260, x + 60, CY - 150), fill=W)
    d.rectangle((C - 70, CY + 110, C + 70, CY + 290), fill=(0, 0, 0, 0))
    d.ellipse((C - 70, CY + 40, C + 70, CY + 180), fill=(0, 0, 0, 0))
    d.rectangle((C - 30, CY - 70, C + 30, CY + 10), fill=(0, 0, 0, 0))


emblem('08_tower', tower)


def wheat(d, im):
    for side in (-1, 0, 1):
        stem_top = (C + side * 110, CY - 250)
        stem_bottom = (C + side * 30, CY + 300)
        d.line([stem_top, stem_bottom], fill=W, width=26)
        for k in range(6):
            t = k / 6
            x = stem_top[0] + (stem_bottom[0] - stem_top[0]) * t * 0.6
            y = stem_top[1] + (stem_bottom[1] - stem_top[1]) * t * 0.6
            for lr in (-1, 1):
                grain = [(x, y), (x + lr * 70, y - 40), (x + lr * 60, y + 30)]
                d.polygon(grain, fill=W)
        d.ellipse((stem_top[0] - 30, stem_top[1] - 70, stem_top[0] + 30, stem_top[1] + 20), fill=W)
    d.rectangle((C - 120, CY + 130, C + 120, CY + 175), fill=W)


emblem('09_wheat', wheat)


def swords(d, im):
    for deg in (40, -40):
        blade = [(C - 25, CY - 300), (C + 25, CY - 300), (C + 25, CY + 170), (C - 25, CY + 170)]
        tip = [(C - 25, CY - 300), (C, CY - 360), (C + 25, CY - 300)]
        guard = [(C - 110, CY + 170), (C + 110, CY + 170), (C + 110, CY + 210), (C - 110, CY + 210)]
        grip = [(C - 20, CY + 210), (C + 20, CY + 210), (C + 20, CY + 320), (C - 20, CY + 320)]
        for part in (blade, tip, guard, grip):
            d.polygon(rotate(part, C, CY, deg), fill=W)
        px, py = rotate([(C, CY + 345)], C, CY, deg)[0]
        d.ellipse((px - 40, py - 40, px + 40, py + 40), fill=W)


emblem('10_swords', swords)


def wreath(d, im):
    for side in (-1, 1):
        for k in range(9):
            a = math.radians(110 + k * 17) if side < 0 else math.radians(70 - k * 17)
            r = 250
            x, y = C + r * math.cos(a), CY + r * math.sin(a) - 20
            leaf = [(x, y - 55), (x + 26, y), (x, y + 55), (x - 26, y)]
            d.polygon(rotate(leaf, x, y, math.degrees(a) + 90 + side * 25), fill=W)
        d.arc((C - 250, CY - 270, C + 250, CY + 230), 95 if side < 0 else -5, 265 if side < 0 else 85, fill=W, width=18)
    d.polygon(star_points(C, CY - 20, 120, 50), fill=W)


emblem('11_wreath', wreath)


def eagle(d, im):
    # a simple heraldic bird: the body, the spread wings with feathers, the head, the tail
    d.ellipse((C - 75, CY - 140, C + 75, CY + 150), fill=W)
    d.ellipse((C - 55, CY - 250, C + 45, CY - 150), fill=W)
    d.polygon([(C + 40, CY - 215), (C + 110, CY - 195), (C + 40, CY - 175)], fill=W)
    for side in (-1, 1):
        for k in range(5):
            x0 = C + side * 60
            y0 = CY - 90 + k * 22
            x1 = C + side * (330 - k * 25)
            y1 = CY - 260 + k * 70
            d.polygon([(x0, y0 - 25), (x1, y1 - 18), (x1 - side * 20, y1 + 30), (x0, y0 + 25)], fill=W)
    d.polygon([(C - 60, CY + 120), (C + 60, CY + 120), (C + 120, CY + 300), (C, CY + 250), (C - 120, CY + 300)], fill=W)


emblem('12_eagle', eagle)
print('ok')
