# Crypts of Vael — TRS-80 Color Computer 3 port

A port of **Crypts of Vael**, a first-person vector dungeon crawl with typed commands, from its
single-file HTML/JavaScript version to the **TRS-80 Color Computer 3** in **6809 assembly**. C compiled
with CMOC is allowed for non-critical parts if it saves time. Line drawing and sound stay in assembly.

- Review files (screenshots, WAVs) go in **`/home/steve/tmp/vael`** (`SHOTDIR` in the Makefile).
- The disk image Steve hands out is `dist/crypts-of-vael.dsk`.

## The reference

- `reference/crypts-of-vael.html` is the web version, copied in as of v1.0.2. It is the spec: game
  rules, numbers, text, shapes and sounds all come from there where possible.
- `reference/Crypts of Vael Monster and Item Reference.odt` lists every monster and item with its stats.
- **Never edit anything in `reference/`.** The live web game lives in a separate project
  (`~/Coding/crypts_of_vael`). Don't touch it from here either. If the web game changes, Steve copies
  a new snapshot in on purpose.
- The game is **original**: it borrows the *mechanics* of an old TRS-80 dungeon game but has its own name,
  monsters, items and random mazes. Since this port runs on the same machine as that game, take extra
  care: don't copy that game's name, maps, monsters, art, sounds or look.

### Where things are in the reference (by its `// ----------` section markers)

| Section | What it holds |
| --- | --- |
| setup | screen size (800×500 logical, 3D view 440 high), colours, seeded RNG (`mulberry32`), `parseSeed` |
| audio / music / victory hymn / background music / monster voices | Web Audio synthesis: `SFX`, `TUNES`, `MUSIC` patterns, `musicTick`, `inCombat`. Only `TUNES` (win/lose) and simplified `SFX` are ported; no background music |
| data | `ITEMS`, `MON` (monsters, weakest first), `LEVELS` (what spawns on each depth) |
| maze | `makeLevel` / `buildLevel` |
| commands | `VERBS` and the command parser (abbreviations, MOVE/TURN/ATTACK/GET/…) |
| simulation / sleeping / experience | monster AI, combat, fatigue, SLEEP, XP and ranks |
| vector shapes | `ICON` (items), `SHAPE` (monsters, in units where the floor is y = 0 and ~2 is head height), `HERO` (title figure) |
| rendering | `renderMain` (the corridor view), maps, pack view |
| title-screen attract mode | the demo maze the title wanders through (not ported: the CoCo title is static) |

## Must match the web version

<!-- - **Same seed → same maze.** Port `mulberry32`, `parseSeed` (FNV-1a for text seeds) and the per-level seed
  `(seed ^ imul(depth, 0x9E3779B1)) >>> 0` bit-exactly in 32-bit integer maths.
  - `rnd(a, b)` is `a + floor(RNG() * (b-a+1))` with `RNG()` = `u32 / 2^32`. In integers that is exactly
    `a + ((u32 * n) >> 32)`, so no floating point is needed.
  - Before relying on this, confirm `buildLevel` uses nothing but `RNG`/`rnd`/`pick` for its choices.
    `Math.random` elsewhere is cosmetic or in-play randomness and doesn't need to match. -->
- Entering the same seed in this version should always generate the same maze. It does not need to match the maze in the html version.
  Still port the web version's `mulberry32`, `parseSeed` (FNV-1a for text seeds) and per-level seed: they are
  cheap on the 6809, and if ported exactly the web game becomes a free check on maze generation.
  - **Done and verified bit-exact** for the maze grid and ladder cell (`src/rng.asm`, `src/maze.asm`;
    `make mazecheck`). `rnd(a,b)` = `a + ((u32 * n) >> 32)`; `floor(S*S*0.06)` = `S*S*6/100` for every S.
  - Keep calling the RNG in exactly the reference's order when porting the rest of `buildLevel` (items,
    monsters, loot), and extend `tools/refmaze.js` / `tools/mazecheck.py` to compare those too.
- Game numbers (HP, damage, timings, light ranges, XP) should match the reference unless a change is agreed.

## Platform targets and expected compromises

- CoCo 3, 6809 at 1.79 MHz (high-speed poke), 128K RAM minimum; 512K may be used if it really helps.
- Graphics: GIME **320×192, 16 colours** (`VRES_320x16`, `$1E`) from the palette of 64; page-flip
  between two screens for flicker-free drawing. 2 pixels per byte (4 bits each): **160 bytes per row,
  30,720 bytes per page**; a text cell is 8 pixels = 4 bytes per character row.
  - **Logical x is 0–639 everywhere** (projection tables, shapes, attack pictures, map layout,
    `dline`/`muldiv` clipping); `line` halves x on entry. Every line loop steps 4-bit pixels (`com lmask`:
    `$F0` ↔ `$0F`); `xfast` is unrolled by 2 pixel positions; `pixmask`/`lmaskl`/`lmaskr` come from
    `mktables.py`. Fast paths are checked pixel-identical against `NOFAST` (6 scenes incl. REVEAL).
  - Screen split: 3D view on the top 136 lines; below it 7 text rows (4 message lines, 2 status rows,
    the command line), each 40 characters wide. Maps and HELP use the full screen.
  - Pixels are tall: one logical x unit is about 2.5× narrower than a row is high, so shapes and the
    corridor have their y values squashed.
  - **Colour scheme (Steve, 2026-11-20):** 16 entries (`rgbpal`/`cmppal` in `main.asm`, `palsh` 16
    bytes, `setpal` takes 16): 0 black; 1–3 walls white `$3F $38 $07` (3 shades: RGB has only 3
    greys, Steve chose this over 4); 4–7 enemies red `$27 $24 $20 $04`; 8–10 items yellow `$36 $30
    $06`; 11–13 ladders cyan `$1B $18 $03`; 14 text green (1,3,1) `$17`; 15 orange `$26`. A colour byte
    is the entry in both nibbles (`$EE` green…); `setcol` stores it in `lcol`. No mixed (dithered)
    colours (Steve, 2026-11-20: nothing large and filled to use them on).
    Composite: white `$30 $20 $10`, red `$27 $17 $07 $07`, yellow `$24 $14 $04`, cyan `$2D $1D $0D`,
    green `$12`, orange `$06`. Hues are guesses (yellow 4, orange 6, red 7, cyan 13) and fade little
    (intensity 0 is a hue's darkest). Steve (2026-11-20): close enough; the reds vary a lot from light
    to dark, but the pink `$27` is acceptable.
  - **Distance shading:** the reference's `bright(d, range)` (`max(0.15, 1 - d/(range+1.5))`; no light:
    0.5 for your own cell, 0.22 beyond; its random flicker is dropped) gives a shade level 0–4
    (thresholds 0.9 / 0.65 / 0.4 / 0.2), held in table `vpat` (`mktables.py`; rows: 0 = no light, 1-8 =
    range; columns: depth in thirds). `cellpat` sets `vlev`; `shade`/`shadea` (`view.asm`) pick colour
    and dot pattern from `wallshd`, `monshd`, `itemshd`, `ladshd`: the colour's shades bright to dim,
    then the dimmest shade with 50% (`$AA`) and 25% (`$88`) dots. Monsters in the dark: level 4. Like
    the reference, a cell's walls use its near edge's depth; the end wall its own. Pan seam: mid white,
    solid. Each dot-pattern bit covers 1 pixel along a mostly-horizontal line or 1 row of a steep one;
    horizontal lines use it as byte masks anchored to the screen.
  - **Text colours:** green (`TXGREEN` `$EE`) for text; mid white (`TXBLUE` `$22`, an old name) for
    older messages, headings, the title's credits; red (`TXRED` `$55`) for the heart, REVEAL's monster
    letters and YOU HAVE PERISHED; cyan (`TXCYAN` `$BB`) for the hands on the status row; yellow
    (`TXYELLOW` `$88`) for health and RANK/XP.
  - **RGB and composite both supported.** The GIME reads palette values differently on each (RGB: R1 G1 B1
    R0 G0 B0; composite: 2 intensity bits + 4 hue bits), and the CoCo can't detect which is connected.
    - Two 16-entry palette tables; the chosen one is copied into `palsh` and the GIME.
    - At startup ask "PRESS R FOR RGB MONITOR / OR C FOR COMPOSITE", drawn in black `$00` and white `$3F`,
      which look the same on both displays (`askmon` in `kbd.asm`, palette `askpal`).
    - **MONITOR** command switches later: `MONITOR RGB` / `MONITOR COMPOSITE`. The argument can be shortened
      to any prefix (`R`, `RG`; `C`, `CO`, `COMP`, …). The verb itself needs at least `MON`, since `M` and
      `MO` already match MOVE.
    - Composite colours vary by TV and GIME revision; revisit if real hardware disagrees.
    - Make composite look as good as possible, but never at the expense of RGB.
- Expect to simplify: moves glide in 3 frames, turns pan in 2; no black-filled
  (hidden-line) objects or monsters.
- Sound:
  - No background music.
  - Win and lose tunes play through the 6-bit DAC (`$FF20`, top 6 bits). They play on the end-of-game
    screen, so blocking playback (the game waits while the tune plays) is fine.
  - Sounds during play play **in the background** (Steve, 2026-11-19): a GIME timer interrupt feeds the
    DAC while the game draws and reads keys (see **Sound effects** below).
- No floating point at runtime: fixed-point maths, sine/cosine lookup tables, precomputed shape tables.
- Saves and best times should be removed.
- Agree compromises with Steve before making them.

## Agreed changes from the web version

- **Lines only.** Players, monsters, items and walls are all drawn as lines. No filled areas.
- **Font:** one simple bitmap font, used everywhere including the title. Characters are **8×8**, giving
  **40 columns × 24 rows** on both RGB and composite.
  - About 64 characters: space, A–Z, 0–9, `! % ( ) + , - . / : < = > ? [ ] ^ |`, `'`, the `•`
    separator, a cursor block, the heart, and spare slots for symbols.
  - Stored 1 bit per pixel in 16 bytes per character (8 rows × 2 bytes, 4 pixels in the top 4 bits of
    each), expanded to 4 bits per pixel through `fontexp` (2 × 256 bytes), then masked to the text colour.
  - The font must be our own design, not copied from the CoCo ROMs.
  - **Steve owns the font's look** and cleans up `src/font.txt` himself. Don't redraw his characters;
    only add missing ones when needed, and tell him.
  - Line spacing (7 rows of character + 1 blank) is accepted as it is.
  - Source is `src/font.txt`: `= NAME` then 8 rows of 8 `#`/`.`; row 7 stays blank for spacing. Codes
    `$20-$5F` are ASCII; extras: BULLET `$60`, CURSOR `$61`, BAR (`|`) `$62`, hearts `$63-$66`. Missing
    characters (currently `@`, `` ` ``) draw as blanks.
  - `tools/font2asm.py` turns it into `build/font.asm` (`font`, `fontexp`).
- **Renamed (Steve, 2026-11-19):** the MENDING DRAUGHT is the **MENDING BREW** (fits the status row; its
  kind word for commands is still MENDING; same effect).
- **Messages may be shortened** to suit 40 columns. Long ones wrap; Steve and Claude go through the
  reference's long messages together and agree shorter wording. Don't shorten text without agreement.
- **Title screen:** static, using the main font, with the credits and version (see Title below).
- **Movement glide (changed 2026-11-19, Steve's request):** a step forward or back draws two in-between
  frames (1/3 and 2/3 of the way) and then the new position, using the reference's `shift` (forward: from
  the old spot, scenery pulled closer; back: from the new spot, scenery receding). Depth tables are in
  thirds of a cell.
- **Turn pan (2026-11-19, Steve's request):** a quarter turn draws one halfway frame, then the new
  direction. The halfway frame is the reference's pan at v = 1/2: the old view shifted half a screen one
  way, the new view half a screen the other, both clipped at the screen edges (`dline` in `view.asm`:
  shift by `vxoff`, clip to x 0–639 with `muldiv`), plus a seam line at x 320.
- **Attack animations:** one frame each for the player's swing and the monster's strike.
- **Maps** (DUNGEON MAP and REVEAL) use the full screen (done 2026-11-19, `map.asm`), as the reference's
  `renderMap`: walls drawn as edges around open cells; REVEAL ("FULL MAZE (TEST VIEW) - DEPTH n") shows
  everything, YOUR MAP (the DUNGEON MAP item; for now the `XMAP` test command, later USE MAP) only seen
  cells. Seen cells are marked as the reference's `markSeen` (open cells ahead within the light range and
  their side neighbours), every frame that isn't mid-glide/turn, and kept per level in `BANKLVL` ($3B).
  - Layout: title row 0, maze rows 1–21 (cells 2.5× wider than tall so they look square), "LOOK TO
    CLOSE" row 22, command line row 23. Legend (2026-11-20, Steve; on both maps): left of the maze, the
    marks as drawn at this level's size with their words, from row 2 every other row: YOU (first, Steve), DOWN, UP (only
    the ladders the level has) (`legend`, `youmark`, `vmarkc` in `map.asm`). It replaced "V = DOWN
    ^ = UP" on row 22. The message log is hidden while a map is open.
  - Colours: seen walls bright white (`WALLCOL`), unseen ones on REVEAL mid white, solid (`MAPDIM`);
    ladders solid cyan triangles pointing down / up (Steve; the reference's V / ^ lines didn't show at
    this size); you a green arrow outline (`TXGREEN`; orange was too close to the red inside, Steve) with
    a half-size red one inside (2026-11-20: the outline drawn twice, the second a pixel larger each way,
    and wider when pointing up/down: back corners 0.9 of its length, not 0.7); items yellow diamonds;
    monsters red letters.
  - Maps stay open while moving and turning (no glide/pan then), as the reference's `mapSafeView`; LOOK
    or changing level closes them. Drawing takes 0.35 s (level 1) to 0.5 s (level 5); joining
    neighbouring edges into longer lines would roughly halve it if needed.
- **Ladders (drawn 2026-11-19):** as the reference: trapezoid outline from 0.2 to 0.8 into the cell,
  half-width 0.35, rails and three rungs at 0.7 of that; on the floor for the down ladder (far cell,
  levels 1–4), in the ceiling for the up ladder ((1,1), levels 2–5). Colour: cyan (`ladshd`; `LADCOL` on the map). Shaded
  like the cell's walls (near edge). One deliberate difference: **no rungs** when the ladder is under 6 rows deep (outline
  and rails only); packed tighter, the rungs' dots merged into a solid patch that showed farther away than
  the walls. (Shading ladders one step dimmer was tried and rejected: it dotted the ladder in your own cell.)
  Geometry from `ltab` (`mktables.py`); drawn by `contents`/`ladder` in `view.asm`, far to near after the
  walls.
- **Commands:** REVEAL stays. The SHIFT-F3 shortcut is removed. SAVE, LOAD, ANIMATE and MUSIC are removed.
- **Items, part 1 (2026-11-19): placement and drawing.**
  - Placement is the reference's `buildLevel` (`placeitems` in `maze.asm`): used = {start, far}, seed 0's
    showcase cells on level 1 (path steps 3, 5 … 15 from (1,1) toward the far cell), then the level's own
    items with free(3) and 4 + n fillers with free(2) + pick(FILLER), same RNG calls in the same order.
    Verified identical for 5 seeds × 5 levels (`make mazecheck`, which now compares items too).
    `tools/refmaze.js` now calls the reference's own `buildLevel`/`makeLevel` and also prints monsters.
  - The new game's dagger at (1,1) is added after building level 1, as the reference's `newGame`.
  - Each level's items are kept in `BANKLVL` (after the seen cells, 256 bytes per level: count + up to
    48 records of x, y, kind, light seconds left) and restored when you come back (`lvlvis`); the maze
    is rebuilt each visit but its fresh item placement is then discarded.
  - Drawn as the reference: the `ICON` shapes (one still frame) on the floor at depth d + 0.45 (except
    your own cell, Steve: 0.2, so they read as at your feet; blending to d + 0.45 one cell out), side by
    side if several share a cell, shaded like the cell, in yellow (`itemshd`; `ITEMCOL` on the map). Shapes come from the reference via `make shapes` (`tools/refshapes.js`
    under gjs → `tools/mkicons.py` → `src/icons.asm`, kept in `src/` so the normal build needs no gjs).
    Per-depth floor y, scales and spacing: `itab` in `mktables.py`.
  - REVEAL marks items with diamonds (the reference's map). "YOU SEE A …, AN … HERE." after each move.
- **Items, part 2 (2026-11-19): using them** (`items.asm`), as the reference:
  - Two hands, a pack of 8; a new game starts with a torch and the map in the pack, nothing lit (dark:
    "IT IS DARK. YOU CAN BARELY SEE." at the top of the view), 100/100 health, the dagger at your feet.
  - GET/DROP/STOW/PULL hand [words], USE hand or USE words (hands first, then pack), EXAMINE (the pack
    view, in the view area: pack, floor, light and seconds left, facing, depth, foes slain, rank, XP,
    damage, dodge, seed; LOOK closes it, so does moving or turning). Words match the reference's
    `itemMatches` (each word starts a word of the name or the kind word). Replies are the reference's.
    PULL also takes the pack view's number (`PULL L 2`, ours, 2026-11-21: the view shows numbers
    but the reference never accepted them); a number past the pack's end gets NO SUCH THING.
  - An item is one byte: kind + `$80` once it has given its pick-up XP (3 XP; not the crown).
  - USE: lights burn (torch 4 cells / 200 s, lantern 7 / 420 s; reach shrinks over the last 45 s as
    the reference's `lightRange`; "… GUTTERS OUT. DARKNESS."); potions (mending +50, herb +20 up to
    the most health; vigor +20 to both); relic 15 XP; the map opens YOUR MAP; weapons/shields say to
    ATTACK. XP gives ranks (25 each, up to 10) with "YOU GROW MORE SKILLED!".
  - `gameclock` (main loop) counts seconds of play from the 60 Hz ticks; it stops while paused, while a
    Y/N question is up and after the game ends.
  - Walking into a wall costs 2–4 health; at 0 the game ends (the reference's `die` messages); then only
    RESTART or QUIT do anything (`gmode` 2) — plus EXAMINE (the pack view: inventory, stats, seed) and
    LOOK back to the end view (Steve; the reference allows only RESTART). REVEAL also works there, but
    it's a troubleshooting tool only: **never mention REVEAL to players** (messages, HELP).
  - Status row 21 (Steve's layout): "L: item" from column 0, the heart (columns 15–16, red), HP from
    column 17 (yellow), "R: item" ending at column 39 (hands cyan, held or empty). Every item name is at
    most 12 letters (a longer one would show its kind word instead). Row 22 (Steve): "RANK n  XP n"
    centred (yellow), WINDED / EXHAUSTED at the right end (green). The message log is 4 lines (rows 17–20).
  - The heart: font characters HEARTL/HEARTR (`$63/$64`, beating) and HEART2L/HEART2R (`$65/$66`, between
    beats), added by Claude for Steve to redraw. `heartbeat` (main loop) beats as the reference: every
    (180 + 920 × health^1.5) ms (`hbbase`, by health in 16ths), ÷ (1 + fatigue/6), at least 150 ms; the big
    heart shows 100 ms of each beat; small and still once the game is over.
    **The beat is timed by the IRQ** (2026-11-20, Steve: it went erratic while the CoCo was busy):
    `hbtick` (sound area) sounds it when `ticks` reaches `hbnt` and sets `hbflag`; `heartbeat` (main
    loop) sets the period `hbper` (real ticks, worked out at each beat), switches it on and off (`hbon`)
    and shows the big heart when `hbflag` is set (the picture can still lag while drawing; the sound
    doesn't). Measured: beats exactly one period apart through a burst of moves and turns. `sndplay`
    masks interrupts from its first instruction, as the IRQ calls it too. `irqinit` clears `$0D68-$0DFF` before the IRQ starts:
    on a real CoCo that page holds Disk BASIC's leftovers, and a stray `hbon` gave a grumble of beats
    right after R / C (XRoar's leftovers there happen to be harmless, so it didn't show headless).
    New direct page variables must be in that cleared range or set before use.
- **Monsters, part 2 (2026-11-19): placement and drawing** (no movement or combat yet).
  - Placement is the rest of the reference's `buildLevel` (`placemons` in `maze.asm`): each level's
    monsters in its LEVELS key order with free(8), level 5's king on the far cell, seed 0's showcase
    (asleep, `MF_DORMANT`), then loot for all but the king: RNG() < 0.35 ⇔ u32 < `$5999999A`, then
    pick(LOOT). Health = round(hp × (1 + (n−1) × 0.28)) from a table. Verified identical (positions, kinds,
    loot, dormant) for 5 seeds × 5 levels by `make mazecheck`.
  - Record (`MONREC` 14): x, y, kind, hp (2), most hp (2), carried item ($FF none), flags, 5 bytes for the
    simulation. Up to 20 per level; current level's in `mons` (low buffers), others in `BANKLVL`.
  - Drawn as the reference: straight ahead at depth max(0.3, d − 0.15), scale 1.2 (the `SHAPE` shapes,
    one still pose, `src/monsters.asm` in 1/60 units, from `make shapes`); in side passages, peeking
    round the doorway (clipped to it: `dline`'s window `vwl..vwr`); red; shaded like the cell, or
    faintest (level 4) in the dark, where only your cell and the next show them. Lines only: walls show through.
  - REVEAL: red line letters (S C B H W G K) sized to the cell, a yellow mark if it carries something,
    and "n FOES  n ITEMS" in the title (shortened from "FULL MAZE (TEST VIEW)").
  - Messages: "YOU ARE FACE TO FACE WITH THE …!" / "THE … SLEEPS RIGHT HERE."; GET refuses with "THE …
    IS IN THE WAY. KILL IT FIRST." / "THE … GUARDS IT. KILL IT FIRST." as the reference.
  - **Hidden lines inside a shape (2026-11-19, Steve: wraith's cloak folds across its face, a line down
    the hound's face):** the reference's `drawPolys` fills each closed polyline black before stroking
    it, in order, so later closed parts hide earlier lines. `mkicons.py` (`hide`) cuts those hidden
    pieces out when the shapes are made (nonzero winding, as the canvas), for items and monsters.
    Separate objects still show through each other (lines only, as agreed). Monsters: 914 points.
  - **Simpler shapes (agreed with Steve):** `mkicons.py` simplifies every polyline (Douglas-Peucker,
    1.5 rows at the nearest size, x counted at 0.4 per logical x unit): monsters 1213 → 887 points, icons 546 →
    348. Each polyline carries its size; `drawshp` skips any smaller than `MINDETAIL` (3) rows at the
    distance it's drawn (eyes, rivets, teeth far away).
  - **Speed:** seed 0's showcase walk went from 290 ms average / 717 ms worst to 243 / 533 with the
    simpler shapes, and 235 with the fast line routine (`xfast` in `draw.asm`: solid, mostly-horizontal
    lines up to 255 wide gather a byte's pixels and write it once, unrolled by pixel position; checked
    pixel-identical to the old loop). Drawing every line solid (no distance dots) only saves ~5%.
    Ordinary seeds ~97 ms. (Speed figures here were measured 2026-11-19.)
  - **Profile** of a crowded 301 ms frame (`make profile`): steep + vertical line loops 22%, shape
    points (`ipoint`/`scl`/`drawshp`) 23%, `xfast` and its flushes ~16%, clearing the view 8%, doorway
    clipping maths (`muldiv`, 1,800 cycles a call) 6%, the rest setup and the keyboard IRQ.
  - Then (agreed with Steve): `muldiv` finds only the 8 quotient bits (~550 cycles; checked against
    exact maths); solid one-colour vertical lines (`vline0`, keep/set masks, 2 rows a loop) and steep
    lines (`yfast`, 8-bit Bresenham) have fast paths; shape points scale inline (`ipointm`/`ipointi`,
    chosen once per shape; monsters' /64 is two double shifts plus the carry). All checked
    pixel-identical against `NOFAST`. Now: that frame 268 ms; seed 0's walk 210 ms average / 450 worst;
    ordinary seeds ~90 ms. What's left is spread out: two multiplies per shape point (~140 cycles), the
    per-segment work in `drawshp`, clearing the view (24 ms), flushes, dotted walls' vertical lines.
- **Monsters, part 3 (2026-11-19): the simulation and combat** (`sim.asm`), as the reference's `update`:
  - Play clock `stime` (60ths of a second; advances in `gameclock` only while playing: not paused, no
    Y/N question, game not over), so pausing freezes the monsters as the reference's timer shifting does.
    **It also stands still while the CoCo draws and works** (Steve, 2026-11-19): after each command and
    each redraw the main loop drops the ticks that passed (`@still`). A step costs ~0.57 s of drawing
    here against the web's 0.14 s, which gave monsters ~4× the moves per step and made them gang up;
    now, as in the web version, they only get the time you spend looking and typing. Light, healing and
    fatigue follow the same clock. **Only your commands' drawing is dropped** (fixed 2026-11-20): redraws
    caused by monsters moving count as time (`keyed` in the main loop). ATTACK's drawing counts too (`swung`, set
    by `c_attack`; Steve, 2026-11-20: the arm took too long to be ready, as the swing's 0.1–0.3 s of
    drawing came on top of the reference's recovery). `keyed`/`swung` are direct page `$0D68`/`$0D69`. Dropping those too made a feedback
    loop: in a crowd, with a light, nearly all the time went on monster redraws and the clock almost
    stopped (Steve: a slime mould beside him never struck, no cries, until his light went out).
    `newplayer` also resets `nextcry` now (an old game's value silenced cries for minutes).
    `newgame` must call `newplayer` (play clock to 0) **before** `enterlevel` (whose `monwake` sets each
    monster's next turn to the clock): the other way round, after SEED/QUIT every monster waited as
    long as the previous game had lasted (fixed 2026-11-20).
    Reference milliseconds × 0.06 = ticks (`mstats`, `wstats`). In-play randomness uses the RNG freely.
  - After each move (and entering a level, XJUMP) `pbfs` works out steps from you (`dist` in the scratch
    bank, read with `pdat`); entering a level lets every monster act at once (`monwake`).
  - Monsters: asleep ones wake at 0–1 steps ("STIRS AND NOTICES YOU!"); each turn (move × 0.8–1.2) a
    monster next to you steps into your cell if it's free, else strikes when its arm is ready; others
    chase (seeing you down a hall: 20 cells lit / 6 dark; or within 6 + depth steps: **changed from the reference's 14 + 2 × depth**, Steve 2026-11-20, as monsters
    ganged up from most of the level) by stepping
    closer, or wander (60% of turns); "YOU HEAR … NEARBY..." at most every 9 s within 5 steps.
    A move redraws the view if the monster was within 10 steps (or on REVEAL); the main loop redraws
    whenever `vdirty` is set, key or no key.
  - Their blows: hit, then your dodge (rank × 5%, max 50%), then a shield's block if it's in front
    (`blockb`/`blockt`: the reference's Math.round results, taken from JS); "THE … STRIKES!" /
    "SOMETHING STRIKES FROM YOUR LEFT!" etc.; at 0 health "YOUR HEART FALLS SILENT…".
  - You: each step (`exert`) adds fatigue and strain (0.355 + 0.02 f + 0.125 f² health; fatigue kept × 30,
    easing 2 a second); WINDED (4+) / EXHAUSTED (8+) after HP on the status row, with the reference's
    warnings; resting heals 1 a 1.2 s (not hurt 3 s, still 1.5 s, fatigue < 5); at 10 health you faint:
    the view goes black, commands get "YOU ARE UNCONSCIOUS...", until healing lifts you above 10.
  - ATTACK hand: weapon hit/damage/speed (bare hand and shields too), swinging costs 1 health, your cell
    then the one ahead, sleepers wake, damage + rank; kills give the death message, XP, +4 most health (to
    250), the loot dropped, and for the king the crown; GET on the crown wins. XXX kills the monster in
    your cell, ahead or beside you (test). XJUMP now also works on level 5 (to the king's cell).
- **Win and lose tunes (2026-11-19, for Steve to listen to)** (`src/tune.asm`, in the data bank;
  `tools/mktunes.py` → `build/tunes.asm`): the reference's `TUNES.death` (lament, 66 bpm, triangle +
  sine) and `playVictory` (two horns, drone, timpani at 120 bpm). Four voices mixed in software into the
  DAC: each a 16-bit phase through a 256-byte wave table × an 8-bit volume; a bias cancels the DC so
  volume changes don't thump; volumes add up to ≤ 254. Interrupts off while it plays; a key pressed
  (after all keys were up) stops it. `die`/`win` set `tunereq` (so does a monster's killing blow in `mattack`, which doesn't go
  through `die`: it was missing until 2026-11-20); `flashoff` must keep A (`tunego` holds the tune number in it; a
  monster's killing blow leaves the hurt flash up, and A = 0 sent the player into random memory). the main loop plays it (`tunego`) once
  the end screen is drawn.
  - **Samples must be evenly spaced.** The first version (5 voices) stopped for 1–2 samples every 64
    to read its events; Steve heard static in the win tune (measured: 4.5× the error of an even
    version; the 6-bit DAC itself adds almost none). Now every sample is followed by exactly one small
    *task* (start of tick, one event = 2 tasks, each voice's volume and slide, bias, keyboard, idle),
    all padded with NOP/BRN to the same length: 215 + 75 = **290 cycles a sample, 6172 Hz**, 64 samples
    a tick. **After any change to `tune.asm`, run `make tunetime TUNE=1` and `TUNE=2`** (XRoar trace,
    `tools/tunetime.py`: every pass must be 290). The build checks the loop's own 215 (`mktunes.py --check`
    against `data.lst`). At most 26 events a tick (mktunes moves extras to the next tick).
  - Left out (to agree with Steve): the hall reverb, the horns' detuned pairs, moving filter and
    vibrato (one horn wave with 4 harmonics instead); the timpani's noise thud is a rougher wave
    (`wtimpa`) for the first 0.18 s of each drum. Rebalanced: the reference's timpani are 5× a horn;
    here horns 77/60, drone 38, timpani 64 × strength.
  - **Open (Steve, 2026-11-19):** the lose tune plays perfectly; the win tune still has a couple of
    small bits of static (the loud static was the floating single-bit sound line). Come back to it if
    it persists. The program's DAC output was checked clean from an XRoar trace
    (`/home/steve/tmp/tune-win-xroar.wav`), so suspects are the DAC's steps at 6.2 kHz (bright horns),
    XRoar's audio buffer (`AO="-ao-buffer-ms 200"`), or the brief bias mismatch when a volume jumps.
  - `make tunes` writes `/home/steve/tmp/vael/tune-lose.wav` and `tune-win.wav` by running the events through
    the same integer arithmetic (XRoar can't record audio). `TUNETEST=1|2` build plays one at start-up
    and stops at `tunedone`: `make -B run DEFS=-DTUNETEST=2` (then `make -B` for the normal game).
- **SLEEP n (2026-11-19)**, as the reference's `startSleep`/`sleepTick`/`endSleep` (`c_sleep` in `cmd.asm`,
  helpers `monbeside`/`slstrike` in `sim.asm`): n = 1–20 moves of 5 s, refused with an awake monster
  0–1 steps away or a blow in the last 4 s (`laststruck`). The game runs forward in 50 ms steps exactly
  as play (play clock, light, `simulate`); woken at once by a monster beside you or a blow (`lasthurt ==
  stime`), or dying. Then the reference's messages (WAKE AFTER / JOLTED AWAKE + the blow or who's beside
  you / HEALTH a -> b / light BURNED OUT / STILL TOO WEAK; dead: YOU NEVER WAKE + the last held-back
  messages). Two differences: the screen goes **straight to black and back** (palette to `$00`; no 2 s
  fade), and only the **last three** held-back messages are kept (`sleeplog`, 3 × 64 bytes in the low
  buffers), which is all the reference ever shows.
- **Play clock wrap:** `stime` is 16 bits (wraps after 18 min) and compared by signed differences.
  `freshen` (start of `simulate`) moves any timestamp more than 10000 ticks in the past up to 10000 ago
  (`fresht` list plus each monster's `MNEXTMV`/`MNEXTAT`). A new timestamp must go in `fresht`, and code
  must not treat a change in a timestamp as an event (test it against `stime` instead).
- **Command line (2026-11-19):** typed commands as the reference's `exec`: words may be shortened to any
  prefix and the first verb in `verbs` (`strings.asm`, the reference's order minus the removed ones, plus
  MONITOR and the X test commands) that fits wins; REVEAL, QUIT, XXX and X… must be typed in full. Empty
  ENTER repeats the last command. Keys follow CoCo habit: left arrow = backspace, SHIFT+left / CLEAR /
  BREAK = clear the line. Keyboard scanned by the 60 Hz IRQ (`kbscan`) into a 16-key buffer (`getkey`).
  - Working: MOVE [BACK/LEFT/RIGHT] (sideways instant), TURN LEFT/RIGHT/AROUND (AROUND = two panned
    quarter turns), DESCEND, ASCEND (arrive on the upper level's down ladder), SEED, SEED <words> or a
    bare number (Y/N to start over), QUIT (Y/N → title), PAUSE, LOOK, MONITOR RGB/COMPOSITE. The rest
    answer "NOT READY YET." (ours) until they exist. Walking into a wall gives the message but no damage yet.
  - Title: static, "CRYPTS OF VAEL"; the command line takes the seed (blank = random 100000–999999, from
    key timing). Seeds are parsed as the reference (`parseseed`: digits mod 2^32, else FNV-1a; verified:
    VAEL = 734810769 on both).
  - Text rows: 17–20 message log (word-wrapped at spaces; lines of the latest two messages green, older
    mid white, as the reference dims older ones), 21–22 status, 23 command line. Depth and seed are
    **not** shown during play (Steve): PAUSE prints "DEPTH n   SEED n" after its message; EXAMINE
    shows them too.
    Text rows are drawn on both screen pages; `paintdirty` redraws what changed.
    Never blank a text row and then write on it: the shown page flashes. The status rows (21–22) are
    built in `SROW` (direct page `$0D80`–`$0DCF`, 80 bytes, filled before it's read; each cell's colour
    in `scol`, 80 bytes of fixed RAM in `main.asm`) and drawn a cell at a time (`status.asm`: `sclear`, `sprint`,
    `sheart`, `sflush`; Steve, 2026-11-20: the hands and health flashed). The log and the command line
    already write each cell once (`rowstr` pads with spaces).
  - Message text is the reference's unless marked "(ours)" in `strings.asm`. Long ones wrap.
    Agreed: "SOMEWHERE BELOW…" stays as it is; the ladder message drops "(DESCEND)"; the QUIT and START
    OVER questions are not logged but shown in the middle of the view while waiting for Y/N (`overlay`,
    as the reference's box: question, then "Y = …" and "N = …" stacked because one line won't fit).
    PAUSE likewise shows "PAUSED" / "ENTER ANY COMMAND TO RESUME" in the middle of the view instead of
    logging "GAME PAUSED…" (the depth/seed line is still logged). The opening "MAZE SEED: n" drops
    "(ENTER THIS SEED TO PLAY THE SAME MAZE)". The SEED command likewise just says "MAZE SEED: n"
    (its "(TYPE SEED <NUMBER> TO START A NEW MAZE)" is dropped).
  - Seed 0's message (2026-11-20, agreed): "TEST MAZE: ONE OF EACH MONSTER SLEEPS ALONG THE PATH. STRIKE
    ONE TO WAKE IT." (wraps as two lines), after MAZE SEED; text in bank `$3E` at `TESTMSG` `$DC00`
    (`bank3e.asm`), copied into `mbuf` by `testmsg` (`cmd.asm`).
- **HELP (2026-11-19, wording agreed 2026-11-20)** (`src/help.asm`, text `src/helptext.asm` in bank
  `$3E` at `HELPTAB` `$DD40`, via `src/bank3e.asm`): view mode 4, full screen like the maps (covers the
  log and status rows); LOOK, moving or turning closes it (as the pack view). One line per row: `{`
  heading colour (mid white), `}` cyan from there (LOOK TO RETURN, Steve), `~` to column 24 for the note, `|` drawn as the font's BAR (Steve redrew it, 2026-11-19,
  so it no longer looks like an I). Notes cut to 16 letters and the footer to 3 lines: the shortenings are listed at the
  top of `helptext.asm`. Never mention REVEAL. (lwasm's raw output doesn't fill an `org` gap: pad
  with `fill`.)
- **Title (2026-11-19, Steve):** "CRYPTS OF VAEL", then "BY STEVE NORTON AND CLAUDE AI" and "VERSION
  1.1.0" in mid white (`s_credit`, `s_version` in `main.asm`). 0.1.0 was the first version; **1.0.0
  is the first release** (Steve, 2026-11-20). 1.1.0 (Steve, 2026-11-21): a small gameplay change (PULL takes the pack number). Bump it only when Steve asks.
- **Attack pictures (2026-11-19, for Steve to look at)** (`src/attack.asm`, data `src/fxpics.asm` +
  `src/fxid.inc` from `tools/mkfx.py`, run by `make shapes`, kept in `src/`): one frame each of the
  reference's `drawSwing` and `drawStrike`, worked out in Python in screen terms (the reference's view
  800 × 440 → 640 × 136 in logical x) and clipped to the view; the game copies a polyline at a time into `ptbuf`
  and draws plain lines over the corridor (`fxdraw` from `drawframe`), holds it `FXHOLD` (15 ticks),
  then redraws (`fxtick` in the main loop; `-DFXHOLD=30000` keeps it up for screenshots).
  - Your blow (`fxswing` from ATTACK): the held item swung in an arc at t = 0.45 (the reference's dotted
    motion trail at 0.30 was removed, Steve 2026-11-20), or a shield / fist thrust at its furthest.
    Your swung item is yellow (`ITEMCOL`, Steve); the fist, shield and monsters' blows orange (`HITCOL`:
    `fxpic1` picks by picture number and ignores the colours stored in `fxpics.asm`).
    Right-hand pictures; the left hand flips x. Items get the shape's hidden lines removed (`hide`).
  - A monster's blow (`fxstrike` from `mattack`): claw rakes (crawler, hound, wraith), blade arc
    (skeleton, king) or impact burst (mould, golem) on the side it came from; a miss or dodge dotted
    (`$88`), a block adds sparks. The reference sweeps it either way at random: front/behind
    flip about the mark's centre, the sides have their own pictures (`FX_STRIKE2`).
  - Points are stored as x / 2.5 (one byte) and y; ~3.1K in bank `$3E` at `$1100` (`$D100`).
  - Not done: the reference's monster lunge and the swing's motion (one frame, as agreed).
- **Hurt flash (2026-11-19, Steve: palette switch):** `fxflash` turns palette entry 0 (black) orange
  (2026-11-20, Steve: RGB `$22` = 34, approved; composite `$06`, hue 6, approved by Steve; it was dim
  yellow RGB `$06` / composite `$04`) for 3 ticks when a monster hurts you, 2 for a wall (Steve; the
  reference's are 160 / 120 ms). The **IRQ** (`irqh`) counts `flashcnt` (direct page `$0D6A`) down and
  puts the black back, so it lasts exactly that long; ended from the main loop (as at first) it stayed
  up through the 0.1–0.3 s redraw. `tunego` ends it at once (`flashoff`, which must keep A) before a
  tune. The whole screen tints, text rows included.
- **Sound effects (2026-11-19, first version, for Steve to listen to)** (`src/sound.asm`,
  `tools/mksfx.py` → `build/sfx.asm`, `sfxid.inc`, `crylv.asm`; Steve chose background sound):
  - The GIME timer (count 1278 at 3.58 MHz: ~2800 Hz) raises FIRQ (`$FEF4` → `firqh`; `INIT0` `$7C`,
    `INIT1` `$20`, `FIRQENR` `$20`); each interrupt puts out the sample worked out last time, then works
    out the next. The timer runs only while a sound plays (`sndplay` starts it, the tick stops it).
    **Silence is DAC level 0** and the sound stays switched on all game. The effects have no
    DC-cancelling bias: each voice starts its wave at phase 0 and rises and falls with its volume, so
    sounds start and end at 0. (Tried and dropped, 2026-11-19: idling at the DAC's middle hissed in
    XRoar; switching the sound on and off around each sound clicked every time, Steve.) The tunes keep
    their bias and glide the DAC from 0 up to the middle and back (`glide` in `tune.asm`, ~23 ms each).
    `sndoff` before a tune.
  - When both voices are idle the tick switches the timer's interrupt off (`FIRQENR` 0) as well as
    setting the count to 0: in XRoar a count of 0 doesn't stop the timer, it wraps every 4096 ticks.
  - Checked from an XRoar trace: samples every 640 cycles (±10, instruction timing), values smooth.
    Steve still hears some random static in XRoar (2026-11-19); suspect XRoar's audio output
    (`AO="-ao-buffer-ms 200"`), check on real hardware.
  - Two voices: 0 the heartbeat, 1 everything else (priority: cries 1, actions 2, hurt/kill/ladder 3; a
    sound doesn't cut off a more important one). Waves made on the spot: saw, square, triangle (stands in
    for sine), noise (LFSR, a new value each phase wrap). Every 32 samples a tick: segments (wave,
    pitch, slide, volume, decay, length) from `BANKSND` `$C400`.
  - Sounds as the reference's `SFX`: beat, swing, hit, hurt, kill, get, thud (wall), step, descend (any
    level change); loudness compressed (square root of the reference's gain) so quiet ones stay audible.
    Low sounds (heartbeat, step, thud, golem) are square waves (a TV speaker barely plays a pure 70 Hz:
    Steve found the heartbeat too quiet); noise parts are at `NOISEGAIN` (0.12) of the reference's
    gain, because unfiltered white noise came across as loud random static (Steve, 2026-11-19).
    Hooks: `sfxa` (full loudness) / `sfx` (A = sound, B = loudness; silent while asleep).
  - Monster cries (the reference's `CRIES`, one voice, layers taken in turn): `crytick` (from
    `simulate`) every 0.9–2 s picks a random monster **among those within 17 steps** (a sleeper
    cries half the time; picking from the whole level made cries ~15× rarer, Steve heard none: fixed
    2026-11-20, `crypick`); within 17 steps it cries
    at `crylv[distance]` (the reference's `cryLevel`). The reference times each monster separately and
    pans them in stereo; the CoCo is mono.
  - `SOUND [0-9]` as the reference (volume × 36, at most 255: 6 = 216, 7-9 full; SOUND alone toggles).
    Default 6.
  - No heartbeat sound while a map is open (the heartbeat routine skips then; the reference keeps beating).
  - `make sfx` → `/home/steve/tmp/vael/sfx-all.wav` (every sound in turn, through the engine's arithmetic).
  - Cost: each sample ~150–200 cycles (~25–30% of the CPU while a sound plays; nothing when silent).
- **Message review (done 2026-11-20, Steve agreed):** the HELP shortenings stay as listed in
  `src/helptext.asm`. Messages over 40 columns: the wrapper (`msg`) breaks after a sentence (". ", "! ",
  "? ") within 40 columns when the rest then fits, so two-sentence messages keep the reference's words
  (PERISHED, WON, GAME OVER, IN THE WAY / GUARDS IT. KILL IT FIRST.). Reworded (marked "agreed" in
  `strings.asm`): TRY: PULL L TORCH, USE L, GET R DAGGER; TYPE RESTART TO RETURN TO THE TITLE.; YOU
  UNFOLD YOUR MAP.; SLEEP HOW LONG? TYPE SLEEP 1 TO 20.; FACE TO FACE WITH THE …!; YOU TAKE THE …. (no
  hand: the status row shows it); YOUR … WENT OUT AS YOU SLEPT.; blows from the side/behind: "THE …
  MISSES FROM THE RIGHT." / "YOU DODGE A BLOW FROM BEHIND." (from the front unchanged), and FROM YOUR
  RIGHT/LEFT → FROM THE RIGHT/LEFT everywhere; deaths: HISSES INTO A PUDDLE!, CURLS UP AND DIES!,
  CRUMBLES INTO BONES!, FADES WITH A MOAN! (Steve's), TUMBLES WITH A CRASH!, SINKS INTO EMPTY ROBES!.
  Still wrapping on purpose: SOMEWHERE BELOW…, YOU SEE … lists. Seed 0's TEST MAZE message isn't
  ported yet; it will need shortening too.
- **End screen (2026-11-20)** (`endpanel` in `cmd.asm`, from `drawframe`), the reference's `renderEnd` in
  40 columns: once the game is over, on the corridor view (not a map, the pack or the help), text rows
  4–13 cleared and: row 5 "YOU HAVE PERISHED" (red) / "VICTORY" (mid white); row 7 "SLAIN BY THE …" /
  die's own message ("YOU DASH YOURSELF AGAINST THE STONE.", "YOUR HEART BURSTS FROM EXERTION.") / "THE
  EMBER CROWN IS YOURS"; row 9 "TIME m:ss (h:mm:ss)   FOES SLAIN n   RANK n"; row 10 "DEPTH n
  DEEPEST n   SEED n" (the reference's "ON DEPTH n" moved here); row 12 "TYPE RESTART AND PRESS ENTER"
  (mid white). Best times left out (agreed). Kept in the direct page: `psec`/`pmin`/`phour` (`playtick`
  from `second`), `deepest` (`deepck` from `enterlevel`), `gwon` (`win`), `dwhy` (`die`'s Y; 0 = a
  monster's blow) and `dkind` (`mattack`); `endreset` (from `newplayer`) clears them.
- **The disk (2026-11-20):** `make` builds `build/vael.dsk` and copies it to **`dist/crypts-of-vael.dsk`**,
  the copy Steve hands out (git-ignored; Steve, 2026-11-20: not `~/tmp` any more). It boots on a real BASIC path: tested
  headless with `xroar -load-fd0 build/vael.dsk -type 'LOADM"VAEL":EXEC\r'` and a trap at `askmon`. A BASIC
  loader (`RUN"VAEL"`) **can't work**: a running BASIC program sits at about `$0E00`–`$2600`, which LOADM
  overwrites, so the rest of its line is garbage (`?SN ERROR`). (`mkdsk.py` can still store ASCII
  files: TYPE ending in A.) To read BASIC's text screen headless: trap at POLCAT (`$A1CB` on Disk BASIC
  2.1) with `-trap-range 3000`, then the 32-column screen is CPU `$0400`.
- **Next:** Steve is
  working out how to get the disk onto a real CoCo 3 (#9).
- **Later, not now:** possible support for the Orchestra-90/CC sound cartridge (stereo 8-bit DACs). Don't build anything for it yet.

## Plan

1. **Proof of concept** (done 2026-11-19): maze generation plus the corridor renderer (walls only, no
   shading) walking through a maze. Arrow keys move and turn, 1–5 change level. Measured: clearing and
   drawing the view takes about 62 ms on average, 100 ms worst (60-frame walk, light range 7).
   With glide, pan and distance shading: 86 ms average, 117 ms worst (80-frame walk). With ladders:
   92 ms average, 133 ms worst. With the keyboard scanned in the IRQ: 97 ms average.
   With items and seen-cell marking: 102 ms average, 167 ms worst (`make walk` uses a lantern).
2. Then movement and the command parser, items, monsters, combat, sound effects, win/lose tunes, title screen.

## Tools and testing

- Assembler: **lwtools** (`lwasm`). Emulator: **XRoar** (or MAME), driven headless where possible.
  Optional: **CMOC**. All three are installed; for anything else, tell Steve what needs installing
  rather than installing system packages unasked. ToolShed is not installed; `tools/mkdsk.py` builds the `.DSK` images instead.
- Layout: `src/` — `main.asm` (entry, title, new game, levels, main loop, IRQ, pages), `gime.inc`
  (hardware equates), `text.asm` (characters, strings, numbers), `kbd.asm` (keyboard, IRQ scan),
  `msg.asm` (message log, text rows), `cmd.asm` (command line and parser), `strings.asm` (verbs and
  messages, in the common bank), `draw.asm` (lines), `view.asm`
  (corridor renderer), `rng.asm` (mulberry32), `maze.asm` (level generation), `fonttest.asm`, `font.txt`.
  `tools/` — `font2asm.py`, `mktables.py` (projection, row address and mask tables → `build/tables.asm`),
  `snapshot.py` (shared snapshot reader), `snap2png.py`, `timing.py`, `refmaze.js`, `mazecheck.py`,
  `relocate.py` (moves banked parts of the `.bin` to loadable addresses; every build runs it).
- `make` builds the data file and `build/vael.bin` (DECB format, plus `vael.lst`, `vael.sym`) and puts
  both on `build/vael.dsk`. `make run` opens it in XRoar on an RGB monitor, `make run-cmp` on composite.
- `make shot [SHOT_AT=label] [SHOT_N=n] [SHOT_NAME=name] [SHOT_MON=R|C] [SHOT_DEFS="-DX ..."]` builds
  `build/shot.bin` with `-D AUTOMON=<R or C>` (headless runs can't press keys) plus `SHOT_DEFS`, runs XRoar
  headless until the CPU reaches `label` for the n'th time (default `framedone`, 1), snapshots, and writes
  `/home/steve/tmp/vael/<name>.png`. The PNG always shows RGB colours; check composite by eye in `make run-cmp`.
  - `make walk [WALK=n]`: `AUTOWALK` build walks n frames by the left-hand rule, prints draw timings,
    saves the last frame. Frame k: `make shot SHOT_DEFS=-DAUTOWALK=60 SHOT_N=k`.
  - `make fontshot`, `make askshot`: the font test screen and the monitor question.
  - `make mazecheck [SEEDS="..."]`: compares all 5 levels with the reference for each seed.
  - `make tunes`: the win and lose tunes as WAVs in `/home/steve/tmp/vael`; `make tunetime TUNE=1|2`: check
    the player's samples are evenly spaced (see the tunes notes above).
  - `make profile SHOT_DEFS="..." PROF_N=n`: traces the n'th `render` in XRoar (`-trace-timing`) and adds
    up the cycles per routine (`tools/profile.py`; XRoar's dt is in 1/8 cycles). Find the slow frames first
    by reading `lastdraw` from snapshots of `SHOT_N=` frames.
  - Test commands exist only in test builds (`TESTCMDS`, defined by `make shot` and so `keys`/`walk`, and
    `make profile`; Steve, 2026-11-20: not in the release). For them in `make run`: `make -B run
    DEFS=-DTESTCMDS` (then `make -B` again for the release). XXX (kill the monster beside you),
    XLIGHT (cycle lantern → torch → none; burns 999 s), XJUMP (face the
    down ladder, 2 cells away if possible), XDEPTH n (go to level n), XINFO (position, facing, last draw
    time).
  - `make keys` passes `SHOT_DEFS` on (it used to drop them). The key script sits in the fixed code
    (about 90 bytes free for it in a test build).
  - `make keys KEYS="12345/M//T L/XINFO/"` types the keys instead of the keyboard (`/` = ENTER, `~` = wait
    one second of game time, e.g. to let a torch burn; long waits need `SHOT_SECS=` above 100; it starts
    at the title, so the first line is the seed; build option `AUTOKEYS` via `build/autokeys.inc`) and
    screenshots the screen when the keys run out. Use it to test commands headless.
  - Build options (`-D NAME[=value]`: `DEFS="..."` for `make` / `make run`, `SHOT_DEFS="..."` for `make shot`
    / `keys` / `walk`; after trying one with `make -B run DEFS=...`, `make -B` again for the release):
    - Release: none. `make` builds the game as it ships (no test commands; REVEAL stays, unmentioned).
    - Testing: `TESTCMDS` (the X commands; `make shot` and `make profile` always define it), `AUTOMON`
      (answer the monitor question: `R` or `C` as a number; `make shot` sets it), `AUTOKEYS` (type a
      script: `make keys`), `AUTOWALK` (a timed left-hand walk: `make walk`), `SEEDVAL` (the seed to
      play), `STARTLIGHT` (7 lantern / 4 torch / 0 none), `STARTHP` (starting health), `BIGHIT` (every
      monster blow 20–30; with STARTHP, to get killed quickly: `make keys SHOT_SECS=150
      SHOT_DEFS="-DSTARTHP=40 -DBIGHIT" KEYS="0/M/M/M/~~~…"`), `FXHOLD` (ticks an attack picture stays up,
      e.g. 30000 for screenshots), `TUNETEST` (1 lose / 2 win: play a tune at start-up and stop at
      `tunedone`).
    - Test screens: `FONTTEST` (`make fontshot`), `MAZETEST` (the maze check, `make mazecheck`).
    - Colours to try on the map: `WALLCOL`, `LADCOL`, `ITEMCOL` (colour bytes, in decimal because the
      shell eats `$`: `make -B run DEFS=-DLADCOL=204`). The corridor's colours are the `*shd` tables.
    - Drawing and timing: `NOFAST` (general line loop only), `NODOTS` (every line solid), `PROF_NOMON`,
      `PROF_NOPEEK`, `PROF_NOLINE` (leave out parts of monster drawing), `LINELOG` (log every line call of
      a frame to `lnlog`; read it from a snapshot when a frame draws wrongly).
- **`gjs` is installed** (GNOME JavaScript). `tools/refmaze.js` runs the reference's own functions, cut
  out of the HTML at run time, so the reference stays untouched. Prefer this over headless Firefox for
  checking logic.
- lwasm gotchas: labels are case-sensitive among themselves (`lowend` and `LOWEND` are two symbols, so
  don't rely on case to tell names apart: easy to mix up), but a `-D` name clashes with a label of the
  same name in any case (`-D FONTTEST` against a label `fonttest`: "multiply defined"); a
  local `@label`'s scope ends at a **blank line** (two routines with the same `@label` need a blank line
  between them); short
  branches fail with "Byte overflow" past ±127 bytes (macros like `LINE` expand large: use `lbxx`/`lbsr`);
  `ldd b,x` overwrites B, so reload the index before a second table lookup.
- XRoar always runs with `-machine coco3 -ram 128`, to stay inside the 128K minimum.
- The GIME registers are write-only, so the program keeps shadow copies for the screenshot tool:
  `voffsh` (vertical offset of the displayed page) and `palsh` (the 16 palette bytes). Both must stay in
  CPU `$0000-$3FFF`, which maps to physical blocks `$38-$39`.
- **Memory: 128K with MMU banking** (agreed 2026-11-19; 512K stays a fallback, not a requirement).
  The CPU map (also at the top of `src/main.asm`):
  | CPU | Use | Physical block |
  | --- | --- | --- |
  | `$0000-$00FF` | low code (`low.asm`: `monletters` now): carried by the data file at offset `$0300` of `BANKSND` (`relocate.py`), copied down by `sndcopy` after the data file is read (Disk BASIC's DSKCON uses this page until then). Up to `lowcend` (`$00E4` now) | `$38` |
  | `$0100-$0BEF` | buffers that start empty: `grid`, `seen`, `nitems`+`items`, `logtxt`, `nmons`+`mons`, `sleeplog` (equates in `main.asm`; LOADM can't load here, so nothing that needs a value at load time) | `$38` |
  | `$0BF0-$0CFF` | stack, grows down from `$0D00` (the build errors if the buffers pass `$0C00`) | `$38` |
  | `$0D00-$0DFF` | direct page variables (DP = `$0D`): lines `$0D00-$0D23`, sound `$0D40-$0D67`, main loop / flash / end screen / heartbeat `$0D68-$0D78`, `SROW` `$0D80-$0DCF`; free `$0D79-$0D7F`, `$0DD0-$0DFF` | `$38` |
  | `$0E00-$3FFF` | fixed code and data, up to `progend` (`$3EAD` now, ~340 bytes left); the build errors past `$3FFF` (MAZETEST builds add ~180 bytes here) | `$38-$39` |
  | `$4000-$BFFF` | the screen page being drawn (`mappage`); while `mklevel` runs, `$8000-$9FFF` holds `BANKSND` (the level generator overlay, at `$8C00`) | `$30-$33` / `$34-$37` |
  | `$C000-$DFFF` | bank window: `BANKCOM` normally, `BANKSCR` while `mklevel` runs, `BANKLVL` / `BANKDAT` briefly, `BANKSND` inside the sound interrupt | `$3A` / `$3C` / `$3B` / `$3D` / `$3E` |
  | `$E000-$FBFF` | high code: `rng`, `maze` (what play also uses), `cmd`, `map`, `attack` (up to `highend`, `$FB26` now, ~210 bytes left) | `$3F` |
  | `$FC00-$FEED` | the sound engine and the monster cries (`sound.asm`, up to `sndres_end`, `$FEC7`; SOUND is in `cmd.asm`), copied up from the data file by `sndcopy` | `$3F` |
  | `$FEEE-$FFFF` | interrupt vectors (`$FEF4` FIRQ, `$FEF7` IRQ), I/O | `$3F` |
  - Common bank (`$3A`): font, `fontexp`, `tables.asm`, `strings.asm`, `status.asm`, and in test builds
    `testbank.asm` (`jump`, for XJUMP). Assembled at `$C000` but stored in the `.bin` at
    `$4000` by `tools/relocate.py`, so LOADM puts it in block `$3A`; `start` maps it into the window.
    The build errors if it passes 8K.
  - Scratch bank (`$3C`, not loaded): `dist`, `queue`, `cstack` for level building. `mklevel` maps it in
    and puts `BANKCOM` back. Anything that draws text or lines needs `BANKCOM` mapped.
  - Level bank (`$3B`, not loaded): each level's seen cells, 1K per level; `seensave`/`seenload` copy the
    current level's in and out of `seen` (fixed) when changing level.
  - High code (2026-11-19): assembled at `$E000` but stored in the `.bin` at `$6000` (`relocate.py`), where
    LOADM puts it in block `$3B`; `start` copies it up to `$E000` before anything else (then `$3B` is free
    for the level bank). It's always mapped, so it needs no bank switching. Code there must not run
    before the copy (only `start`'s first lines do).
  - Sound bank `BANKSND` (`$3E`, the data file's second 8K; `tools/joindata.py`): `$0000` the image of
    `$FC00-$FEED` (copied up at start-up), `$0400` the sound effects (`sndbank.asm` + `build/sfx.asm`,
    read at `$C400` by the sound interrupt), `$0C00` the level generator overlay (`mazegen.asm`,
    assembled at `$8C00`: `mklevel` maps the bank at `$8000` while it runs; nothing draws then),
    `$1100` the attack pictures (`build/fx.dat` from `src/fxpics.asm`, read at `$D100`).
    `relocate.py` takes `$FC00-$FEED` and `$8C00-$9FFF` out of the `.bin` into `NAME.res` / `NAME.ovl`.
    Both call the game's routines, so **every build variant makes its own data file and disk**
    (`build/NAME.dsk`, Makefile's `variant`; `mazecheck.py` does the same).
  - LOADM is only safe below about `$7C00` (BASIC's stack sits near `$7FFF`); `relocate.py` refuses
    anything higher. Load map now: fixed `$0E00-…`, common bank `$4000-$5FFF`, high code `$6000-$7BFF`.
    That fills the loadable space; more will need a second file read from disk at start-up.
  - `tools/snapshot.py`'s `cpu_low` reads both fixed areas (`$0000-$3FFF` and `$E000-$FEFF`).
  - Two screen pages: page 0 in blocks `$30-$33`, page 1 in `$34-$37`. The hidden page is mapped at
    `$4000-$BFFF`, drawn, then shown (`showpage`) right after a vertical-border tick.
  - IRQ: GIME vertical-border interrupt (`JMP irqh` at `$FEF7`, PIA interrupts off) counts `ticks` at 60 Hz.
  - **No BASIC ROM routines are used** (only BASIC's LOADM, to load). Start-up (checked against Steve's
    `remove_basic.txt`): `ORCC #$50`, `CLR $FF40` (drive motor off: Disk BASIC turns it off from its
    own IRQ, which we replace), `STA $FFDF` (all-RAM), own stack/DP, own IRQ via BASIC's `$FEF7`
    redirect (the RAM copy of the vectors at `$FFF2-$FFFF` still points there), PIA IRQs off.
    The single-bit sound line (PIA 1 PB1, `$FF22` bit 1) is made an output, held low (`irqinit`):
    BASIC leaves port B's direction at `$F8`, so that line is an input and floats (Steve, 2026-11-19,
    hunting static in the tunes).
  - **Data file (2026-11-19, option B):** the game is a disk: `build/vael.dsk` (`tools/mkdsk.py`, a DECB
    image) with `VAEL.BIN` and `VAELDATA.DAT`. On a CoCo: `LOADM"VAEL":EXEC`. In its first moments, while
    BASIC still runs, `start` calls `dataload` (`dload.asm`): Disk BASIC's DSKCON (the one ROM call)
    reads the FAT and directory on track 17, finds VAELDATA.DAT on the default drive (`DEFDRV`) and
    reads its sectors into staging blocks `$34-$35` (screen page 1; BASIC runs out of `$3D/$3E`).
    After the take-over `dataplace` copies them into the data bank `BANKDAT` (`$3D`; `$3E` is the next
    block when it outgrows 8K). No file: "VAELDATA.DAT IS MISSING FROM THE DISK" (`nodata`).
  - `src/data.asm` is assembled on its own (raw, org `$C000`) into `build/vaeldata.dat`; the game
    includes its addresses from `build/data.sym`. Holds the item and monster shapes and the tune player with its tunes and wave tables (**full**: ends at `$E000`; the next data goes in `$3E`).
    Anything in it is read only with `BANKDAT` mapped; `drawshp` converts a polyline's points into
    `ptbuf` with `BANKDAT` mapped, then draws with `BANKCOM` back (the line routine needs its tables).
  - Every XRoar run (`make run`, shots, `mazecheck`, `profile`) attaches the disk (`-load-fd0`) and
    `-run`s the `.bin`; BASIC is alive at that point, so `dataload` works the same as after LOADM.
  - Memory still unused: `$3D` none, `$3E` from about `$1DBA` (~0.6K; `dload.asm` reads a data file of up to 16K into `$3D-$3E`). Plan for loading data
    into `$3D/$3E`: a two-file BASIC loader (`LOADM"VAELDATA":EXEC` — data at `$4000-$7BFF` plus a
    stub that copies it into the banks and returns — then `LOADM"VAEL":EXEC`).
- XRoar snapshots are a tagged binary format; RAM follows the `RAM` tag after a variable-length size
  (leading 1 bits = number of extra bytes, e.g. `C2 00 00` = `$20000`).
- CoCo 3 ROM images aren't freely distributable. Steve supplies his own; never download them.
- Node isn't installed. To run the reference game, use headless Firefox (a snap): stage files under
  `~/snap/firefox/common/` and run with `--headless --no-remote --profile <dir> --screenshot <out.png>`.
  Draw on load rather than only in `requestAnimationFrame`, or the screenshot can come out blank.

## Working with Steve

- **Files for Steve to review** (screenshots, emulator captures, audio) go in **`/home/steve/tmp/vael`**.
  He can't open `/tmp` or the session scratchpad. Give the full path.
- **Monsters face the player** head-on. Side and three-quarter views were rejected.
- **Versioning:** semver-style (patch = fixes/tweaks, minor = new content/features). Don't bump the version unless asked.
- Short fragments like "a r" in a message are game commands typed into the wrong window. Ignore them.
- Commit or push only when asked.
