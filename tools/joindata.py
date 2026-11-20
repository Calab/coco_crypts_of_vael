#!/usr/bin/env python3
"""Put the data file VAELDATA.DAT together: what's loaded into bank $3D, then bank $3E.

    joindata.py OUT.dat DATA.dat RES.bin SNDBANK.dat OVL.bin FX.dat

Bank $3D: DATA.dat (src/data.asm: shapes, the tune player), padded to 8K.
Bank $3E: RES.bin at $C000 (the sound engine's image, copied to $FC00 at start-up; up to 1K), then
SNDBANK.dat from $C400 (src/sndbank.asm: the sound effects, up to 2K), then OVL.bin from offset $0C00
(the level generator, run with the bank mapped at $8000, so it's assembled at $8C00), then FX.dat from
offset $1100 (src/fxpics.asm: the attack pictures, read at $D100).
"""
import sys


def main():
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    out, data, res, snd, ovlf, fxf = sys.argv[1:]
    d = open(data, 'rb').read()
    r = open(res, 'rb').read()
    s = open(snd, 'rb').read()
    if len(d) > 0x2000:
        sys.exit('%s is over 8K' % data)
    if len(r) > 0x400:
        sys.exit('%s is over 1K' % res)
    o = open(ovlf, 'rb').read()
    if len(s) > 0x800:
        sys.exit('%s is over 2K (the overlay starts at $0C00)' % snd)
    f = open(fxf, 'rb').read()
    if 0xC00 + len(o) > 0x1100:
        sys.exit('%s runs into the attack pictures at $1100' % ovlf)
    if 0x1100 + len(f) > 0x2000:
        sys.exit('%s runs past the end of bank $3E' % fxf)
    img = (d + bytes(0x2000 - len(d)) + r + bytes(0x400 - len(r)) + s + bytes(0x800 - len(s)) + o +
           bytes(0x500 - len(o)) + f)
    open(out, 'wb').write(img)


if __name__ == '__main__':
    main()
