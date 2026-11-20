#!/usr/bin/env python3
"""Build a Disk BASIC (DECB) disk image holding the given files.

    mkdsk.py OUT.dsk NAME.EXT=PATH[:TYPE] ...

TYPE: 0 BASIC program, 1 BASIC data, 2 machine language (default for .BIN), 3 text; files are stored
as binary unless TYPE ends in A (ASCII: e.g. a BASIC program as plain text lines ending in CR, which
Disk BASIC's RUN and LOAD accept, so "VAEL.BAS=loader.bas:0A"). The image is the usual 35 tracks x 18 sectors x 256 bytes (.dsk / JVC with no
header), sectors in order.

Disk BASIC layout: a granule is half a track (9 sectors); granules 0-67 cover tracks 0-16 and 18-34.
Track 17 holds the granule table (FAT, sector 2: $FF free, else the next granule, or $C0 + sectors
used in the last one) and the directory (sectors 3-11: 32-byte entries of name (8), extension (3),
type, ASCII flag, first granule, bytes used in the last sector (2), then zeros; $FF = never used).
"""
import sys

TRACKS, SECTORS, SECSIZE = 35, 18, 256
DIRTRACK = 17


def granule_place(g):
    track = g // 2
    if track >= DIRTRACK:
        track += 1
    return track, 1 + 9 * (g % 2)


def offset(track, sector):
    return (track * SECTORS + sector - 1) * SECSIZE


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    img = bytearray(b'\xff' * (TRACKS * SECTORS * SECSIZE))
    fat = bytearray(b'\xff' * 68)
    dirents = []
    nextg = 0
    for spec in sys.argv[2:]:
        name_ext, path = spec.split('=', 1)
        ftype, ascii = None, False
        if ':' in path:
            path, ftype = path.rsplit(':', 1)
            ascii = ftype.upper().endswith('A')
            ftype = int(ftype.rstrip('aA'))
        name, ext = (name_ext.upper().split('.') + [''])[:2]
        if ftype is None:
            ftype = 2 if ext == 'BIN' else 1
        data = open(path, 'rb').read()
        if not data:
            sys.exit('%s is empty' % path)
        nsec = (len(data) + SECSIZE - 1) // SECSIZE
        ngran = (nsec + 8) // 9
        if nextg + ngran > 68:
            sys.exit('disk full')
        first = nextg
        for k in range(ngran):
            g = nextg + k
            track, sec0 = granule_place(g)
            chunk = data[k * 9 * SECSIZE:(k + 1) * 9 * SECSIZE]
            img[offset(track, sec0):offset(track, sec0) + len(chunk)] = chunk
            if k < ngran - 1:
                fat[g] = g + 1
            else:
                fat[g] = 0xC0 + (nsec - 9 * k)
        nextg += ngran
        last = len(data) - (nsec - 1) * SECSIZE          # bytes used in the last sector, 1-256
        ent = bytearray(32)
        ent[0:8] = name.ljust(8)[:8].encode()
        ent[8:11] = ext.ljust(3)[:3].encode()
        ent[11] = ftype
        ent[12] = 0xFF if ascii else 0x00                 # ASCII or binary
        ent[13] = first
        ent[14:16] = last.to_bytes(2, 'big')
        dirents.append(ent)
        print('%-8s.%-3s %6d bytes, granules %d-%d' % (name, ext, len(data), first, nextg - 1))
    sec2 = bytearray(SECSIZE)                             # FAT sector: 68 entries, the rest zero
    sec2[:68] = fat
    img[offset(DIRTRACK, 2):offset(DIRTRACK, 2) + SECSIZE] = sec2
    for i, ent in enumerate(dirents):                     # directory: 8 entries per sector, from 3
        o = offset(DIRTRACK, 3 + i // 8) + 32 * (i % 8)
        img[o:o + 32] = ent
    open(sys.argv[1], 'wb').write(img)


if __name__ == '__main__':
    main()
