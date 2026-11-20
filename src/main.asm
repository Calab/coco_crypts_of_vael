* Crypts of Vael - CoCo 3
* Proof of concept: ask RGB or composite, build a maze from the seed, walk it in the corridor view.
*
* Build options (lwasm -D):
*   AUTOMON=82 or 67  answer the monitor question with R or C (headless runs can't press keys)
*   SEEDVAL=n         maze seed (default 12345)
*   MAZETEST          generate levels 1-5 and stop at mazedone (tools/mazecheck.py)
*   FONTTEST          show the font test screen instead of the maze
*   STARTLIGHT=n      light at the start: 7 lantern (default), 4 torch, 0 none
*   AUTOKEYS          act out the key actions in build/autokeys.inc (U D L R T 1-5; make keys KEYS=...)
*                     instead of reading keys, then stop at walkdone
*   AUTOWALK=n        walk n frames by the left-hand rule instead of reading keys, then stop at
*                     walkdone (for timing and screenshots)

        include "gime.inc"
        include "fxid.inc"      ; attack picture numbers (tools/mkfx.py)
        include "data.sym"      ; addresses in the data file (build/data.sym, from src/data.asm)

SCRCPU  equ     $4000           ; where the page being drawn is mapped (CPU $4000-$BFFF)

* Text colours for textmask, and colours as line fill bytes
TXGREEN equ     $55             ; colour 1
TXRED   equ     $AA             ; colour 2
TXBLUE  equ     $FF             ; colour 3
        ifndef  WALLCOL
WALLCOL equ     TXGREEN
        endc
* Ladder colour: a fill byte gives each of a byte's 4 pixels its own colour, so a mix in 2-pixel
* runs dithers along the line (fine for the ladder, which has no exactly vertical lines).
        ifndef  LADCOL
LADCOL  equ     $A5             ; red, red, green, green: reads as an olive-gold "yellow"
        endc
        ifndef  ITEMCOL
ITEMCOL equ     TXBLUE          ; solid light blue (the blue/green mix was tried and didn't read well)
        endc

* Two screen pages: draw on the hidden one, then show it.
PAGE0BLK equ    SCR0BLK         ; physical blocks $30-$33
PAGE1BLK equ    SCR0BLK+4       ; physical blocks $34-$37

* Memory map (CPU address: what's there, physical block):
*   $0100-$0BFF  buffers that start empty (grid, seen, items, log, monsters, sleep log)  $38
*   $0C00-$0CFF  stack (grows down from $0D00)                        $38
*   $0D00-$0DFF  direct page variables                                $38
*   $0E00-$3FFF  fixed code and data (must end below $4000)           $38-$39
*   $4000-$BFFF  the screen page being drawn                          $30-$33 or $34-$37
*   $C000-$DFFF  bank window: BANKCOM normally, BANKSCR while a level is built, BANKLVL briefly
*   $E000-$FBFF  high code: copied here by start from where LOADM put it ($6000, block $3B)  $3F
*   $FC00-$FFFF  unchanged ($FExx vectors, $FFxx I/O)                 $3F
* The common bank is assembled at $C000 but stored in the .bin at $4000 (tools/relocate.py), where
* LOADM puts it in block $3A; start maps that block into the bank window.
* Buffers in BASIC's old variable area. LOADM can't load there (BASIC uses it while loading), so
* only things that are filled in before they're read live here.
LOWBUF  equ     $0100
grid    equ     LOWBUF          ; maze, 1 = wall (31*31)
seen    equ     grid+31*31      ; the current level's seen cells (31*31)
nitems  equ     seen+31*31      ; the current level's items: count, then records (kept together
items   equ     nitems+1        ;   for itemsave / itemload)
logtxt  equ     items+48*5      ; the message log (4 lines of 41)
nmons   equ     logtxt+4*41     ; the current level's monsters: count, then records (kept together
mons    equ     nmons+1         ;   for monsave / monload)
sleeplog equ    mons+20*14      ; SLEEP: the last three messages held back (3 x 64)
LOWEND  equ     sleeplog+3*64
        ifgt    LOWEND-$0C00
        error   "low buffers run into the stack"
        endc

BANKWIN equ     $C000
HIGHWIN equ     $E000           ; high code runs here...
HIGHLOAD equ    $6000           ; ...and is loaded here (tools/relocate.py)
BANKCOM equ     $3A             ; common bank: font, tables (loaded with the program)
BANKSCR equ     $3C             ; scratch bank: maze-building buffers (not loaded)
BANKLVL equ     $3B             ; level bank: each level's seen cells, 1K per level (not loaded)
BANKDAT equ     $3D             ; data bank: VAELDATA.DAT (shapes), read from disk at start-up
        setdp   $0D
keyed   equ     $0D68           ; (direct page, after the sound engine's) this time round the main
                                ; loop ran a key
swung   equ     $0D69           ; ATTACK swung: its time counts (c_attack)
flashcnt equ    $0D6A           ; ticks left of the hurt flash (fxflash; the IRQ counts it down)
psec    equ     $0D6B           ; play time (playtick): seconds, minutes, hours
pmin    equ     $0D6C
phour   equ     $0D6D
deepest equ     $0D6E           ; the deepest level reached (deepck)
gwon    equ     $0D6F           ; the game was won (win)
dwhy    equ     $0D70           ; 2: how you died: the message die was given, or 0 for a monster's blow
dkind   equ     $0D72           ; ...whose kind is this
hbon    equ     $0D73           ; the heartbeat is going (heartbeat sets it; hbtick, in the IRQ, beats)
hbflag  equ     $0D74           ; hbtick beat: the main loop shows the big heart
hbnt    equ     $0D75           ; 2: when the next beat is due (ticks)
hbper   equ     $0D77           ; 2: ticks between beats (heartbeat works it out)

        org     $0E00

start   lbsr    dataload        ; while BASIC still runs: read VAELDATA.DAT (the one ROM call)
        orcc    #$50            ; IRQ and FIRQ off: we own the machine from here
        clr     $FF40           ; drive motor off (Disk BASIC would do it from its own IRQ, now gone)
        sta     $FFDF           ; all-RAM mode (BASIC already runs this way; make sure)
        ldx     #HIGHLOAD       ; copy the high code up to $E000 before anything remaps $6000
        ldu     #HIGHWIN
@high   ldd     ,x++
        std     ,u++
        cmpu    #highend
        blo     @high
        lda     #BANKCOM        ; the common bank, loaded at $4000, into the bank window
        sta     MMUT0+6
        lds     #$0D00
        lda     #$0D
        tfr     a,dp
        sta     SPEEDHI         ; 1.79 MHz

        lbsr    dataplace       ; the data file, from its staging blocks into its bank

* GIME: CoCo-compatible mode off, MMU on, constant RAM at $FExx, standard SCS
        lda     #$4C
        sta     INIT0
        lda     #VMODE_GFX
        sta     VMODE
        lda     #VRES_640x4
        sta     VRES
        clr     BORDER
        clr     HOFF
        clra
        lbsr    mappage
        lbsr    showpage

        ifdef   MAZETEST
* Maze check build: generate levels 1-5 for SEEDVAL and leave the results in screen memory
* (level n's grid at SCRCPU+(n-1)*1024; S, farx, fary, fardist at SCRCPU+5120+(n-1)*8; items
* at SCRCPU+6144+(n-1)*256: count, then x, y, kind each)
* for tools/mazecheck.py to read from a snapshot.
        lda     #1
@mt     sta     mtlvl
        lbsr    mklevel
        lda     mtlvl
        deca
        lsla
        lsla
        clrb
        addd    #SCRCPU
        tfr     d,u
        ldx     #grid
        ldy     mz_n
@cp     lda     ,x+
        sta     ,u+
        leay    -1,y
        bne     @cp
        ldb     mtlvl
        decb
        lslb
        lslb
        lslb
        ldx     #SCRCPU+5120
        abx
        lda     mz_s
        sta     ,x
        lda     farx
        sta     1,x
        lda     fary
        sta     2,x
        ldd     fardist
        std     3,x
        ldb     mtlvl           ; items: count, then x, y, kind each, at SCRCPU+6144+(n-1)*256
        decb
        clra
        tfr     d,u             ; (n-1) * 256
        exg     a,b
        addd    #SCRCPU+6144
        tfr     d,u
        lda     nitems
        sta     ,u+
        ldx     #items
        ldb     nitems
        beq     @itd
@it     lda     ,x
        sta     ,u+
        lda     1,x
        sta     ,u+
        lda     2,x
        sta     ,u+
        leax    ITEMREC,x
        decb
        bne     @it
@itd    ldb     mtlvl           ; monsters: count, then x, y, kind, carry, flags each, at
        decb                    ; SCRCPU+7424+(n-1)*128
        lda     #128
        mul
        addd    #SCRCPU+7424
        tfr     d,u
        lda     nmons
        sta     ,u+
        ldx     #mons
        ldb     nmons
        beq     @mnd
@mn     lda     ,x
        sta     ,u+
        lda     1,x
        sta     ,u+
        lda     2,x
        sta     ,u+
        lda     7,x
        sta     ,u+
        lda     8,x
        sta     ,u+
        leax    MONREC,x
        decb
        bne     @mn
@mnd    lda     mtlvl
        inca
        cmpa    #6
        lblo    @mt
mazedone bra    mazedone
        endc

* No data file? Say so and stop (black and white, readable on any monitor)
        tst     dlok
        bne     @dataok
        ldx     #askpal
        lbsr    setpal
        lbsr    clrscr
        lda     #TXBLUE
        sta     textmask
        ldd     #(11<<8)|1
        ldy     #s_nodata
        lbsr    printat
nodata  bra     nodata          ; (screenshot point: the data file is missing)
@dataok lbsr    sndcopy         ; the sound engine, from the data file up to $FC00

* Ask which monitor, in black and white (the same on RGB and composite)
        ldx     #askpal
        lbsr    setpal
        lbsr    clrscr
        lda     #TXBLUE
        sta     textmask
        ldd     #(9<<8)|13
        ldy     #s_title
        lbsr    printat
        ldd     #(12<<8)|8
        ldy     #s_ask1
        lbsr    printat
        ldd     #(13<<8)|11
        ldy     #s_ask2
        lbsr    printat
askshown                        ; screenshot point for the question screen
        ifdef   AUTOMON
        lda     #AUTOMON
        else
        lbsr    askmon
        endc
        sta     monitor
        ldx     #rgbpal
        cmpa    #'C
        bne     @setp
        ldx     #cmppal
@setp   lbsr    setpal

        ifdef   FONTTEST
        lbra    fontscr
        endc

* ---- the game ----
        lbsr    irqinit
        ifdef   AUTOWALK
        lbsr    newgame         ; timing walk: straight into SEEDVAL's maze, no title
        lda     #STARTLIGHT     ; with this light (7 = a lantern that doesn't run out)
        beq     walkloop
        sta     vlight
        ldd     #9999
        std     lrem
        lbsr    lightrange
walkloop
        lbsr    drawframe
        ldd     frames
        cmpd    #AUTOWALK
        lbhs    walkdone
        lbsr    autoact
        lbsr    doact
        bra     walkloop
walkdone bra    walkdone        ; timing results in frames, totdraw, maxdraw
        else
        ifdef   TUNETEST
        lda     #TUNETEST       ; play a tune, then stop (make shot SHOT_DEFS=-DTUNETEST=2 SHOT_AT=tunedone)
        sta     tunereq
        lbsr    tunego
tunedone bra    tunedone
        endc
        lbsr    title
mainloop
        lbsr    gameclock       ; seconds of play: the light burns
        lbsr    simulate        ; fatigue, healing, fainting, the monsters
        lbsr    heartbeat       ; the heart on the status row
        lbsr    fxtick          ; an attack picture's time up?
        lbsr    paintdirty      ; text rows that changed
        ldd     spin            ; (time spent waiting is the randomness for a blank seed)
        addd    #1
        std     spin
        clr     <keyed
        clr     <swung
        lbsr    getkey
        beq     @view           ; no key: but a monster may have moved
        lbsr    editkey
        tst     <swung           ; (a swing's drawing counts: the arm's recovery is real time, Steve)
        bne     @view
        bsr     @still          ; (the command's own drawing and working out took no game time)
        inc     <keyed
@view   tst     vdirty          ; redraw whenever something changed, key or not
        lbeq    mainloop
        clr     vdirty
        tst     gmode
        lbeq    mainloop
        lbsr    paintdirty      ; messages first, then the view
        lbsr    drawframe
        lbsr    tunego          ; the game just ended: its tune, over the end screen
        tst     <keyed           ; (a redraw for a monster's move is time you spend watching: it counts)
        lbeq    mainloop
        bsr     @still
        lbra    mainloop
* The play clock stands still while the CoCo works out and draws your command: the web version draws
* instantly, so its monsters only get the time you spend looking and typing (Steve: they ganged up when
* every step's 0.5 s of drawing gave them extra moves). Drop the ticks that passed since gameclock.
* Only for your commands: dropping the redraws monsters cause too froze the clock in a crowd (each
* move nearby redraws, ~0.3 s that never counted; Steve's slime mould next to him never struck).
@still  ldd     ticks
        std     lastt
        rts
        endc
        ifdef   AUTOKEYS
walkdone bra    walkdone        ; the scripted keys ran out
akeyp   fdb     akeys
akeys   include "autokeys.inc"  ; written by make: fcc "<KEYS>"  ('/' = ENTER)
        fcb     0
        endc

* sndcopy: copy the sound engine's image (the start of bank BANKSND, from the data file) up to $FC00,
* and the low code (offset $0300) down to $0000
sndcopy lda     #BANKSND
        sta     MMUT0+6
        ldx     #BANKWIN
        ldu     #$FC00
@copy   ldd     ,x++
        std     ,u++
        cmpu    #sndres_end
        blo     @copy
        ldx     #BANKWIN+$300   ; and the low code down to $0000 (low.asm)
        ldu     #0
@low    ldd     ,x++
        std     ,u++
        cmpu    #lowcend
        blo     @low
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* tunego: play the tune asked for (tunereq 1 lose, 2 win; the player is in the data bank, tune.asm)
tunego  lda     tunereq
        beq     @r
        clr     tunereq
        lbsr    sndoff          ; (the tune drives the DAC itself)
        lbsr    flashoff        ; (and the main loop, which ends a hurt flash, stops while it plays)
        ldb     #BANKDAT
        stb     MMUT0+6
        jsr     tuneplay
        ldb     #BANKCOM
        stb     MMUT0+6
        lbsr    kbflush         ; (keys held while it played aren't commands)
@r      rts
tunereq fcb     0
pbddr   fcb     0               ; PIA 1 port B direction as BASIC left it (for checking)

* title: the static title screen; the command line takes a seed
title   clr     gmode
        clr     vmode
        clr     pending
        clr     paused
        clr     ilen
        lbsr    clearboth
        lbsr    logclear
        clra                    ; the title text, on both pages
        bsr     @page
        lda     #1
        bsr     @page
        lda     #1
        sta     statdirty
        sta     cmddirty
        rts
@page   lbsr    mappage
        lda     #TXGREEN
        sta     textmask
        ldd     #(8<<8)|13
        ldy     #s_title
        lbsr    printat
        lda     #TXBLUE         ; the credits and the version (Steve)
        sta     textmask
        lda     #11
        ldy     #s_credit
        lbsr    center
        lda     #13
        ldy     #s_version
        lbra    center

* newgame: start a game in the maze for seed
newgame lda     #1
        sta     gmode
        clr     pending
        clr     paused
        clr     ilen
        clr     vmode
        lbsr    clearboth
        lbsr    logclear
        lbsr    seenclear
        clr     lvlon
        ldx     #lvlvis         ; no level visited yet
        ldb     #5
@nv     clr     ,x+
        decb
        bne     @nv
        lbsr    newplayer       ; first: it sets the play clock to 0, and entering the level sets every
        lda     #1              ; monster's next turn to the clock (after it, an old game's clock left
        clrb                    ; them all waiting that long: Steve, after SEED)
        lbsr    enterlevel
        lda     #K_DAGGER       ; a dagger at your feet, as the reference's newGame
        sta     ikind
        lda     #1
        tfr     a,b
        lbsr    additem
        ldd     ticks
        std     lastt
        lda     #1
        sta     statdirty
        ldy     #m_descend
        lbsr    msg
        ldy     #m_below
        lbsr    msg
        ldy     #m_try
        lbsr    msg
        lbsr    mbstart
        ldx     #m_mazeseed
        lbsr    mbstr
        ldd     seed
        std     num32
        ldd     seed+2
        std     num32+2
        lbsr    mbnum32
        lbsr    mbsend
        lbsr    testmsg         ; seed 0: the test maze's message
        lda     #1
        sta     cmddirty
        rts

* clearboth: clear both screen pages
clearboth
        lda     #1
        lbsr    mappage
        lbsr    clrscr
        clra
        lbsr    mappage
        lbsr    clrscr
        clr     front
        rts

* enterlevel: A = level, B = 0 to arrive at the start (1,1), 1 at the down ladder (climbing up).
* Builds the level and faces the first open direction (N, E, S, W), as the reference's enterLevel.
* (The maze comes out the same every time from the seed; items and monsters will need keeping.)
enterlevel
        stb     elmode
        tst     lvlon           ; keep what you've seen, and the items, on the level you're leaving
        beq     @first
        pshs    a
        lda     #SFX_DESCEND    ; (changing level)
        lbsr    sfxa
        lbsr    seensave
        lbsr    itemsave
        lbsr    monsave
        puls    a
@first  lbsr    mklevel         ; (its maze is the same every time; its items are placed afresh)
        lbsr    seenload
        lbsr    deepck          ; (the end screen's deepest depth)
        ldx     #lvlvis         ; been here before? then its items are as you left them
        ldb     mz_lvl
        decb
        tst     b,x
        beq     @fresh
        lbsr    itemload
        lbsr    monload
        bra     @vis
@fresh  lda     #1
        sta     b,x
@vis
        lda     #1
        sta     lvlon
        tst     vmode           ; changing level closes a map (the reference's enterLevel)
        beq     @start
        clr     vmode
        sta     logdirty
@start
        lda     #1
        sta     px
        sta     py
        tst     elmode
        beq     @face
        lda     farx
        sta     px
        lda     fary
        sta     py
@face   clr     pdir
@try    ldb     pdir
        ldx     #dx1
        lda     b,x
        adda    px
        ldx     #dy1
        ldb     b,x
        addb    py
        lbsr    iswall
        beq     @ok
        inc     pdir
        lda     pdir
        cmpa    #4
        blo     @try
        clr     pdir
@ok     lbsr    pbfs            ; steps from you, for the monsters
        lbsr    monwake         ; and they may all act at once
        lda     #1
        sta     vdirty
        sta     statdirty
        rts

* doact: A = action, for the timing walk: U forward, D back, L/R turn
doact   cmpa    #'U
        bne     @notu
        ldb     pdir
        clra
        lbra    step
@notu   cmpa    #'D
        bne     @notd
        ldb     pdir
        addb    #2
        andb    #3
        lda     #1
        lbra    step
@notd   cmpa    #'L
        bne     @notl
        lda     pdir
        adda    #3
        anda    #3
        ldb     #-1
        lbra    turn
@notl   lda     pdir
        inca
        anda    #3
        ldb     #1
        lbra    turn

* turn: A = new direction, B = 1 turning right or -1 left. Draws the halfway pan frame; the
* caller's normal frame then shows the full turn.
turn    sta     tdir1
        tst     vmode           ; on a map: no pan, just turn
        bne     @set
        stb     vturn
        lbsr    drawframe
        lda     tdir1
@set
        sta     pdir
        clr     vturn
        rts

* step: B = direction, A = 0 glide forward, 1 glide back, 2 step sideways (instant, as the
* reference). Returns A = 0 if you moved, 1 if a wall is in the way. A glide draws two in-between
* frames (1/3 and 2/3 of the way); the caller's normal frame then shows the new spot. Forward glides
* are drawn from the old spot with the scenery pulled closer; backward ones from the new spot with
* the scenery starting closer and receding (as the reference's renderView does).
step    sta     stmode
        lda     #SFX_STEP
        lbsr    sfxa
        ldx     #dx1
        lda     b,x
        adda    px
        sta     tx
        ldx     #dy1
        lda     b,x
        adda    py
        sta     ty
        tfr     a,b
        lda     tx
        lbsr    iswall
        bne     @wall
        lda     stmode
        tst     vmode           ; on a map: no glide
        bne     @inst
        tsta
        beq     @fwd
        cmpa    #1
        beq     @back
@inst   bsr     @arrive         ; sideways (or on a map)
        clra
        rts
@fwd    lda     #1              ; forward: from here, 1/3 then 2/3 of the way
        sta     vshift
        lbsr    drawframe
        lda     #2
        sta     vshift
        lbsr    drawframe
        bsr     @arrive
        bra     @end
@back   bsr     @arrive         ; back: from the new spot, 2/3 then 1/3 of a cell short
        lda     #2
        sta     vshift
        lbsr    drawframe
        lda     #1
        sta     vshift
        lbsr    drawframe
@end    clr     vshift
        clra
        rts
@wall   lda     #1
        rts
@arrive lda     tx
        sta     px
        lda     ty
        sta     py
        rts

        ifdef   AUTOWALK
* autoact: left-hand rule. Turn left and step if the left is open, else step forward, else turn right.
autoact tst     mustfwd
        beq     @look
        clr     mustfwd
        lda     #'U
        rts
@look   ldb     pdir            ; left open?
        addb    #3
        andb    #3
        bsr     @open
        bne     @fwd
        inc     mustfwd
        lda     #'L
        rts
@fwd    ldb     pdir
        bsr     @open
        bne     @right
        lda     #'U
        rts
@right  lda     #'R
        rts
@open   ldx     #dx1            ; B = direction: is that neighbour a wall? (NE = wall)
        lda     b,x
        adda    px
        pshs    a
        ldx     #dy1
        lda     b,x
        adda    py
        tfr     a,b
        puls    a
        lbra    iswall
        endc

* drawframe: draw the view and status on the hidden page, then show it.
drawframe
        lda     front
        eora    #1
        sta     back
        lbsr    mappage
        ldd     ticks
        std     t0
        lda     vshift          ; not mid-glide or mid-turn: note what you can see
        ora     vturn
        bne     @nomark
        lbsr    markseen
@nomark lda     vmode           ; the corridor, a map, the pack view or the help
        beq     @view
        cmpa    #3
        beq     @pack
        cmpa    #4
        beq     @help
        lbsr    mapdraw
        bra     @drawn
@pack   lbsr    packview
        bra     @drawn
@help   lbsr    helpdraw
        bra     @drawn
@view   tst     fainted         ; blacked out: nothing to see
        beq     @see
        lbsr    clrview
        bra     @drawn
@see    lbsr    render
        lbsr    fxdraw          ; an attack picture over it
        tst     vlight          ; no light: the reference's "IT IS DARK" at the top of the view
        bne     @drawn
        lda     #TXGREEN
        sta     textmask
        lda     #1
        ldy     #m_dark
        lbsr    center
@drawn  ldd     ticks
        subd    t0
        std     lastdraw
        lbsr    endpanel        ; the game over: its panel over the view
        lda     pending         ; a Y/N question, or PAUSED, goes over the middle of the view
        ora     paused
        beq     @noq
        lbsr    overlay
@noq
        ldd     ticks           ; flip in the vertical border, so the switch is clean and
@vs     cmpd    ticks           ; the old page is off screen before we draw on it again
        beq     @vs
        lda     back
        lbsr    showpage
        sta     front
        ldd     frames
        addd    #1
        std     frames
        ldd     totdraw
        addd    lastdraw
        std     totdraw
        ldd     lastdraw
        cmpd    maxdraw
        bls     framedone
        std     maxdraw
framedone                       ; screenshot point after each frame (use with -trap-range)
        rts

* mappage: A = page (0/1). Maps it at CPU $4000-$BFFF for drawing. Preserves A.
mappage pshs    a
        ldb     #PAGE0BLK
        tsta
        beq     @p
        ldb     #PAGE1BLK
@p      stb     MMUT0+2
        incb
        stb     MMUT0+3
        incb
        stb     MMUT0+4
        incb
        stb     MMUT0+5
        puls    a,pc

* showpage: A = page (0/1). Displays it. Preserves A.
showpage
        pshs    a
        ldx     #(PAGE0BLK*$2000)/8
        tsta
        beq     @p
        ldx     #(PAGE1BLK*$2000)/8
@p      stx     VOFFHI
        stx     voffsh
        puls    a,pc

* irqinit: count frames in ticks with the GIME's vertical border interrupt
irqinit lda     #$7E            ; JMP irqh at the CoCo 3's IRQ vector
        sta     $FEF7
        ldx     #irqh
        stx     $FEF8
        lda     $FF01           ; PIA interrupts off (BASIC's 60 Hz one included)
        anda    #$FE
        sta     $FF01
        lda     $FF03
        anda    #$FE
        sta     $FF03
        lda     $FF21
        anda    #$FE
        sta     $FF21
        lda     $FF23
        anda    #$FE
        sta     $FF23
        anda    #$FB            ; the single-bit sound line (PIA 1 PB1): an output, held low. BASIC
        sta     $FF23           ; leaves it an input, floating, which can add noise to the sound
        lda     $FF22           ; (read the data direction register, set bit 1, back to data)
        sta     pbddr
        ora     #$02
        sta     $FF22
        lda     $FF23
        ora     #$04
        sta     $FF23
        lda     $FF22
        anda    #$FD
        sta     $FF22
        lda     PIA0A           ; clear any pending PIA flags
        lda     PIA0B
        lda     #$6C            ; as before, plus GIME IRQs on
        sta     INIT0
        lda     #$08            ; vertical border
        sta     IRQENR
        lda     IRQENR
        lbsr    kbscan          ; note what's held now (the R or C, say), then forget it
        lbsr    kbflush
        lbsr    sndinit         ; the sound engine: its state, FIRQ vector, timer clock, sound on
        lda     #$7C            ; GIME IRQ and FIRQ on
        sta     INIT0
        andcc   #$AF            ; IRQ and FIRQ
        rts

irqh    lda     IRQENR          ; acknowledge
        ldx     ticks
        leax    1,x
        stx     ticks
        lda     <flashcnt       ; a hurt flash's last tick: the black back (fxflash)
        beq     @k
        dec     <flashcnt
        bne     @k
        lda     palsh
        sta     PALETTE
@k      lbsr    hbtick          ; the heartbeat's sound, on time (sound.asm)
        lbsr    kbscan          ; the keyboard
        rti

* printat: A = row, B = column, Y = string
printat lbsr    textpos
        lbra    puts

* setpal: X = 4 palette bytes. Copies them to palsh and the GIME.
setpal  pshs    d,x,y,u
        ldu     #palsh
        ldy     #PALETTE
        ldb     #4
@next   lda     ,x+
        sta     ,u+
        sta     ,y+
        decb
        bne     @next
        puls    d,x,y,u,pc

        include "text.asm"
        include "kbd.asm"
        include "draw.asm"
        include "view.asm"
        include "msg.asm"
        include "items.asm"
        include "sim.asm"
        include "dload.asm"
        ifdef   FONTTEST
        include "fonttest.asm"
        endc

* ---- data ----

* Palettes: 0 black, 1 green, 2 red, 3 light blue
rgbpal  fcb     $00,$12,$24,$0F
cmppal  fcb     $00,$12,$07,$1B
askpal  fcb     $00,$3F,$3F,$3F ; black and white: looks the same on either monitor

s_title fcn     "CRYPTS OF VAEL"
s_credit fcn    "BY STEVE NORTON AND CLAUDE AI"
s_version fcn   "VERSION 1.0.0" ; the game's version (semver: bump it only when Steve asks)
s_ask1  fcn     "PRESS R FOR RGB MONITOR"
s_ask2  fcn     "OR C FOR COMPOSITE"
s_nodata fcn    "VAELDATA.DAT IS MISSING FROM THE DISK"
secbuf  fill    0,256           ; a disk sector (start-up only)
ptbuf   fill    0,24*3          ; drawshp: one polyline's points on screen (x 2 bytes, y)

        ifdef   TESTCMDS
lightnext fcb   7,0,0,0,0,0,0,4 ; indexed by vlight: [0] none -> 7, [4] torch -> 0, [7] lantern -> 4
        endc
dirname fcn     "NORTH"         ; 6 bytes each
        fcn     "EAST"
        fcb     0
        fcn     "SOUTH"
        fcn     "WEST"
        fcb     0

* Variables. Shadow copies of display state: the GIME registers are write-only, so the
* screenshot tool (tools/snap2png.py) reads these to know what is on screen.
voffsh  fdb     0               ; value last written to VOFFHI/VOFFLO
palsh   fcb     0,0,0,0         ; palette last written to $FFB0-$FFB3
monitor fcb     0               ; 'R' or 'C'
textmask fcb    TXGREEN         ; colour for putc
putcrow fcb     0               ; putc's row counter
mtlvl   fcb     0               ; maze check build: current level
front   fcb     0               ; page on screen
back    fcb     0               ; page being drawn
ticks   fdb     0               ; 60 Hz frame counter (IRQ)
t0      fdb     0
lastdraw fdb    0               ; ticks the last view took to draw
frames  fdb     0               ; frames drawn
totdraw fdb     0               ; sum of lastdraw
maxdraw fdb     0               ; worst lastdraw
px      fcb     0               ; player position and facing (0 N, 1 E, 2 S, 3 W)
py      fcb     0
pdir    fcb     0
tx      fcb     0
ty      fcb     0
mustfwd fcb     0
stmode  fcb     0               ; step: 0 glide forward, 1 glide back, 2 sideways
elmode  fcb     0               ; enterlevel: 0 arrive at the start, 1 at the down ladder
lvlon   fcb     0               ; a level is in play (its seen cells need saving when you leave)
lvlvis  fcb     0,0,0,0,0       ; levels visited (their items are kept in BANKLVL)

* ---- Buffers: reserved, not stored in the .bin. Must end below $4000 (screen window). ----
progend
        ifgt    progend-$4000
        error   "fixed code and data run past $3FFF into the screen window"
        endc

* ---- High code ($E000-$FBFF, block $3F): loaded at $6000, copied up by start ----
        org     HIGHWIN
        include "rng.asm"
        include "maze.asm"
        include "cmd.asm"
        include "map.asm"
        include "attack.asm"
        include "help.asm"
highend
        ifgt    highend-$FC00
        error   "high code is past $FBFF (its load copy must end below $7C00)"
        endc

* ---- Low code ($0000-$00FF, block $38): carried by the data file at offset $0300 of BANKSND,
* copied down by sndcopy ----
        org     $0000
        include "low.asm"
lowcend
        ifgt    lowcend-$0100
        error   "low code is past $00FF"
        endc

* ---- The sound engine ($FC00-$FEED): carried by the data file, copied up by sndcopy ----
        include "sound.asm"
        ifgt    sndres_end-$FEEC
        error   "the sound engine is too big (sndcopy copies 2 bytes at a time, up to $FEED)"
        endc

* ---- The level generator, an overlay: carried by the data file (bank BANKSND from $0C00), mapped
* at $8000 only while mklevel runs (so it's assembled at $8C00) ----
OVLWIN  equ     $8C00
        org     OVLWIN
        include "mazegen.asm"
ovlend
        ifgt    ovlend-$A000
        error   "the level generator overlay is past $9FFF"
        endc

* ---- Common bank (block BANKCOM at $C000-$DFFF): font and tables ----
        org     BANKWIN
        include "font.asm"
        include "tables.asm"
        include "strings.asm"
        include "crylv.asm"
        include "status.asm"
        ifdef   TESTCMDS
        include "testbank.asm"  ; (test builds: help for the test commands)
        endc
bankcomend
        ifgt    bankcomend-(BANKWIN+$2000)
        error   "common bank is over 8K"
        endc

* ---- Scratch bank (block BANKSCR at $C000-$DFFF while mklevel runs): not loaded ----
dist    equ     BANKWIN         ; distances from the start, -1 = unreached (2*31*31)
queue   equ     dist+2*31*31    ; BFS queue of cell indices (2*31*31)
cstack  equ     queue+2*31*31   ; carve's (x, y) stack (2*256)
used    equ     cstack+2*256    ; item placement: cells already taken (31*31)
dist2   equ     used+31*31      ; showcase: the distances from the start, kept (2*31*31)

        end     start
