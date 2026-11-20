#!/usr/bin/env python3
"""Make the game's sound effects for the background sound engine (src/sound.asm).

    mksfx.py BUILDDIR [--wav DIR]

Writes BUILDDIR/sfx.asm (the sounds, for bank BANKSND at $C400), BUILDDIR/sfxid.inc (sound numbers
and the engine's timing) and BUILDDIR/crylv.asm (how loud a monster's cry is by its distance, for the
common bank). --wav DIR writes DIR/sfx-all.wav: every sound in turn, a second apart, played through
the engine's arithmetic, and prints their order.

The sounds follow the reference's SFX and CRIES (reference/crypts-of-vael.html), simplified: one voice
each (layers become a sequence), waves are sawtooth, square, triangle (for sine too) or noise, and
loudness is compressed (the square root of the reference's) so quiet effects stay audible on a TV.
Low sounds (heartbeat, footstep, thud, golem) are square waves, which a TV speaker can play; noise is
kept well down (NOISEGAIN): unfiltered, it sounds like static (Steve).
"""
import math
import sys
import wave

GIMECLK = 3579545
STIMER = 1278                       # GIME timer count (279 ns clock)
SRATE = GIMECLK / (STIMER + 1)      # samples per second (~2800)
STICK = 32                          # samples per tick
TICK = STICK / SRATE                # seconds per tick (~11.4 ms)

WAVES = {'saw': 2, 'sq': 4, 'tri': 6, 'noise': 8, 'rest': 10}


def inc(f):
    return max(0, min(65535, round(f * 65536 / SRATE)))


def vol(a):
    """The reference's gain (about 0.05 to 0.6) to a voice volume (0-127)."""
    return max(1, min(127, round(127 * math.sqrt(a / 0.6))))


def seg(w, f0, f1, dur, a, fade=True):
    """A segment: wave w from f0 to f1 Hz over dur seconds at gain a, fading out or held."""
    n = max(1, round(dur / TICK))
    v = vol(a) if a else 0
    i0 = inc(f0)
    sl = round((inc(f1) - i0) / n) if n > 1 else 0
    k = 0
    if fade and v > 1 and n > 1:
        k = max(1, min(255, round(256 * (1 / v) ** (1 / (n - 1)))))
    return (WAVES[w], i0, sl, v, k, n)


def rest(dur):
    return seg('rest', 0, 0, dur, 0, fade=False)


NOISEGAIN = 0.12               # noise is harsh (white, unfiltered): well under the reference's gains


def noise(rate, dur, a, fade=True):
    return seg('noise', rate, rate, dur, a * NOISEGAIN, fade)


# ---- the sounds: (name, voice, priority, segments) ----
def beat():                          # SFX.beat: two low thumps
    # (square, not the reference's sine: a TV speaker barely plays a pure 70 Hz)
    return [seg('sq', 70, 42, 0.11, 0.45), rest(0.03), seg('sq', 55, 33, 0.11, 0.35)]


def cries():
    """CRIES, one voice each (the reference layers some parts; here they take turns)."""
    c = {}
    c['mould'] = [noise(300, 0.06, 0.35), seg('tri', 140, 420, 0.1, 0.5), noise(300, 0.04, 0.3),
                  seg('tri', 170, 420, 0.1, 0.5), noise(300, 0.04, 0.25), seg('tri', 190, 420, 0.1, 0.5)]
    c['crawler'] = sum(([noise(SRATE, 0.025, 0.9), rest(0.02)] for _ in range(7)), [])
    sk = []
    for i in range(9):
        sk += [noise(2000, 0.02, 0.8), seg('tri', 600 + 50 * (i % 5) * 2, 600, 0.02, 0.12), rest(0.012)]
    sk += [rest(0.15), seg('sq', 240, 240, 0.05, 0.18), rest(0.11), seg('sq', 240, 240, 0.05, 0.18)]
    c['skeleton'] = sk
    c['hound'] = [noise(900, 0.18, 0.7), rest(0.1), noise(900, 0.18, 0.7), rest(0.1), noise(900, 0.18, 0.7),
                  rest(0.21), seg('saw', 95, 125, 0.15, 0.3, fade=False), seg('saw', 125, 85, 0.3, 0.3)]
    c['wraith'] = [seg('tri', 260, 290, 0.2, 0.3, fade=False), seg('tri', 290, 330, 0.4, 0.6, fade=False),
                   seg('tri', 330, 170, 1.0, 0.6)]
    c['golem'] = [seg('sq', 310, 310, 0.03, 0.1), seg('sq', 55, 50, 0.3, 0.8), rest(0.17),
                  seg('sq', 310, 310, 0.03, 0.1), seg('sq', 55, 50, 0.3, 0.8)]
    k = []
    for f in (330, 294, 262, 233):
        k += [seg('saw', f, f * 0.85, 0.17, 0.25), rest(0.05)]
    c['king'] = k
    return c


# the order matters: it's the monster kinds' order (kind number = SFX_CRY + kind)
MONSTERS = ['mould', 'crawler', 'skeleton', 'hound', 'wraith', 'golem', 'king']


def sounds():
    s = [('BEAT', 0, 1, beat()),
         ('SWING', 1, 2, [seg('tri', 900, 270, 0.09, 0.08)]),
         ('HIT', 1, 2, [seg('sq', 180, 72, 0.12, 0.12)]),
         ('HURT', 1, 3, [seg('saw', 120, 60, 0.25, 0.2)]),
         ('KILL', 1, 3, [seg('saw', 300, 60, 0.4, 0.15)]),
         ('GET', 1, 2, [seg('sq', 660, 660, 0.07, 0.06), seg('sq', 880, 880, 0.07, 0.06)]),
         ('THUD', 1, 2, [seg('sq', 160, 48, 0.03, 0.08), seg('sq', 85, 38, 0.22, 0.6)]),
         ('STEP', 1, 2, [seg('sq', 90, 90, 0.04, 0.05)]),
         ('DESCEND', 1, 3, [seg('tri', 400, 100, 1.2, 0.15)])]
    c = cries()
    for m in MONSTERS:
        s.append(('CRY_' + m.upper(), 1, 1, c[m]))
    return s


def crylevels():
    """cryLevel(dist) x 255 for path distances 0-17 (the reference's HEAR_RANGE)."""
    return [round(255 * (1 - max(0, d - 1) / 17) ** 1.3) for d in range(18)]


# ---- the engine's arithmetic, for the preview ----
def play(segs, lv=255, master=216):
    out = []
    lvl = (lv * master) >> 8
    ph, i_, sl, vo, k, nz, lf = 0, 0, 0, 0, 0, 0, 1     # (the phase starts at 0 with each sound)
    w = 10
    cnt = 1
    dur = 1
    idx = 0
    while True:
        # a tick
        dur -= 1
        if dur == 0:
            if idx == len(segs):
                break
            w, i_, sl, v, k, dur = segs[idx]
            idx += 1
            vo = (v * lvl) >> 8
        else:
            i_ = (i_ + sl) & 0xFFFF
            if k:
                vo = (vo * k) >> 8
        bias = 0
        for _ in range(STICK):
            if w == 10:
                s = 0
            else:
                n = ph + i_
                ph = n & 0xFFFF
                a = ph >> 8
                if w == 2:
                    s = a
                elif w == 4:
                    s = 255 if a & 0x80 else 0
                elif w == 6:
                    s = ((a << 1) & 255) ^ (255 if a & 0x80 else 0)
                else:
                    if n > 0xFFFF:
                        c = lf & 1
                        lf >>= 1
                        if c:
                            lf ^= 0xB8
                        nz = lf
                    s = nz
                s = (s * vo) >> 8
            out.append(((s + bias) & 0xFC))
    return out


def main():
    bdir = sys.argv[1]
    wavdir = sys.argv[sys.argv.index('--wav') + 1] if '--wav' in sys.argv else None
    s = sounds()
    inc_ = ['* Made by tools/mksfx.py. Do not edit.',
            'STIMER  equ     %d               ; GIME timer count: %.0f samples a second' % (STIMER, SRATE),
            'STICK   equ     %d               ; samples a tick (%.1f ms)' % (STICK, TICK * 1000)]
    for i, (name, _, _, _) in enumerate(s):
        inc_.append('SFX_%-12s equ %d' % (name, i))
    inc_.append('SFX_CRY equ     SFX_CRY_%s       ; + monster kind' % MONSTERS[0].upper())
    open('%s/sfxid.inc' % bdir, 'w').write('\n'.join(inc_) + '\n')
    a = ['* Made by tools/mksfx.py: the sounds for src/sound.asm. Do not edit.',
         '        org     $C400',
         'sfxtab']
    for name, v, p, _ in s:
        a.append('        fdb     s_%s' % name.lower())
        a.append('        fcb     %d,%d' % (v, p))
    for name, _, _, segs in s:
        a.append('s_%s' % name.lower())
        for w, i0, sl, v, k, n in segs:
            if n > 255:
                sys.exit('%s: a segment over 255 ticks' % name)
            a.append('        fcb     %d,$%02X,$%02X,$%02X,$%02X,%d,%d,%d' %
                     (w, i0 >> 8, i0 & 255, (sl >> 8) & 255, sl & 255, v, k, n))
        a.append('        fcb     0')
    open('%s/sfx.asm' % bdir, 'w').write('\n'.join(a) + '\n')
    cl = crylevels()
    open('%s/crylv.asm' % bdir, 'w').write(
        '* Made by tools/mksfx.py: a monster cry\'s loudness by path distance 0-17 (the reference\'s\n'
        '* cryLevel x 255)\ncrylv   fcb     %s\n' % ','.join(str(x) for x in cl))
    if wavdir:
        data = []
        for name, _, _, segs in s:
            print('%5.1f s  %s' % (len(data) / SRATE, name))
            data += play(segs)
            data += [128] * round(SRATE * 0.6)
        w = wave.open('%s/sfx-all.wav' % wavdir, 'wb')
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(round(SRATE))
        w.writeframes(bytes(data))
        w.close()
        print('wrote %s/sfx-all.wav' % wavdir)


if __name__ == '__main__':
    main()
