#!/usr/bin/env python3
"""Convert src/font.txt into assembly, checking the composite rule.

    font2asm.py FONT.txt OUT.asm

Output defines:
    font     16 bytes per character (8 rows x 2 bytes, leftmost pixel in bit 7 of the first byte),
             for codes FONT_FIRST .. FONT_FIRST+FONT_COUNT-1
    fontexp  256 bytes: a font byte's left 4 pixels expanded to 2 bits per pixel (one screen byte)
             followed by 256 bytes for its right 4 pixels
Composite rule: in every row, each run of lit pixels is at least 2 wide. Gaps of 1 unlit pixel are allowed.
"""
import sys

FIRST = 0x20
NAMED = {'SPACE': 0x20, 'BULLET': 0x60, 'CURSOR': 0x61, 'BAR': 0x62,
         'HEARTL': 0x63, 'HEARTR': 0x64, 'HEART2L': 0x65, 'HEART2R': 0x66}
LAST = max(NAMED.values())


def code_of(name):
    if name in NAMED:
        return NAMED[name]
    if len(name) == 1 and 0x21 <= ord(name) <= 0x5F:
        return ord(name)
    raise ValueError('unknown character name %r' % name)


def check_row(row):
    """Return an error message if the row breaks the composite rule, else None."""
    runs = []                       # (lit?, length)
    for ch in row:
        lit = ch == '#'
        if runs and runs[-1][0] == lit:
            runs[-1][1] += 1
        else:
            runs.append([lit, 1])
    for lit, n in runs:
        if lit and n < 2:
            return 'single lit pixel'
    return None


def parse(path):
    glyphs, errors = {}, []
    lines = open(path).read().split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        i += 1
        if not line or line.startswith('# '):     # blank line or comment
            continue
        if not line.startswith('= '):
            errors.append('line %d: expected "= NAME", got %r' % (i, line))
            continue
        name = line[2:]
        try:
            code = code_of(name)
        except ValueError as e:
            errors.append('line %d: %s' % (i, e))
            continue
        rows = [lines[i + k].rstrip() for k in range(8)]
        for k, r in enumerate(rows):
            if len(r) != 16 or set(r) - set('#.'):
                errors.append('line %d (%s row %d): need 16 of # or ., got %r' % (i + k + 1, name, k, r))
            else:
                bad = check_row(r)
                if bad:
                    errors.append('line %d (%s row %d): %s: %s' % (i + k + 1, name, k, bad, r))
        if code in glyphs:
            errors.append('line %d: %s defined twice' % (i, name))
        glyphs[code] = rows
        i += 8
    return glyphs, errors


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    glyphs, errors = parse(sys.argv[1])
    if errors:
        sys.exit('font errors:\n  ' + '\n  '.join(errors))
    out = ['* Generated from %s by tools/font2asm.py. Do not edit.' % sys.argv[1], '',
           'FONT_FIRST equ $%02X' % FIRST, 'FONT_COUNT equ %d' % (LAST - FIRST + 1),
           'CH_BULLET equ $60', 'CH_CURSOR equ $61', 'CH_BAR equ $62',
           'CH_HEART equ $63', 'CH_HEART2 equ $65', '', 'font']
    for code in range(FIRST, LAST + 1):
        rows = glyphs.get(code, ['.' * 16] * 8)
        data = []
        for r in rows:
            bits = int(r.replace('#', '1').replace('.', '0'), 2)
            data += [bits >> 8, bits & 0xFF]
        label = chr(code) if 0x21 <= code <= 0x5F else {v: k for k, v in NAMED.items()}.get(code, '')
        out.append('        fcb     ' + ','.join('$%02X' % b for b in data) + '  ; $%02X %s' % (code, label))
    out += ['', '* fontexp+n: left 4 pixels of font byte n at 2 bits each; fontexp+256+n: right 4 pixels', 'fontexp']
    for half in (4, 0):
        for n in range(256):
            nib = (n >> half) & 15
            v = 0
            for b in range(4):
                if nib & (8 >> b):
                    v |= 3 << (6 - 2 * b)
            if n % 16 == 0:
                vals = []
            vals.append('$%02X' % v)
            if n % 16 == 15:
                out.append('        fcb     ' + ','.join(vals))
    open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
    print('%s: %d characters' % (sys.argv[2], len(glyphs)))


if __name__ == '__main__':
    main()
