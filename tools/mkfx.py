#!/usr/bin/env python3
"""Make the attack pictures (the reference's drawSwing and drawStrike, one frame each) for the CoCo.

    mkfx.py ICONS.json src/fxpics.asm src/fxid.inc     (make shapes runs it; kept in src/, so a normal
                                                       build doesn't need gjs)

Each picture is worked out here in screen terms, at one moment of the reference's animation, already
clipped to the view (640 x VIEWH), so the game only draws lines:
  * swing (FX_SWING + item kind, or FX_FIST): your attack with the right hand. A held item sweeps in
    an arc from the side (the reference's faint motion trail behind it is left out, Steve); a shield or an
    empty hand thrusts forward instead. The left hand is the mirror image (the game flips x).
  * strike (FX_STRIKE + style x 4 + side): a monster's blow, on the side it came from (0 front, 1 right,
    2 behind, 3 left): three claw rakes, a blade arc or an impact burst. The reference picks the
    sweep's direction at random; the game flips x about the mark's centre for the other one.
  * sparks (FX_SPARK + side): drawn as well when your shield blocks the blow.
  * FX_STRIKE2 + style x 2 + (side 3): claw and blade marks at the sides swept the other way (a flip
    of the FX_STRIKE one would run off the screen).

Format (bank BANKSND from $D100, FXTAB): a table of pointers, then per picture: the mirror sum M
(2 bytes: a flipped x is M - x), then polylines: points (0 ends), colour byte, dot pattern, then
points as x / 2.5 (one byte: CoCo pixels are about 2.5 times taller than wide, so that's as fine as a
row) and y. At most 24 points a polyline (the game's ptbuf).
"""
import json
import math
import sys

sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mkicons import hide, simplify, KINDS      # noqa: E402

W, VH = 800.0, 440.0                 # the reference's view
CX, CY = W / 2, VH / 2
SW, SH = 640, 136                    # the CoCo's view (VIEWH)
KX, KY = SW / W, SH / VH
GREEN, RED, BLUE = 0x55, 0xAA, 0xFF
SOLID, HALF, QUARTER = 0xFF, 0xAA, 0x88
MAXPTS = 24

FIST = [[[-0.28, 0], [-0.3, 0.3], [-0.22, 0.42], [0.22, 0.42], [0.3, 0.3], [0.28, 0], [-0.28, 0]],
        [[-0.12, 0.28], [-0.12, 0.42]], [[0.02, 0.28], [0.02, 0.42]], [[0.15, 0.28], [0.15, 0.42]],
        [[-0.3, 0.2], [-0.05, 0.16], [0.08, 0.22]]]
SHIELDS = ('buckler', 'tower')
SWING_T = 0.45                       # the moment shown: mid-sweep / the thrust at its furthest
TRAIL_T = 0.30                       # (the trail's moment; not drawn)
STYLES = ['claw', 'blade', 'crush']  # (the game's table maps monster kinds to these)


def clip(a, b, x0, x1, y0=0.0, y1=SH - 1):
    """Liang-Barsky: the part of segment a-b inside the box, or None."""
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t0, t1 = 0.0, 1.0
    for p, q in ((-dx, ax - x0), (dx, x1 - ax), (-dy, ay - y0), (dy, y1 - ay)):
        if abs(p) < 1e-12:
            if q < 0:
                return None
            continue
        r = q / p
        if p < 0:
            t0 = max(t0, r)
        else:
            t1 = min(t1, r)
        if t0 > t1:
            return None
    return (ax + dx * t0, ay + dy * t0), (ax + dx * t1, ay + dy * t1)


def clippoly(pts, x0, x1):
    """Split a polyline into the pieces inside the view (x from x0 to x1)."""
    out, cur = [], []
    for a, b in zip(pts, pts[1:]):
        c = clip(a, b, x0, x1)
        if c is None:
            if len(cur) > 1:
                out.append(cur)
            cur = []
            continue
        p, q = c
        if cur and (abs(cur[-1][0] - p[0]) > 1e-6 or abs(cur[-1][1] - p[1]) > 1e-6):
            if len(cur) > 1:
                out.append(cur)
            cur = []
        if not cur:
            cur = [p]
        cur.append(q)
    if len(cur) > 1:
        out.append(cur)
    return out


class Pic:
    def __init__(self, mirror):
        self.m = mirror                  # M: flipped x = M - x
        self.lines = []                  # (colour, pattern, [(x, y)...]) in CoCo pixels

    def add(self, pts_ref, col, pat):
        """Points in the reference's view coordinates."""
        pts = [(x * KX, y * KY) for x, y in pts_ref]
        lo, hi = max(0, self.m - (SW - 1)), min(SW - 1, self.m)
        for piece in clippoly(pts, lo, hi):
            # simplify in square-ish units (x counts 0.4: pixels are ~2.5 times taller than wide)
            piece = simplify(piece, 1.0, 1.0, tol=1.5)
            q = [(min(255, round(x / 2.5)), round(y)) for x, y in piece]     # x in 2.5-pixel steps
            q = [p for i, p in enumerate(q) if i == 0 or p != q[i - 1]]
            if len(q) < 2:
                continue
            for k in range(0, len(q) - 1, MAXPTS - 1):
                self.lines.append((col, pat, q[k:k + MAXPTS]))

    def asm(self, label):
        out = ['%s fdb     %d' % (label, self.m)]
        for col, pat, q in self.lines:
            out.append('        fcb     %d,$%02X,$%02X' % (len(q), col, pat))
            out.append('        fcb     ' + ','.join('%d,%d' % (x, y) for x, y in q))
        out.append('        fcb     0')
        return out


def transform(polys, f):
    return [[f(x, y) for x, y in p] for p in polys]


def swing(polys, shield_or_fist, col):
    """drawSwing for the right hand (sgn = +1) at SWING_T."""
    p = Pic(SW - 1)
    sgn = 1
    if not shield_or_fist:
        s, px, py = 380.0, CX + sgn * 300, VH + 30

        def at(u, k):
            e = 1 - (1 - min(1, max(0, u))) ** 3
            a = sgn * (0.35 - 1.5 * e)
            ca, sa = math.cos(a), math.sin(a)

            def f(x, y):
                X, Y = x * s, 0.1 * s - y * s
                return (px + X * ca - Y * sa, py + X * sa + Y * ca)
            return f
        # (the reference's faint motion trail at TRAIL_T is left out: Steve, 2026-11-20)
        for q in transform(hide(polys), at(SWING_T, 0)):
            p.add(q, col, SOLID)
    else:
        e = math.sin(min(1.0, 0.5) * math.pi)                 # out and back: at its furthest
        x, y = CX + sgn * (300 - 190 * e), VH + 40 - 170 * e
        s = (300 if polys is FIST else 360) * (1 - 0.35 * e)
        for q in transform(hide(polys), lambda px_, py_: (x + px_ * s, y - py_ * s)):
            p.add(q, col, SOLID)
    return p


def strike(style, rel, d=1):
    """drawStrike fully drawn in (e = 1), a hit, sweeping with d. A picture for d = +1 can be flipped
    (about the mark's centre) for d = -1, but that flip only fits on the screen for the front and the
    back: the sides have their own d = -1 pictures (FX_STRIKE2), which aren't flipped."""
    ox, oy, sc = [(CX, CY - 10, 1), (W * 0.86, CY, 0.7), (CX, VH - 70, 0.7), (W * 0.14, CY, 0.7)][rel]
    p = Pic(round(2 * ox * KX) if d == 1 and rel in (0, 2) else SW - 1)     # (SW - 1: full width)
    if style == 'claw':
        for i in (-1, 0, 1):
            pts = []
            for j in range(9):
                u = j / 8
                pts.append((ox + d * sc * (-150 + 300 * u) + i * 34 * sc,
                            oy + sc * (-120 + 240 * u) - math.sin(u * math.pi) * 30 * sc))
            p.add(pts, RED, SOLID)
            if i == 0:                                         # (the middle rake is the widest: twice)
                p.add([(x + 2, y + 3) for x, y in pts], RED, SOLID)
    elif style == 'blade':
        R, rot = 230 * sc, d * 0.35
        cr, sr = math.cos(rot), math.sin(rot)
        pts = []
        for j in range(15):
            ang = -0.9 + 1.8 * j / 14
            x, y = d * math.sin(ang) * R, math.cos(ang) * R - R + 30 * sc
            pts.append((ox + x * cr - y * sr, oy + x * sr + y * cr))
        p.add(pts, RED, SOLID)
        p.add([(x, y + 4) for x, y in pts], RED, SOLID)       # (it's wide)
        p.add([(x, y - 14 * sc) for x, y in pts], RED, HALF)
    else:
        r0, r1 = 30 * sc, 30 * sc + 130 * sc
        for i in range(10):
            ang = i / 10 * math.pi * 2 + 0.3
            k = 0.7 if i % 2 else 1
            p.add([(ox + math.cos(ang) * r0, oy + math.sin(ang) * r0),
                   (ox + math.cos(ang) * r1 * k, oy + math.sin(ang) * r1 * k)], RED, SOLID)
        r = r0 + 60 * sc
        p.add([(ox + math.cos(a / 16 * 2 * math.pi) * r, oy + math.sin(a / 16 * 2 * math.pi) * r)
               for a in range(17)], RED, SOLID)
    return p


def sparks(rel):
    ox, oy, sc = [(CX, CY - 10, 1), (W * 0.86, CY, 0.7), (CX, VH - 70, 0.7), (W * 0.14, CY, 0.7)][rel]
    p = Pic(round(2 * ox * KX))
    r = 60
    for i in range(7):
        ang = i / 7 * math.pi * 2
        p.add([(ox + math.cos(ang) * r * 0.4, oy + math.sin(ang) * r * 0.4),
               (ox + math.cos(ang) * r, oy + math.sin(ang) * r)], BLUE, SOLID)
    return p


def main():
    icons = json.load(open(sys.argv[1]))
    pics, names = [], []
    for k in KINDS:
        pics.append(swing(icons[k], k in SHIELDS, BLUE))
        names.append('fx_' + k)
    pics.append(swing(FIST, True, GREEN))
    names.append('fx_fist')
    for st in STYLES:
        for rel in range(4):
            pics.append(strike(st, rel))
            names.append('fx_%s%d' % (st, rel))
    for rel in range(4):
        pics.append(sparks(rel))
        names.append('fx_spark%d' % rel)
    for st in STYLES[:2]:                        # claw and blade at the sides, swept the other way
        for rel in (1, 3):
            pics.append(strike(st, rel, -1))
            names.append('fx_%s%dr' % (st, rel))
    out = ['* Made by tools/mkfx.py from the reference (make shapes). Do not edit.',
           '        org     $D100',
           'fxtab   fdb     ' + ','.join(names[:8])]
    for i in range(8, len(names), 8):
        out.append('        fdb     ' + ','.join(names[i:i + 8]))
    for n, p in zip(names, pics):
        out += p.asm(n)
    out.append('fxend')
    open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
    inc = ['* Made by tools/mkfx.py. Do not edit.',
           'FXTAB   equ     $D100           ; (in BANKSND)',
           'FX_SWING equ    0               ; + item kind',
           'FX_FIST equ     %d' % len(KINDS),
           'FX_STRIKE equ   %d               ; + style x 4 + side (claw, blade, crush)' % (len(KINDS) + 1),
           'FX_SPARK equ    %d               ; + side' % (len(KINDS) + 1 + 4 * len(STYLES)),
           'FX_STRIKE2 equ  %d               ; + style x 2 + (side = left): the sides swept the other way'
           % (len(KINDS) + 1 + 4 * len(STYLES) + 4)]
    open(sys.argv[3], 'w').write('\n'.join(inc) + '\n')
    pts = sum(len(q) for p in pics for _, _, q in p.lines)
    print('%s: %d pictures, %d lines, %d points, ~%d bytes' % (
        sys.argv[2], len(pics), sum(len(p.lines) for p in pics), pts,
        2 * len(pics) + sum(3 + sum(3 + 2 * len(q) for _, _, q in p.lines) for p in pics)))


if __name__ == '__main__':
    main()
