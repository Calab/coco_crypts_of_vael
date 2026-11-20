* Maze generation: a port of the web version's makeLevel / carve / bfs, using the same RNG calls
* in the same order, so a seed gives the same maze as the web game.
*
*   mklevel  A = level (1-5). Builds grid (1 = wall, 0 = open), mz_s = size S, far/farx/fary/fardist
*            = the farthest cell (the down ladder on levels 1-4). The work buffers (dist, queue,
*            cstack) are in the scratch bank, mapped in only while this runs.
*
* Grid cell (x, y) is grid + y*S + x. Directions: 0 north, 1 east, 2 south, 3 west.

mklevel ldb     MMUT0+4         ; the generator (mazegen.asm, in BANKSND) at $8000, the work buffers
        pshs    b               ; (scratch bank) at $C000
        ldb     #BANKSND
        stb     MMUT0+4
        ldb     #BANKSCR
        stb     MMUT0+6
        jsr     mkbuild
        ldb     #BANKCOM
        stb     MMUT0+6
        puls    b
        stb     MMUT0+4
        rts

* cellad: A = x, B = y. Returns X = address of that grid cell. Uses D.
cellad  pshs    a
        lda     mz_s
        mul                     ; D = y * S
        addb    ,s+
        adca    #0
        ldx     #grid
        leax    d,x
        rts

* bfs: D = start cell index. Fills dist (16-bit per cell, -1 = unreached) with steps from there.
bfs     std     bcur
        ldx     #dist
        ldy     mz_n
        ldd     #$FFFF
@init   std     ,x++
        leay    -1,y
        bne     @init
        ldd     bcur
        lslb
        rola
        ldx     #dist
        leax    d,x
        ldd     #0
        std     ,x
        ldx     #queue
        ldd     bcur
        std     ,x++
        stx     qtail
        ldd     #queue
        std     qhead
@loop   ldx     qhead
        cmpx    qtail
        beq     @end
        ldd     ,x++
        stx     qhead
        std     bcur
        lslb
        rola
        ldx     #dist
        ldd     d,x
        addd    #1
        std     bnd             ; distance for unvisited neighbours
        ldd     bcur            ; north, east, south, west
        subd    mz_s16
        bsr     @try
        ldd     bcur
        addd    #1
        bsr     @try
        ldd     bcur
        addd    mz_s16
        bsr     @try
        ldd     bcur
        subd    #1
        bsr     @try
        bra     @loop
@try    ldx     #grid           ; D = neighbour index
        tst     d,x
        bne     @ret            ; wall
        std     bj
        lslb
        rola
        ldx     #dist
        leax    d,x
        tst     ,x
        bpl     @ret            ; already reached
        ldd     bnd
        std     ,x
        ldx     qtail
        ldd     bj
        std     ,x++
        stx     qtail
@ret    rts
@end    rts

* addmon: A = x, B = y, mkind = kind, mflags = flags. Health is the kind's scaled for the level.
addmon  pshs    d
        lda     nmons
        cmpa    #MAXMONS
        bhs     @full
        ldb     #MONREC
        mul
        addd    #mons
        tfr     d,x
        puls    d
        std     ,x              ; x, y
        lda     mkind
        sta     2,x
        ldb     mz_lvl          ; hp = round(MON hp * (1 + (n-1) * 0.28)), from a table
        decb
        lda     #7*2
        mul
        addd    #mhp
        tfr     d,u
        ldb     mkind
        lslb
        ldd     b,u
        std     3,x             ; hp
        std     5,x             ; most hp
        lda     #$FF            ; carries nothing (yet)
        sta     7,x
        lda     mflags
        sta     8,x
        clr     9,x             ; (simulation state, later)
        clr     10,x
        clr     11,x
        clr     12,x
        clr     13,x
        inc     nmons
        rts
@full   puls    d,pc

* Monster kinds (the reference's MON order, weakest first)
M_MOULD    equ  0
M_CRAWLER  equ  1
M_SKELETON equ  2
M_HOUND    equ  3
M_WRAITH   equ  4
M_GOLEM    equ  5
M_KING     equ  6
MF_DORMANT equ  1               ; asleep until struck (seed 0's showcase)
MAXMONS    equ  20              ; per level
MONREC     equ  14              ; x, y, kind, hp (2), most hp (2), carry, flags, 5 for the simulation

* Health by level (rows) and kind: round(MON hp * (1 + (n-1) * 0.28))
mhp     fdb     8,16,24,42,38,80,210
        fdb     10,20,31,54,49,102,269
        fdb     12,25,37,66,59,125,328
        fdb     15,29,44,77,70,147,386
        fdb     17,34,51,89,81,170,445

* additem: A = x, B = y, ikind = kind. Adds it to the level's items (lights start with full time).
additem pshs    d
        lda     nitems
        cmpa    #MAXITEMS
        bhs     @full
        ldb     #ITEMREC
        mul
        addd    #items
        tfr     d,x
        puls    d
        std     ,x
        lda     ikind
        sta     2,x
        ldu     #0
        ldb     ikind
        cmpb    #K_TORCH
        bne     @lant
        ldu     #200            ; seconds of light (the reference's dur)
@lant   cmpb    #K_LANTERN
        bne     @t
        ldu     #420
@t      stu     3,x
        inc     nitems
        rts
@full   puls    d,pc

* cellidx: A = x, B = y. D = y * S + x.
cellidx pshs    a
        lda     mz_s
        mul
        addb    ,s+
        adca    #0
        rts

* Item kinds (the reference's ITEMS order)
K_DAGGER  equ   0
K_AXE     equ   1
K_SWORD   equ   2
K_HAMMER  equ   3
K_RUNE    equ   4
K_BUCKLER equ   5
K_TOWER   equ   6
K_TORCH   equ   7
K_LANTERN equ   8
K_MENDING equ   9
K_HERB    equ   10
K_VIGOR   equ   11
K_MAP     equ   12
K_RELIC   equ   13
K_CROWN   equ   14
MAXITEMS  equ   48              ; per level
ITEMREC   equ   5               ; x, y, kind, light time left (2)

dx1     fcb     0,1,0,-1
dy1     fcb     -1,0,1,0
dx2     fcb     0,2,0,-2
dy2     fcb     -2,0,2,0
opencnt fcb     31,37,43,50,57  ; floor(S*S*0.06) for S = 23, 25, 27, 29, 31

* Maze variables
        ifdef   SEEDVAL
seed    fqb     SEEDVAL
        else
seed    fqb     12345
        endc
mz_lvl  fcb     0
mz_s    fcb     0
mz_s1   fcb     0
mz_s16  fdb     0
mz_n    fdb     0
far     fdb     0
farx    fcb     0
fary    fcb     0
fardist fdb     0
cx      fcb     0               ; cx, cy must stay together (stored as a pair)
cy      fcb     0
nx      fcb     0
ny      fcb     0
cd      fcb     0
nopts   fcb     0
opts    fcb     0,0,0,0
opn     fcb     0
bcur    fdb     0
bnd     fdb     0
bj      fdb     0
qhead   fdb     0
qtail   fdb     0

* Item placement variables, and the current level's items
pip     fdb     0
pcnt    fcb     0
pxy     fdb     0
ikind   fcb     0
mkind   fcb     0
mflags  fcb     0
fmin    fcb     0
ftry    fdb     0
fi      fdb     0
fy      fcb     0
scx     fcb     0
scy     fcb     0
snx     fcb     0
sstep   fcb     0
sd      fcb     0
sidx    fdb     0
stf     fdb     0
showc   fill    $FF,14          ; seed 0's showcase cells (x, y) for the 7 monsters; $FF = none
