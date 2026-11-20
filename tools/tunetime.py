#!/usr/bin/env python3
"""Check that the tune player's samples are evenly spaced: reads an XRoar trace (-trace-timing) of
tune.asm running and adds up the cycles of every pass through the loop (smp, then one task), grouped
by task. Every pass must take the same time, TSAMP in tools/mktunes.py (but the last, hend:
the tune is over).

    tunetime.py TRACE SYMBOLS        (make tunetime runs it)

XRoar's dt is in 1/8 cycle units; the first traced line's dt is the time since the run began.
"""
import collections
import re
import sys

from snapshot import symbols

TASKS = ['ttick', 'tev', 'hpitch', 'hslide', 'hset', 'hramp', 'hdecay', 'hwave', 'hwait', 'hend',
         'tenva', 'tenvb', 'tbias', 'tkey', 'tidle', 'texit']


def main():
    sym = symbols(sys.argv[2])
    smp = sym['smp']
    starts = sorted((sym[t], t) for t in TASKS)
    pat = re.compile(r'^([0-9a-f]{4})\|.*dt=(\d+)')
    seen = collections.defaultdict(collections.Counter)
    cur, task, first, passes = None, None, True, 0
    for line in open(sys.argv[1]):
        m = pat.match(line)
        if not m:
            continue
        pc, dt = int(m.group(1), 16), int(m.group(2))
        if first:
            first = False
            continue
        if pc == smp:
            if cur is not None and task is not None:
                seen[task][cur / 8] += 1
                passes += 1
            cur, task = 0, None
        if cur is None:
            continue
        cur += dt
        for a, t in starts:
            if pc == a:
                task = t
    want = None
    try:
        sys.path.insert(0, 'tools')
        import mktunes
        want = mktunes.TSAMP
    except Exception:
        pass
    bad = False
    print('%d passes; TSAMP %s' % (passes, want))
    for t in TASKS:
        if t in seen:
            c = seen[t]
            print('  %-7s %s' % (t, '  '.join('%g cycles x%d' % (k, n) for k, n in sorted(c.items()))))
            if want is not None and any(k != want for k in c) and t not in ('hend', 'texit'):
                bad = True
    if bad:
        sys.exit('not every pass takes TSAMP cycles')


if __name__ == '__main__':
    main()
