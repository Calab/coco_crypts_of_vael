# Crypts of Vael for the TRS-80 Color Computer 3

A first-person dungeon crawl with typed commands, written in 6809 assembly for the Tandy Color
Computer 3. You descend five levels of randomly built crypts by torchlight, fight what lives there,
and try to take the Ember Crown from the Hollow King.

This is a port of the web game *Crypts of Vael* by Steve Norton. The rules, monsters, items and
numbers follow the web version; the graphics, sound and memory use were rebuilt for the CoCo 3.

- 640 × 192 vector graphics: walls, monsters and items drawn as lines, fading with distance from
  your light
- Smooth steps and turns, with a two-page display so nothing flickers
- Random mazes from a seed: the same seed always gives the same five levels
- Monsters that sleep, wander, hunt you and call out in the dark
- Items, two hands and a pack: weapons, shields, torches, lanterns, potions, relics and a map
- Sound effects in the background through the 6-bit DAC, plus win and lose tunes
- Plays on an RGB monitor or a composite TV (chosen at start-up)

## Playing

### What you need

- A Color Computer 3 with at least 128K, and Disk Extended Color BASIC
- A way to read the disk image: a floppy drive and a written 5.25" disk, a floppy emulator such
  as a Gotek with FlashFloppy, or a CoCoSDC
- An RGB monitor (CM-8 or similar) or a composite TV

Or an emulator such as [XRoar](https://www.6809.org.uk/xroar/) or MAME, set up as a CoCo 3 with
128K and a disk controller. You need your own CoCo 3 ROM images; they aren't included here.

### Starting the game

The disk (`vael.dsk`) holds two files, `VAEL.BIN` and `VAELDATA.DAT`; both must be on the same disk.
At the `OK` prompt type:

```
LOADM"VAEL":EXEC
```

Press **R** for an RGB monitor or **C** for composite. You can switch later with `MONITOR RGB` or
`MONITOR COMPOSITE`.

At the title, type a seed and press ENTER, or just press ENTER for a random maze. A seed can be a
number or any words; the same seed always builds the same maze.

### How to play

You start in the dark at the top of the crypts with a torch and a map in your pack, and a dagger at
your feet. Each level has a ladder down; the Hollow King waits on the fifth. Take his crown to win.

Type commands and press ENTER. Words can be shortened (`M` = MOVE, `T L` = TURN LEFT), ENTER on its
own repeats the last command, and `L` / `R` mean your left and right hands. Type `HELP` in the game
for the full list.

| Command | What it does |
| --- | --- |
| `MOVE` · `MOVE BACK` / `LEFT` / `RIGHT` | Step forward, or that way |
| `TURN LEFT` / `RIGHT` / `AROUND` | Face a new way |
| `DESCEND` / `ASCEND` | Climb a ladder |
| `ATTACK L` / `R` | Strike with what that hand holds |
| `GET L` / `R` [item] | Pick something up into a hand |
| `DROP L` / `R` · `STOW L` / `R` | Put it down, or put it in your pack |
| `PULL L` / `R` item | Take something out of your pack |
| `USE L` / `R` · `USE` item | Light a torch, drink a potion, read the map |
| `EXAMINE` | Your pack, light, rank and the run so far |
| `SLEEP` 1–20 | Rest to heal (not with enemies close) |
| `LOOK` | Back to the corridor view |
| `PAUSE` · `QUIT` | Stop the clock · give up |
| `SEED` [number] | Show the seed, or start a new maze |
| `SOUND` 0–9 | Volume (0 is off) |
| `MONITOR RGB` / `COMPOSITE` | Change the colours to suit your display |

A few tips:

- Light your torch first: `PULL L TORCH`, then `USE L`. In the dark you can barely see, and
  monsters can't see you far either. Torches and lanterns burn out.
- Every step tires you, and a fast heartbeat means you need to stand still and get your breath
  back. Resting heals you slowly; `SLEEP` lets the time pass quickly while you heal, but a monster
  that finds you gets the first blow.
- Picking things up and killing monsters gives experience. Higher ranks hit harder and dodge more.
- The status rows show what's in each hand, your health, rank and experience.

## Building

### Requirements

- [lwtools](http://www.lwtools.ca/) (`lwasm`)
- Python 3 (standard library only)
- GNU make
- [XRoar](https://www.6809.org.uk/xroar/) with CoCo 3 ROMs, to run it (`make run`)
- `make shapes` and `make mazecheck` also need `gjs` (GNOME JavaScript) and a copy of the web
  version in `reference/`, which isn't included here. They regenerate or check data that's already
  in `src/`, so the normal build doesn't need them.

### Commands

```
make            # build build/vael.dsk (VAEL.BIN and VAELDATA.DAT)
make run        # run it in XRoar on an RGB monitor
make run-cmp    # run it in XRoar on a composite monitor
make clean
```

There are more targets for testing: headless screenshots, scripted key presses, draw timings,
profiling, and WAV files of the tunes and sound effects. They're listed at the top of the
`Makefile`, along with the build options. Their output goes to `~/tmp` (set `SHOTDIR` to change
it). Test builds include a few extra commands for getting around quickly; the normal build
doesn't.

### How it fits in 128K

The game uses the CoCo 3's memory management to fit:

- Two 32K screen pages, drawn and shown in turn.
- Fixed code and buffers in the first 16K, and more code at the top of memory.
- A common bank holding the font, tables and text.
- Banks for the level being built, each level's saved state, and the sound effects, level
  generator, attack pictures and help text.

Everything that LOADM can't place is carried in `VAELDATA.DAT`, which the program reads with Disk
BASIC's DSKCON as it starts and then copies into the banks. After that it runs without any ROM
routines, with its own interrupts for the keyboard, timing and sound.

## Project layout

| Path | Contents |
| --- | --- |
| `src/` | The 6809 source (`main.asm` is the entry point), the font (`font.txt`) and generated shape data |
| `tools/` | Python build tools (tables, font, sounds, tunes, disk image, relocation) and test helpers |
| `Makefile` | The build and all test targets |
| `CLAUDE.md` | Design notes: the memory map, build options, every agreed difference from the web version and why (written as working notes for Claude Code) |

## Credits

By Steve Norton and Claude AI.

## License

Copyright (C) 2026 Steve Norton.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License, version 3 or (at your option) any later version. It comes with no
warranty. See [license.txt](license.txt) for the full terms.
