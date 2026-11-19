* Maze generation: a port of the web version's makeLevel / carve / bfs, using the same RNG calls
* in the same order, so a seed gives the same maze as the web game.
*
*   mklevel  A = level (1-5). Builds grid (1 = wall, 0 = open), mz_s = size S, far/farx/fary/fardist
*            = the farthest cell (the down ladder on levels 1-4). The work buffers (dist, queue,
*            cstack) are in the scratch bank, mapped in only while this runs.
*
* Grid cell (x, y) is grid + y*S + x. Directions: 0 north, 1 east, 2 south, 3 west.

mklevel ldb     #BANKSCR
        stb     MMUT0+6
        bsr     @build
        ldb     #BANKCOM
        stb     MMUT0+6
        rts
@build  sta     mz_lvl
        lsla
        adda    #21
        sta     mz_s            ; S = 21 + 2n
        deca
        sta     mz_s1           ; S - 1
        ldb     mz_s
        clra
        std     mz_s16
        lda     mz_s
        ldb     mz_s
        mul
        std     mz_n            ; S * S
* RNG seed for this level: seed ^ imul(n, 0x9E3779B1)
        ldd     #0
        std     m_x
        ldb     mz_lvl
        std     m_x+2
        ldd     #$9E37
        std     m_y
        ldd     #$79B1
        std     m_y+2
        lbsr    imul32
        ldd     seed
        eora    m_res
        eorb    m_res+1
        std     rngst
        ldd     seed+2
        eora    m_res+2
        eorb    m_res+3
        std     rngst+2
        lbsr    carve
        lbsr    openup
        ldd     mz_s16
        addd    #1              ; start cell (1,1)
        lbsr    bfs
        lbra    findfar

* cellad: A = x, B = y. Returns X = address of that grid cell. Uses D.
cellad  pshs    a
        lda     mz_s
        mul                     ; D = y * S
        addb    ,s+
        adca    #0
        ldx     #grid
        leax    d,x
        rts

* carve: depth-first maze over the odd cells, as the JS carve(S) does
carve   ldx     #grid           ; every cell starts as wall
        ldy     mz_n
        lda     #1
@fill   sta     ,x+
        leay    -1,y
        bne     @fill
        ldu     #cstack         ; stack of (x, y) byte pairs, growing upward
        ldd     #$0101
        std     ,u++
        lbsr    cellad
        clr     ,x
@loop   cmpu    #cstack
        lbeq    @end
        ldd     -2,u            ; top of stack
        std     cx              ; cx, cy
        clr     nopts
        clr     cd
@dir    ldb     cd              ; candidate two cells away in direction cd
        ldx     #dx2
        lda     b,x
        adda    cx
        sta     nx
        ldx     #dy2
        lda     b,x
        adda    cy
        sta     ny
        lda     nx              ; 0 < nx < S-1 (unsigned compare also rejects -1)
        beq     @nxt
        cmpa    mz_s1
        bhs     @nxt
        ldb     ny
        beq     @nxt
        cmpb    mz_s1
        bhs     @nxt
        lbsr    cellad
        tst     ,x              ; still wall = not visited
        beq     @nxt
        ldx     #opts
        ldb     nopts
        lda     cd
        sta     b,x
        inc     nopts
@nxt    inc     cd
        lda     cd
        cmpa    #4
        blo     @dir
        ldb     nopts
        bne     @pick
        leau    -2,u            ; dead end: pop
        bra     @loop
@pick   clra                    ; d = pick(opts)
        pshs    u
        lbsr    rndn
        puls    u
        ldx     #opts
        lda     b,x
        sta     cd
        ldb     cd              ; open the wall between
        ldx     #dx1
        lda     b,x
        adda    cx
        pshs    a
        ldx     #dy1
        lda     b,x
        adda    cy
        tfr     a,b
        puls    a
        lbsr    cellad
        clr     ,x
        ldb     cd              ; open the new cell and push it
        ldx     #dx2
        lda     b,x
        adda    cx
        sta     nx
        ldx     #dy2
        lda     b,x
        adda    cy
        sta     ny
        tfr     a,b
        lda     nx
        lbsr    cellad
        clr     ,x
        lda     nx
        ldb     ny
        std     ,u++
        lbra    @loop
@end    rts

* openup: knock out floor(S*S*0.06) random wall cells that sit between two open cells in a
* straight line, making loops (the second half of the JS carve)
openup  ldx     #opencnt-1
        ldb     mz_lvl
        lda     b,x
        sta     opn
@loop   lda     opn             ; while (n-- > 0)
        beq     @end
        dec     opn
        ldb     mz_s            ; x = rnd(1, S-2)
        subb    #2
        clra
        lbsr    rndn
        incb
        stb     nx
        ldb     mz_s            ; y = rnd(1, S-2)
        subb    #2
        clra
        lbsr    rndn
        incb
        stb     ny
        lda     nx
        lbsr    cellad
        tst     ,x
        beq     @loop           ; already open
        lda     -1,x            ; h: west and east open, north and south wall
        ora     1,x
        bne     @tryv
        ldb     mz_s
        lda     b,x
        negb
        anda    b,x
        bne     @open
        bra     @loop
@tryv   lda     -1,x            ; v: north and south open, west and east wall
        anda    1,x
        beq     @loop
        ldb     mz_s
        lda     b,x
        negb
        ora     b,x
        bne     @loop
@open   clr     ,x
        bra     @loop
@end    rts

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

* findfar: far = first cell with the greatest distance; farx, fary its position
findfar ldx     #dist
        ldd     ,x
        std     fardist
        ldd     #0
        std     far
        ldy     #0
@loop   ldd     ,x++
        cmpd    fardist
        ble     @next
        std     fardist
        sty     far
@next   leay    1,y
        cmpy    mz_n
        blo     @loop
        ldd     far             ; divide by S
        clr     fary
@div    cmpd    mz_s16
        blo     @done
        subd    mz_s16
        inc     fary
        bra     @div
@done   stb     farx
        rts

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
