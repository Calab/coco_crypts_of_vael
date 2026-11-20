#!/usr/bin/env python3
"""Where a frame's time goes: reads an XRoar trace (-trace-timing) and adds up the cycles spent in
each routine (by the symbol table), from the first time START runs until END.

    profile.py TRACE SYMBOLS [START END]      (default: render .. framedone)

XRoar's dt is in 1/8 cycle units (its 14.318 MHz clock); the first traced line's dt is the time
since the run began, so it's skipped. Local @labels count toward the routine they're in.
"""
import bisect
import collections
import re
import sys

from snapshot import symbols


def main():
    if len(sys.argv) not in (3, 5):
        sys.exit(__doc__)
    sym = {n: a for n, a in symbols(sys.argv[2]).items() if not n.isupper()}
    start = sym[sys.argv[3] if len(sys.argv) == 5 else 'render']
    end = sym[sys.argv[4] if len(sys.argv) == 5 else 'framedone']
    addrs = sorted((a, n) for n, a in sym.items() if 0x0E00 <= a < 0x4000 or 0xE000 <= a < 0xFC00)
    keys = [a for a, _ in addrs]
    tot, calls = collections.Counter(), collections.Counter()
    pat = re.compile(r'^([0-9a-f]{4})\|.*dt=(\d+)')
    started, first, total = False, True, 0
    for line in open(sys.argv[1]):
        m = pat.match(line)
        if not m:
            continue
        pc, dt = int(m.group(1), 16), int(m.group(2))
        if not started:
            if pc != start:
                continue
            started = True
        if first:
            first = False
            continue
        if pc == end:
            break
        i = bisect.bisect_right(keys, pc) - 1
        name = addrs[i][1] if i >= 0 else '?'
        tot[name] += dt
        total += dt
        if addrs[i][0] == pc:
            calls[name] += 1
    if not total:
        sys.exit('nothing traced between the two symbols')
    print('%d cycles = %.0f ms at 1.79 MHz' % (total // 8, total / 8 / 1789.773))
    for name, dt in tot.most_common(25):
        print('%-12s %5.1f%%  %8d cycles  %6d calls' % (name, 100 * dt / total, dt // 8, calls[name]))


if __name__ == '__main__':
    main()
