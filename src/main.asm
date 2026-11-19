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

* Two screen pages: draw on the hidden one, then show it.
PAGE0BLK equ    SCR0BLK         ; physical blocks $30-$33
PAGE1BLK equ    SCR0BLK+4       ; physical blocks $34-$37

* Memory map (CPU address: what's there, physical block):
*   $0000-$0CFF  stack (below $0D00) and spare                        $38
*   $0D00-$0DFF  direct page variables                                $38
*   $0E00-$3FFF  fixed code and data (must end below $4000)           $38-$39
*   $4000-$BFFF  the screen page being drawn                          $30-$33 or $34-$37
*   $C000-$DFFF  bank window: BANKCOM normally, BANKSCR while a level is built
*   $E000-$FFFF  unchanged ($FExx vectors, $FFxx I/O)                 $3F
* The common bank is assembled at $C000 but stored in the .bin at $4000 (tools/relocate.py), where
* LOADM puts it in block $3A; start maps that block into the bank window.
BANKWIN equ     $C000
BANKCOM equ     $3A             ; common bank: font, tables (loaded with the program)
BANKSCR equ     $3C             ; scratch bank: maze-building buffers (not loaded)
        setdp   $0D

        org     $0E00

start   orcc    #$50            ; IRQ and FIRQ off: we own the machine from here
        lda     #BANKCOM        ; the common bank, loaded at $4000, into the bank window
        sta     MMUT0+6
        lds     #$0D00
        lda     #$0D
        tfr     a,dp
        sta     SPEEDHI         ; 1.79 MHz

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
* (level n's grid at SCRCPU+(n-1)*1024; S, farx, fary, fardist at SCRCPU+5120+(n-1)*8)
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
        lda     mtlvl
        inca
        cmpa    #6
        blo     @mt
mazedone bra    mazedone
        endc

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
        lbsr    title
mainloop
        lbsr    paintdirty      ; text rows that changed
        ldd     spin            ; (time spent waiting is the randomness for a blank seed)
        addd    #1
        std     spin
        lbsr    getkey
        beq     mainloop
        lbsr    editkey
        tst     vdirty
        beq     mainloop
        clr     vdirty
        tst     gmode
        beq     mainloop
        lbsr    paintdirty      ; messages first, then the view
        lbsr    drawframe
        bra     mainloop
        endc
        ifdef   AUTOKEYS
walkdone bra    walkdone        ; the scripted keys ran out
akeyp   fdb     akeys
akeys   include "autokeys.inc"  ; written by make: fcc "<KEYS>"  ('/' = ENTER)
        fcb     0
        endc

* title: the static title screen; the command line takes a seed
title   clr     gmode
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
        lbra    printat

* newgame: start a game in the maze for seed
newgame lda     #1
        sta     gmode
        clr     pending
        clr     paused
        clr     ilen
        lbsr    clearboth
        lbsr    logclear
        lda     #1
        clrb
        lbsr    enterlevel
        ldy     #m_descend
        lbsr    msg
        ldy     #m_below
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
        lbsr    mklevel
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
@ok     lda     #1
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

* jump (test command XJUMP): stand facing the down ladder, two cells away if the passage allows, else one.
jump    lda     mz_lvl
        cmpa    #5
        bhs     @none           ; no down ladder on the last level
        clr     tdir1
@dir    ldb     tdir1           ; one cell back from the ladder, against direction tdir1
        ldx     #dx1
        lda     farx
        suba    b,x
        sta     tx
        ldx     #dy1
        lda     fary
        suba    b,x
        sta     ty
        tfr     a,b
        lda     tx
        lbsr    iswall
        beq     @found
        inc     tdir1
        lda     tdir1
        cmpa    #4
        blo     @dir
@none   rts
@found  lda     tx              ; stand there, then try one more cell back
        sta     px
        lda     ty
        sta     py
        ldb     tdir1
        stb     pdir
        ldx     #dx1
        lda     tx
        suba    b,x
        sta     tx
        ldx     #dy1
        lda     ty
        suba    b,x
        sta     ty
        tfr     a,b
        lda     tx
        lbsr    iswall
        bne     @done
        lda     tx
        sta     px
        lda     ty
        sta     py
@done   rts

* turn: A = new direction, B = 1 turning right or -1 left. Draws the halfway pan frame; the
* caller's normal frame then shows the full turn.
turn    sta     tdir1
        stb     vturn
        lbsr    drawframe
        lda     tdir1
        sta     pdir
        clr     vturn
        rts

* step: B = direction, A = 0 glide forward, 1 glide back, 2 step sideways (instant, as the
* reference). Returns A = 0 if you moved, 1 if a wall is in the way. A glide draws two in-between
* frames (1/3 and 2/3 of the way); the caller's normal frame then shows the new spot. Forward glides
* are drawn from the old spot with the scenery pulled closer; backward ones from the new spot with
* the scenery starting closer and receding (as the reference's renderView does).
step    sta     stmode
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
        beq     @fwd
        cmpa    #1
        beq     @back
        bsr     @arrive         ; sideways
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
        lbsr    render
        ldd     ticks
        subd    t0
        std     lastdraw
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
        lda     PIA0A           ; clear any pending PIA flags
        lda     PIA0B
        lda     #$6C            ; as before, plus GIME IRQs on
        sta     INIT0
        lda     #$08            ; vertical border
        sta     IRQENR
        lda     IRQENR
        lbsr    kbscan          ; note what's held now (the R or C, say), then forget it
        lbsr    kbflush
        andcc   #$EF
        rts

irqh    lda     IRQENR          ; acknowledge
        ldx     ticks
        leax    1,x
        stx     ticks
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
        include "rng.asm"
        include "maze.asm"
        include "msg.asm"
        include "cmd.asm"
        ifdef   FONTTEST
        include "fonttest.asm"
        endc

* ---- data ----

* Palettes: 0 black, 1 green, 2 red, 3 light blue
rgbpal  fcb     $00,$12,$24,$0F
cmppal  fcb     $00,$12,$07,$1B
askpal  fcb     $00,$3F,$3F,$3F ; black and white: looks the same on either monitor

s_title fcn     "CRYPTS OF VAEL"
s_ask1  fcn     "PRESS R FOR RGB MONITOR"
s_ask2  fcn     "OR C FOR COMPOSITE"

lightnext fcb   7,0,0,0,0,0,0,4 ; indexed by vlight: [0] none -> 7, [4] torch -> 0, [7] lantern -> 4
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

* ---- Buffers: reserved, not stored in the .bin. Must end below $4000 (screen window). ----
grid    rmb     31*31           ; maze, 1 = wall
progend
        ifgt    progend-$4000
        error   "fixed code and data run past $3FFF into the screen window"
        endc

* ---- Common bank (block BANKCOM at $C000-$DFFF): font and tables ----
        org     BANKWIN
        include "font.asm"
        include "tables.asm"
        include "strings.asm"
bankcomend
        ifgt    bankcomend-(BANKWIN+$2000)
        error   "common bank is over 8K"
        endc

* ---- Scratch bank (block BANKSCR at $C000-$DFFF while mklevel runs): not loaded ----
dist    equ     BANKWIN         ; distances from the start, -1 = unreached (2*31*31)
queue   equ     dist+2*31*31    ; BFS queue of cell indices (2*31*31)
cstack  equ     queue+2*31*31   ; carve's (x, y) stack (2*256)

        end     start
