#!/usr/bin/env python3
"""Turn an XRoar CoCo 3 snapshot into a PNG of the 640x192 4-colour screen.

    snap2png.py SNAPSHOT SYMBOLS OUT.png [--raw]

SYMBOLS is the lwasm --symbol-dump file. The program must define:
    voffsh  2 bytes: the value it last wrote to the GIME vertical offset ($FF9D/E)
    palsh   4 bytes: the palette it last wrote ($FFB0-$FFB3)
Both must sit in CPU $0000-$3FFF, which this tool assumes is mapped to physical
blocks $38-$39 (the power-on map; the game never remaps those two slots).

By default each row is doubled (640x384), which is close to the shape a monitor
shows (CoCo 3 pixels are about 2.5 times taller than wide) while keeping dither
patterns even. --raw gives 640x192.

Standard library only (no PIL). Shares tools/snapshot.py.
"""
import struct
import sys
import zlib

from snapshot import load_ram, symbols, cpu_low


def write_png(path, w, h, rows):
    raw = b''.join(b'\x00' + r for r in rows)
    def chunk(t, data):
        c = t + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)


def rgb(c):
    """CoCo 3 RGB palette byte (bits 5-0 = R1 G1 B1 R0 G0 B0) to 8-bit RGB."""
    r = ((c >> 4) & 2) | ((c >> 2) & 1)
    g = ((c >> 3) & 2) | ((c >> 1) & 1)
    b = ((c >> 2) & 2) | (c & 1)
    return bytes((r * 85, g * 85, b * 85))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 3:
        sys.exit(__doc__)
    snap, symf, out = args
    ram = load_ram(snap)
    sym = symbols(symf)
    for need in ('voffsh', 'palsh'):
        if need not in sym:
            sys.exit('symbol %s not found in %s' % (need, symf))
    hi, lo = cpu_low(ram, sym['voffsh'], 2)
    voff = (hi << 8) | lo
    pal = [rgb(c) for c in cpu_low(ram, sym['palsh'], 4)]
    base = voff * 8
    rows = []
    for y in range(192):
        line = bytearray()
        for x in range(160):
            byte = ram[(base + y * 160 + x) % len(ram)]
            for shift in (6, 4, 2, 0):
                line += pal[(byte >> shift) & 3]
        rows.append(bytes(line))
    if '--raw' in sys.argv:
        write_png(out, 640, 192, rows)
    else:
        tall = [r for r in rows for _ in (0, 1)]
        write_png(out, 640, 384, tall)


if __name__ == '__main__':
    main()
