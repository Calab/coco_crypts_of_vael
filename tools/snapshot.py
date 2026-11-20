"""Read memory out of an XRoar CoCo 3 snapshot (shared by the tools in this folder).

    ram = load_ram(path)           # all of RAM, as bytes (128K, 512K or 2M)
    sym = symbols(symfile)         # lwasm --symbol-dump file -> {name: value}
    phys(ram, addr, n)             # n bytes at a physical address
    cpu_low(ram, addr, n)          # n bytes at a fixed CPU address: $0000-$3FFF (blocks $38-$39)
                                   # or the high code and sound engine area $E000-$FEFF (block $3F)
"""
import re
import sys

RAM_SIZES = (0x20000, 0x80000, 0x200000)


def read_vuint(d, i):
    """XRoar's variable-length unsigned int: the number of leading 1 bits is the
    number of extra bytes that follow (e.g. C2 00 00 = $20000)."""
    b = d[i]
    n = 0
    while b & (0x80 >> n):
        n += 1
    v = b & (0x7F >> n)
    for k in range(1, n + 1):
        v = (v << 8) | d[i + k]
    return v, i + n + 1


def load_ram(path):
    d = open(path, 'rb').read()
    tag = d.find(b'RAM')
    if tag < 0:
        sys.exit('%s: no RAM section' % path)
    for i in range(tag, min(tag + 64, len(d))):
        try:
            v, j = read_vuint(d, i)
        except IndexError:
            break
        if v in RAM_SIZES and j + v <= len(d):
            return d[j:j + v]
    sys.exit('%s: could not find RAM data' % path)


def symbols(path):
    out = {}
    for line in open(path):
        m = re.match(r'\s*(\S+)\s+EQU\s+\$([0-9A-Fa-f]+)', line)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def phys(ram, addr, n=1):
    return bytes(ram[(addr + k) % len(ram)] for k in range(n))


def cpu_low(ram, addr, n=1):
    """A fixed CPU address: $0000-$3FFF (physical blocks $38-$39) or $E000-$FEFF (block $3F), which
    the game never remaps. (The bank window and screen window move, so they can't be read this way.)"""
    if addr + n <= 0x4000:
        return phys(ram, 0x38 * 0x2000 + addr, n)
    assert 0xE000 <= addr and addr + n <= 0xFF00, 'address %04X is not in a fixed area' % addr
    return phys(ram, 0x3F * 0x2000 + addr - 0xE000, n)
