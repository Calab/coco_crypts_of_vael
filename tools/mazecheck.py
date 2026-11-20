#!/usr/bin/env python3
"""Check that the CoCo build makes the same levels as the web version: maze, far cell, items.

    mazecheck.py SEED [SEED...]        (seeds as typed on the title: numbers or words)

For each seed: runs the reference's own code (tools/refmaze.js under gjs) for levels 1-5, builds
the game with -D MAZETEST -D SEEDVAL=<seed>, runs it headless in XRoar until it reaches mazedone,
and compares every level's grid, size and far cell. Exit status 0 only if everything matches.
"""
import os
import subprocess
import sys

import snapshot

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILD = os.path.join(ROOT, 'build')
SCREEN = 0x60000                     # physical address of screen page 0, where MAZETEST leaves results
KINDS = ['dagger', 'axe', 'sword', 'hammer', 'rune', 'buckler', 'tower', 'torch', 'lantern', 'mending',
         'herb', 'vigor', 'map', 'relic', 'crown']
MKINDS = ['mould', 'crawler', 'skeleton', 'hound', 'wraith', 'golem', 'king']


def reference(seed_text):
    out = subprocess.run(['gjs', '-m', os.path.join(HERE, 'refmaze.js'), seed_text],
                         capture_output=True, text=True, check=True).stdout.split('\n')
    seed = int(out[0].split()[1])
    levels, i = {}, 1
    while i < len(out) and out[i].startswith('LEVEL'):
        w = out[i].split()           # LEVEL n SIZE S FAR x,y
        n, size = int(w[1]), int(w[3])
        fx, fy = map(int, w[5].split(','))
        rows = out[i + 1:i + 1 + size]
        i += 1 + size
        nit = int(out[i].split()[1])  # ITEMS n, then "x,y kind" lines
        items = [tuple(out[i + 1 + k].split()) for k in range(nit)]
        i += 1 + nit
        nmon = int(out[i].split()[1])  # MONS n, then "x,y kind carry dormant" lines
        mons = [tuple(out[i + 1 + k].split()) for k in range(nmon)]
        i += 1 + nmon
        levels[n] = dict(size=size, far=(fx, fy), rows=rows, items=items, mons=mons)
    return seed, levels


def coco(seed):
    binf, symf, snap = (os.path.join(BUILD, 'mazecheck' + e) for e in ('.bin', '.sym', '.sna'))
    subprocess.run(['lwasm', '--format=decb', '-I', 'src', '-I', 'build', '-D', 'MAZETEST',
                    '-D', 'SEEDVAL=%d' % seed, '--symbol-dump=' + symf, '-o', binf + '.raw', 'src/main.asm'],
                   cwd=ROOT, check=True)
    subprocess.run([sys.executable, os.path.join(HERE, 'relocate.py'), binf + '.raw', binf, binf + '.res',
                    binf + '.ovl', os.path.join(BUILD, 'fx.dat')], check=True)
    dsk = os.path.join(BUILD, 'mazecheck.dsk')       # its own disk: the data file carries its code at $FC00
    subprocess.run([sys.executable, os.path.join(HERE, 'joindata.py'), binf + '.dat',
                    os.path.join(BUILD, 'data.dat'), binf + '.res', os.path.join(BUILD, 'sndbank.dat'),
                    binf + '.ovl', os.path.join(BUILD, 'fx.dat')], check=True)
    subprocess.run([sys.executable, os.path.join(HERE, 'mkdsk.py'), dsk, 'VAEL.BIN=' + binf,
                    'VAELDATA.DAT=%s.dat:1' % binf], check=True, stdout=subprocess.DEVNULL)
    addr = snapshot.symbols(symf)['mazedone']
    if os.path.exists(snap):
        os.remove(snap)
    subprocess.run(['timeout', '120', 'xroar', '-machine', 'coco3', '-ram', '128', '-load-fd0', dsk, '-ui', 'null',
                    '-ao', 'null', '-no-ratelimit', '-run', binf, '-trap', 'pc=0x%04X' % addr,
                    '-trap-snap', snap, '-trap-timeout', '0', '-timeout', '100'],
                   capture_output=True)
    if not os.path.exists(snap):
        sys.exit('the CoCo build never reached mazedone')
    ram = snapshot.load_ram(snap)
    levels = {}
    for n in range(1, 6):
        info = snapshot.phys(ram, SCREEN + 5120 + (n - 1) * 8, 5)
        size = info[0]
        grid = snapshot.phys(ram, SCREEN + (n - 1) * 1024, size * size)
        rows = [''.join('#' if grid[y * size + x] else '.' for x in range(size)) for y in range(size)]
        it = snapshot.phys(ram, SCREEN + 6144 + (n - 1) * 256, 256)
        items = [('%d,%d' % (it[1 + 3 * k], it[2 + 3 * k]), KINDS[it[3 + 3 * k]]) for k in range(it[0])]
        mt = snapshot.phys(ram, SCREEN + 7424 + (n - 1) * 128, 128)
        mons = [('%d,%d' % (mt[1 + 5 * k], mt[2 + 5 * k]), MKINDS[mt[3 + 5 * k]],
                 '-' if mt[4 + 5 * k] == 0xFF else KINDS[mt[4 + 5 * k]], str(mt[5 + 5 * k] & 1))
                for k in range(mt[0])]
        levels[n] = dict(size=size, far=(info[1], info[2]), rows=rows, items=items, mons=mons)
    return levels


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    bad = 0
    for text in sys.argv[1:]:
        seed, ref = reference(text)
        got = coco(seed)
        for n in range(1, 6):
            r, g = ref[n], got[n]
            problems = [k for k in ('size', 'far', 'rows', 'items', 'mons') if r[k] != g[k]]
            print('seed %-12s (%10d) level %d: %s' % (text, seed, n,
                  'OK  size %d, far cell %d,%d, %d items, %d monsters' % (g['size'], *g['far'], len(g['items']), len(g['mons']))
                  if not problems else 'MISMATCH in ' + ', '.join(problems)))
            for k in ('items', 'mons'):
                if k in problems:
                    print('   web  %s:' % k, r[k])
                    print('   coco %s:' % k, g[k])
            if problems:
                bad += 1
                if 'rows' in problems:
                    for y, (a, b) in enumerate(zip(r['rows'], g['rows'])):
                        print('   %-31s  %-31s %s' % (a, b, '' if a == b else '<--'))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
