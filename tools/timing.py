#!/usr/bin/env python3
"""Print the draw timings an AUTOWALK build leaves in memory.

    timing.py SNAPSHOT SYMBOLS
"""
import sys

from snapshot import load_ram, symbols, cpu_low


def word(ram, sym, name):
    hi, lo = cpu_low(ram, sym[name], 2)
    return (hi << 8) | lo


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    ram, sym = load_ram(sys.argv[1]), symbols(sys.argv[2])
    frames, total, worst = (word(ram, sym, n) for n in ('frames', 'totdraw', 'maxdraw'))
    if not frames:
        sys.exit('no frames drawn')
    print('%d frames: average %.2f ticks (%.0f ms), worst %d ticks (%.0f ms) to clear and draw the view'
          % (frames, total / frames, total / frames * 1000 / 60, worst, worst * 1000 / 60))


if __name__ == '__main__':
    main()
