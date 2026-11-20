#!/usr/bin/env python3
"""Make the win and lose tunes for the DAC player (src/tune.asm): wave tables and event lists.

    mktunes.py OUT.asm [--wav DIR]
    mktunes.py --check data.lst        (the build: the sample loop's cycles must match TLOOP)

The notes, tempos, volumes and envelopes are the reference's TUNES.death (playTune) and playVictory,
copied from reference/crypts-of-vael.html. What the CoCo leaves out: the hall reverb, the horns' two
detuned oscillators and moving low-pass filter (one horn wave with a few harmonics instead), the
vibrato on long horn notes; the timpani's noise thud is a rougher wave for the first 0.18 s of each
drum. Volumes are rebalanced for 4 voices in the DAC (the reference's timpani are 5x as loud as a
horn, which would drown the tune on a TV speaker).

--wav DIR also writes DIR/tune-lose.wav and DIR/tune-win.wav, made by running the events through
the same integer arithmetic as the player, to listen to without the CoCo.
"""
import math
import random
import re
import sys
import wave

CPU = 1789772.5          # the CoCo 3's high speed
TLOOP = 215              # cycles of tune.asm's sample loop, smp to smpend (the build checks it)
TASKLEN = 75             # cycles of every task (tools/tunetime.py checks it from an XRoar trace)
TSAMP = TLOOP + TASKLEN  # cycles per sample
TICKLEN = 64             # samples per tick
RATE = CPU / TSAMP       # samples per second
TICK = TICKLEN / RATE    # seconds per tick
NV = 4
MAXEV = (TICKLEN - 1 - 2 * NV - 2 - 1) // 2      # events in one tick (each takes 2 of its samples)


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def step(f):
    return round(f * 65536 / RATE)


def ticks(t):
    return round(t / TICK)


# ---- wave tables: 256 values around 128 ----
def table(fn):
    v = [fn(2 * math.pi * i / 256) for i in range(256)]
    m = max(abs(x) for x in v)
    return [128 + round(127 * x / m) for x in v]


def harmonics(hs):
    return lambda p: sum(a * math.sin(n * p) for n, a in hs)


random.seed(7)
_n, _y = [], 0.0
for i in range(512):                         # noise through a one-pole low-pass
    _y += 0.3 * (random.uniform(-1, 1) - _y)
    _n.append(_y)
_n = _n[256:]
_nm = max(abs(x) for x in _n)

WAVES = {
    'wsine': table(math.sin),
    # triangle: odd harmonics 1/n^2, alternating (up to the 5th: the lament's top note is 440 Hz)
    'wtri': table(harmonics([(1, 1), (3, -1 / 9), (5, 1 / 25)])),
    # horn: a sawtooth's harmonics softened, as the reference's low-pass leaves them
    'whorn': table(harmonics([(1, 1), (2, 0.5), (3, 0.28), (4, 0.12)])),
    # drone: low D (a triangle) and the A above (a sine, 0.6 as loud) in one table: a period of D an
    # octave below holds 2 periods of D and 3 of A
    'wdrone': table(harmonics([(2, 1), (6, -1 / 9), (10, 1 / 25), (3, 0.6)])),
    # the timpani's first moment: the sine roughened with noise (the reference's noise thud)
    'wtimpa': table(lambda p: math.sin(p) + 0.45 * _n[round(p * 256 / (2 * math.pi)) % 256] / _nm),
}

HANDLERS = ['pitch', 'slide', 'set', 'ramp', 'decay', 'wave', 'wait', 'end']


# ---- events ----
class Tune:
    def __init__(self):
        self.ev = []                         # (tick, seq, voice, cmd, arg)
        self.seq = 0

    def at(self, k, v, cmd, arg=None):
        self.ev.append((k, self.seq, v, cmd, arg))
        self.seq += 1

    def add(self, t, v, cmd, arg=None):
        self.at(ticks(t), v, cmd, arg)

    def cut(self, t, v):
        """A new note on voice v at time t: drop that voice's events still to come."""
        k = ticks(t)
        self.ev = [e for e in self.ev if not (e[2] == v and e[0] > k)]

    def ramp(self, t, v, frm, to, dur):
        """From frm to to over dur seconds, then held at to."""
        k0 = ticks(t)
        n = max(1, ticks(t + dur) - k0)
        self.at(k0, v, 'set', round(frm))
        self.at(k0, v, 'ramp', int((round(to) - round(frm)) * 256 / n))
        self.at(k0 + n, v, 'set', round(to))

    def decay(self, t, v, frm, dur, floor=0.5):
        n = max(1, ticks(t + dur) - ticks(t))
        self.add(t, v, 'set', round(frm))
        self.add(t, v, 'decay', max(1, min(255, round(256 * (floor / max(frm, 1)) ** (1 / n)))))

    def encode(self, last):
        """The event list: (cmd, voice, arg) and ('wait', 0, n), ending at time last."""
        ev = sorted(self.ev, key=lambda e: (e[0], e[1]))
        byk = {}
        for k, _, v, cmd, a in ev:
            byk.setdefault(k, []).append((cmd, v, a))
        out, k = [], 0
        end = max(ticks(last), max(byk) + 1)
        carry = []
        while byk or carry:
            todo = carry + byk.pop(k, [])
            carry = todo[MAXEV - 1:]         # (room for the WAIT that ends the tick's events)
            out.extend(todo[:MAXEV - 1])
            nxt = k + 1 if carry else min(list(byk) + [end])
            while nxt - k > 255:
                out.append(('wait', 0, 255))
                k += 255
            out.append(('wait', 0, nxt - k))
            k = nxt
        out.append(('end', 0, None))
        return out


def lose():
    """TUNES.death: playTune(..., 66): triangle 0.22, sine 0.18."""
    T = Tune()
    beat = 60 / 66
    voices = [('wtri', 128, [(62, 1), (65, 1), (69, 1.5), (67, 0.5), (65, 1), (64, 1), (62, 2), (57, 1),
                             (61, 1), (62, 3)]),
              ('wsine', 105, [(50, 4), (46, 3), (45, 3), (38, 3)])]
    t = 0
    for v, (w, vol, notes) in enumerate(voices):
        T.add(0, v, 'wave', w)
        t = 0.1
        for m, b in notes:
            ln = b * beat
            if m:                            # playTune's envelope: up in 30 ms, hold to 3/4, fade by 98%
                T.cut(t, v)
                T.add(t, v, 'pitch', step(hz(m)))
                T.ramp(t, v, 0, vol, 0.03)
                T.decay(t + ln * 0.75, v, vol, ln * 0.23)
            t += ln
    return T.encode(t + 0.1)


HORNS = [
    [(57, .5), (62, .5), (69, 2), (67, .5), (65, .5), (67, 1), (64, 1), (62, 2),
     (62, .5), (65, .5), (72, 2), (70, .5), (69, .5), (67, 1), (65, 1), (69, 2),
     (69, .5), (74, .5), (76, 1.5), (77, .5), (76, 1), (74, 1), (72, 1), (69, 2),
     (69, .5), (73, .5), (74, 1), (73, .5), (74, .5), (76, 1), (74, 5)],
    [(52, .5), (57, .5), (64, 2), (62, .5), (60, .5), (62, 1), (59, 1), (57, 2),
     (57, .5), (60, .5), (67, 2), (65, .5), (64, .5), (62, 1), (60, 1), (64, 2),
     (65, .5), (69, .5), (72, 1.5), (74, .5), (72, 1), (70, 1), (69, 1), (65, 2),
     (64, .5), (69, .5), (66, 1), (69, .5), (69, .5), (73, 1), (66, 5)],
]
DRUMS = [(0, 1), (8, 0.8), (16, 0.8), (24, 0.9), (27, 0.35), (27.25, 0.4), (27.5, 0.45), (27.75, 0.55),
         (28, 1.2)]


def win():
    """playVictory at 120 bpm: horns 0.045 / 0.035 (two oscillators each), drone D+A, timpani."""
    T = Tune()
    beat = 0.5
    t0 = 0.1
    total = 33 * beat
    for v, (notes, vol) in enumerate([(HORNS[0], 77), (HORNS[1], 60)]):
        T.add(0, v, 'wave', 'whorn')
        t = t0
        for m, b in notes:                   # hornNote: up in 60 ms, 0.85 from len - 0.12, fade by len + 0.08
            ln = b * beat
            T.cut(t, v)
            T.add(t, v, 'pitch', step(hz(m)))
            T.ramp(t, v, 0, vol, 0.06)
            h = t + max(0.1, ln - 0.12)
            T.decay(h, v, vol * 0.85, ln + 0.08 - (h - t))
            t += ln
    dv = 38                                  # the drone: in over 2.5 s, out over the last 3.5 s
    T.add(0, 2, 'wave', 'wdrone')
    T.add(t0, 2, 'pitch', step(hz(38) / 2))
    T.ramp(t0, 2, 0, dv, 2.5)
    T.ramp(t0 + total - 3, 2, dv, 0, 3.5)
    hi, lo = step(82), step(73)              # timpani: 82 Hz settling to 73 in 0.4 s, dying over 1.4 s
    for b, k in DRUMS:
        t = t0 + b * beat
        T.cut(t, 3)
        n = ticks(t + 0.4) - ticks(t)
        T.add(t, 3, 'wave', 'wtimpa')
        T.add(t, 3, 'pitch', hi)
        T.add(t, 3, 'slide', round((lo - hi) / n))
        T.decay(t, 3, 64 * k, 1.4)
        T.add(t + 0.18, 3, 'wave', 'wsine')
        T.add(t + 0.4, 3, 'pitch', lo)
    return T.encode(t0 + total + 0.6)


def asm_events(name, evs):
    lines = [name]
    for cmd, v, a in evs:
        h = '%d,%d' % (HANDLERS.index(cmd) * 2, v * 16)
        if cmd in ('pitch', 'slide', 'ramp'):
            lines.append('        fcb     %s,$%02X,$%02X' % (h, (a >> 8) & 255, a & 255))
        elif cmd in ('set', 'decay', 'wait'):
            lines.append('        fcb     %s,%d' % (h, a))
        elif cmd == 'wave':
            lines.append('        fcb     %s' % h)
            lines.append('        fdb     %s+128' % a)
        else:
            lines.append('        fcb     %s' % h)
    return lines


def simulate(evs, volumes_only=False):
    """The player's arithmetic, a tick at a time: yields DAC values (0-252), or the sum of volumes."""
    s = [dict(ph=0, inc=0, wv='wsine', vo=0, vol=0, md=0, dv=0, k=0, sl=0) for _ in range(NV)]
    i, wait = 0, 0
    while True:
        if wait:
            wait -= 1
        else:
            n = 0
            while True:
                cmd, v, a = evs[i]
                i += 1
                n += 1
                x = s[v]
                if cmd == 'wait':
                    wait = a - 1
                    break
                if cmd == 'end':
                    return
                if cmd == 'pitch':
                    x['inc'], x['sl'] = a & 0xFFFF, 0
                elif cmd == 'slide':
                    x['sl'] = a
                elif cmd == 'set':
                    x['vol'], x['vo'], x['dv'], x['md'] = a << 8, a, 0, 0
                elif cmd == 'ramp':
                    x['dv'], x['md'] = a, 0
                elif cmd == 'decay':
                    x['k'], x['md'] = a, a
                elif cmd == 'wave':
                    x['wv'] = a
            assert n <= MAXEV, n
        for x in s:
            if x['md'] == 0:
                x['vol'] = (x['vol'] + x['dv']) & 0xFFFF
            else:
                x['vol'] = (x['vol'] >> 8) * x['k']
            x['vo'] = x['vol'] >> 8
            x['inc'] = (x['inc'] + x['sl']) & 0xFFFF
        tot = sum(x['vo'] for x in s)
        if volumes_only:
            yield tot
            continue
        bias = (128 - (tot >> 1)) & 255
        for _ in range(TICKLEN):
            acc = 0
            for x in s:
                x['ph'] = (x['ph'] + x['inc']) & 0xFFFF
                acc += (WAVES[x['wv']][x['ph'] >> 8] * x['vo']) >> 8
            yield (acc + bias) & 0xFC


def check(lst):
    """The sample loop's cycles in the data file's listing (lwasm --6809, opt c) must be TLOOP."""
    on, tot = False, 0
    for line in open(lst):
        if re.search(r'\)\:\d+ +(\[\d+\] +)?smp\s', line):
            on = True
        if on:
            if re.search(r'\d+ +smpend', line):
                break
            m = re.search(r'\[(\d+)\]', line)
            if m:
                tot += int(m.group(1))
    if tot != TLOOP:
        sys.exit("tune.asm's sample loop is %d cycles: set TLOOP in tools/mktunes.py to match" % tot)


def main():
    if sys.argv[1] == '--check':
        return check(sys.argv[2])
    out = sys.argv[1]
    wavdir = sys.argv[sys.argv.index('--wav') + 1] if '--wav' in sys.argv else None
    tunes = {'tlose': lose(), 'twin': win()}
    lines = ['* Made by tools/mktunes.py: the tunes for tune.asm. Do not edit.',
             '* %d cycles a sample, %.1f samples a second, %.2f ms a tick' % (TSAMP, RATE, TICK * 1000),
             'TASKLEN equ     %d' % TASKLEN,
             'tunetab fdb     tlose,twin']
    for name, evs in tunes.items():
        p = max(simulate(evs, volumes_only=True))
        if p > 254:
            sys.exit('%s: the volumes add up to %d (most 254)' % (name, p))
        lines += asm_events(name, evs)
    for name, t in WAVES.items():
        lines.append('        align   256')
        lines.append(name)
        st = [t[i ^ 0x80] for i in range(256)]       # read as (signed phase) from the middle
        for r in range(0, 256, 16):
            lines.append('        fcb     ' + ','.join(str(b) for b in st[r:r + 16]))
    open(out, 'w').write('\n'.join(lines) + '\n')
    if wavdir:
        for name, fn in (('tlose', 'tune-lose.wav'), ('twin', 'tune-win.wav')):
            data = bytes(simulate(tunes[name]))
            w = wave.open('%s/%s' % (wavdir, fn), 'wb')
            w.setnchannels(1)
            w.setsampwidth(1)
            w.setframerate(round(RATE))
            w.writeframes(data)
            w.close()
            print('wrote %s/%s (%.1f s)' % (wavdir, fn, len(data) / RATE))


if __name__ == '__main__':
    main()
