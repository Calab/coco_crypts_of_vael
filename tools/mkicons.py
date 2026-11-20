#!/usr/bin/env python3
"""Turn the reference's vector shapes (JSON from tools/refshapes.js) into assembly.

    mkicons.py ICONS.json OUT.asm              item icons, in 1/100 units, table "icons"
    mkicons.py SHAPES.json OUT.asm --monsters  monsters, in 1/60 units (they're bigger), table "mshapes"

Each shape: number of polylines, then each polyline: number of points, its size (the larger of its
width and height, in the same units, so the renderer can skip details too small to see), then the
points as signed bytes (x across, y up from the floor). The table holds pointers in the reference's
ITEMS / MON order (= the K_ / M_ kind numbers in maze.asm).

Hidden lines are removed first, as the reference shows them: its drawPolys fills every closed
polyline (more than 3 points, first = last) in black just before stroking it, so it hides whatever
was drawn before it (the wraith's cloak folds behind its face, the hound's breastbone behind its
skull). The CoCo draws lines only, so here each line is cut where a later closed polyline covers it
(nonzero winding, as the canvas fills). Shapes are drawn flat and face-on, so this holds at any size.

Polylines are simplified (Douglas-Peucker) in screen terms at the largest size the shape is ever
drawn: a point is dropped if the line moves by less than TOL rows (x counts 0.4 of a pixel, since
CoCo 3 pixels are about 2.5 times taller than wide).
"""
import json
import sys

KINDS = ['dagger', 'axe', 'sword', 'hammer', 'rune', 'buckler', 'tower', 'torch', 'lantern', 'mending',
         'herb', 'vigor', 'map', 'relic', 'crown']
MKINDS = ['mould', 'crawler', 'skeleton', 'hound', 'wraith', 'golem', 'king']

# Largest drawn size, screen pixels / rows per shape unit (the nearest depth in itab / mtab)
NEAR = {'icons': (70.0, 27.0), 'monsters': (168.0, 65.0)}
TOL = 1.5                         # rows


def closed(p):
    return len(p) > 3 and abs(p[0][0] - p[-1][0]) < 1e-6 and abs(p[0][1] - p[-1][1]) < 1e-6


def winding(poly, x, y):
    """Nonzero winding number of point (x, y) for closed polyline poly."""
    w = 0
    for (ax, ay), (bx, by) in zip(poly, poly[1:]):
        if ay <= y:
            if by > y and (bx - ax) * (y - ay) - (x - ax) * (by - ay) > 0:
                w += 1
        elif by <= y and (bx - ax) * (y - ay) - (x - ax) * (by - ay) < 0:
            w -= 1
    return w


def near_edge(poly, x, y, eps=1e-4):
    for (ax, ay), (bx, by) in zip(poly, poly[1:]):
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        t = 0 if L2 < 1e-12 else max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / L2))
        if (ax + t * dx - x) ** 2 + (ay + t * dy - y) ** 2 < eps * eps:
            return True
    return False


def covered(poly, x, y):
    return winding(poly, x, y) != 0 and not near_edge(poly, x, y)


def cuts(a, b, poly):
    """Parameters t in (0, 1) where segment a-b crosses an edge of poly."""
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    ts = []
    for (cx, cy), (ex, ey) in zip(poly, poly[1:]):
        fx, fy = ex - cx, ey - cy
        den = dx * fy - dy * fx
        if abs(den) < 1e-12:
            continue
        t = ((cx - ax) * fy - (cy - ay) * fx) / den
        u = ((cx - ax) * dy - (cy - ay) * dx) / den
        if 1e-9 < t < 1 - 1e-9 and -1e-9 <= u <= 1 + 1e-9:
            ts.append(t)
    return ts


def hide(polys):
    """The visible pieces of each polyline, in drawing order (see the notes at the top)."""
    out = []
    for i, p in enumerate(polys):
        hiders = [q for q in polys[i + 1:] if closed(q)]
        pieces, cur = [], []
        for a, b in zip(p, p[1:]):
            ts = sorted(set([0.0, 1.0] + [t for q in hiders for t in cuts(a, b, q)]))
            for t0, t1 in zip(ts, ts[1:]):
                if t1 - t0 < 1e-9:
                    continue
                tm = (t0 + t1) / 2
                mx, my = a[0] + (b[0] - a[0]) * tm, a[1] + (b[1] - a[1]) * tm
                pa = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
                pb = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
                if any(covered(q, mx, my) for q in hiders):
                    if len(cur) > 1:
                        pieces.append(cur)
                    cur = []
                else:
                    if not cur:
                        cur = [pa]
                    cur.append(pb)
        if len(cur) > 1:
            pieces.append(cur)
        if len(p) == 1:
            pieces = [p]
        out += pieces
    return out


def simplify(pts, sx, sy, tol=TOL):
    """Douglas-Peucker on points mapped to square screen units (x px * 0.4, y rows)."""
    if len(pts) <= 2:
        return pts
    q = [(x * sx * 0.4, y * sy) for x, y in pts]

    def rec(i, j, keep):
        (ax, ay), (bx, by) = q[i], q[j]
        dx, dy = bx - ax, by - ay
        L = (dx * dx + dy * dy) ** 0.5
        best, bk = -1.0, -1
        for k in range(i + 1, j):
            px, py = q[k]
            d = (abs(dx * (ay - py) - dy * (ax - px)) / L) if L > 1e-9 else ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
            if d > best:
                best, bk = d, k
        if best > tol:
            rec(i, bk, keep)
            keep.append(bk)
            rec(bk, j, keep)

    keep = [0]
    rec(0, len(pts) - 1, keep)
    keep.append(len(pts) - 1)
    return [pts[k] for k in sorted(set(keep))]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 2:
        sys.exit(__doc__)
    mons = '--monsters' in sys.argv
    kinds, unit, table, pre, what = ((MKINDS, 60, 'mshapes', 'ms_', 'SHAPE') if mons else
                                     (KINDS, 100, 'icons', 'ic_', 'ICON'))
    shapes = json.load(open(args[0]))
    out = ['* Generated by tools/mkicons.py from the reference\'s %s shapes (make shapes). Do not edit.' % what,
           '* Per shape: polylines, then per polyline: points, then (x, y) pairs in 1/%d units.' % unit, '',
           '%-7s fdb     ' % table + ','.join(pre + k for k in kinds)]
    sx, sy = NEAR['monsters' if mons else 'icons']
    total = before = after = 0
    for k in kinds:
        polys = hide(shapes[k])
        out.append('%s%-6s fcb    %d' % (pre, k, len(polys)))
        for p in polys:
            before += len(p)
            p = simplify(p, sx, sy)
            after += len(p)
            xs, ys = [x for x, y in p], [y for x, y in p]
            size = min(255, round(max(max(xs) - min(xs), max(ys) - min(ys)) * unit))
            pts = []
            for x, y in p:
                xi, yi = round(x * unit), round(y * unit)
                assert -128 <= xi <= 127 and -128 <= yi <= 127, (k, x, y)
                pts += [xi, yi]
            out.append('        fcb     %d,%d,' % (len(p), size) + ','.join(str(v) for v in pts))
            total += 2 + 2 * len(p)
    open(args[1], 'w').write('\n'.join(out) + '\n')
    print('%s: %d shapes, %d points (from %d), %d bytes' % (args[1], len(kinds), after, before,
                                                              total + 3 * len(kinds)))


if __name__ == '__main__':
    main()
