#!/usr/bin/env python3
"""Move banked parts of a DECB .bin to where LOADM can load them.

    relocate.py IN.bin OUT.bin RES.bin OVL.bin

Records assembled for the bank window ($C000-$DFFF) are given load address $4000-$5FFF instead.
Under Disk BASIC's normal memory map that puts them in physical block $3A, which the program maps
into the bank window when it starts. Records for the high code ($E000-$FBFF) are loaded at
$6000-$7BFF, and the program copies them up to $E000 first thing. Records for $FC00-$FEED (the
sound engine, src/sound.asm) can't be loaded at all: they go to RES.bin (an image from $FC00), which
the data file carries and the program copies up at start-up. So do records for $0000-$00FF (the low
code, src/low.asm), at offset $0300 of RES.bin; the program copies them down at start-up. Records for $8C00-$9FFF (the level
generator overlay, src/mazegen.asm) go to OVL.bin (an image from $8C00), also carried by the data
file, mapped in while a level is built. Everything else is unchanged.
"""
import struct
import sys

RESIDENT = (0xFC00, 0xFEEE)              # the sound engine: to RES.bin
LOW = (0x0000, 0x0100)                   # the low code (src/low.asm): to RES.bin from offset $0300
OVERLAY = (0x8C00, 0xA000)               # the level generator: to OVL.bin
MOVES = [(0xC000, 0xE000, -0x8000),      # (first, end, offset): bank window -> $4000
         (0xE000, 0xFC00, -0x8000)]      # high code -> $6000


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    d = open(sys.argv[1], 'rb').read()
    out, used, i = bytearray(), [], 0
    res, ovl = bytearray(), bytearray()
    while i < len(d):
        kind = d[i]
        n, addr = struct.unpack('>HH', d[i + 1:i + 5])
        if kind == 0xFF:                      # postamble: exec address
            out += d[i:i + 5]
            break
        if kind != 0x00:
            sys.exit('bad DECB record type %02X at offset %d' % (kind, i))
        data = d[i + 5:i + 5 + n]
        taken = False
        for (first, end), img, base in ((RESIDENT, res, 0), (LOW, res, 0x300), (OVERLAY, ovl, 0)):
            if first <= addr < end:
                if addr + n > end:
                    sys.exit('record at $%04X runs past $%04X' % (addr, end))
                o = addr - first + base
                if len(img) < o + n:
                    img += bytes(o + n - len(img))
                img[o:o + n] = data
                taken = True
        if taken:
            i += 5 + n
            continue
        for first, end, off in MOVES:
            if first <= addr < end:
                if addr + n > end:
                    sys.exit('record at $%04X runs past $%04X' % (addr, end))
                addr += off
        for a, b in used:
            if addr < b and a < addr + n:
                sys.exit('relocated record at $%04X overlaps $%04X-$%04X' % (addr, a, b - 1))
        used.append((addr, addr + n))
        out += bytes([0]) + struct.pack('>HH', n, addr) + data
        i += 5 + n
    else:
        sys.exit('no postamble')
    top = max(b for a, b in used)
    if top > 0x7C00:
        sys.exit('loads up to $%04X: LOADM is only safe below $7C00 (BASIC keeps its stack near $7FFF)' % top)
    open(sys.argv[2], 'wb').write(out)
    open(sys.argv[3], 'wb').write(res)
    open(sys.argv[4], 'wb').write(ovl)


if __name__ == '__main__':
    main()
