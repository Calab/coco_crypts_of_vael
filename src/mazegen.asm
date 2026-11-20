* Level generation (the overlay): the reference's makeLevel / buildLevel minus the parts the game
* also uses during play (cellidx, cellad, bfs, addmon, additem, in maze.asm). Assembled at OVLWIN
* ($8C00) and run with bank BANKSND mapped at $8000-$9FFF (the screen page's third quarter, borrowed
* while a level is built: nothing draws then); maze.asm's mklevel maps it in. tools/relocate.py
* takes it out of the .bin and the data file carries it (tools/joindata.py).

* mkbuild: A = level (1-5). See mklevel.
mkbuild sta     mz_lvl
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
        lbsr    findfar
        lbsr    placeitems
        lbra    placemons

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

* ---- items: the reference's buildLevel after the far cell ----
* placeitems: used = {start, far}; on seed 0's level 1 the showcase cells; then the level's own items
* (each at least 3 steps from the start: free(3)) and 4 + n fillers (free(2), then pick(FILLER)).
* Fills items/nitems (x, y, kind, light time left (2)).
placeitems
        clr     nitems
        ldx     #used           ; nothing used yet
        ldy     mz_n
@clr    clr     ,x+
        leay    -1,y
        bne     @clr
        lda     #1
        ldx     #used           ; the start and the far cell
        ldd     mz_s16
        addd    #1
        leax    d,x
        lda     #1
        sta     ,x
        ldx     #used
        ldd     far
        leax    d,x
        lda     #1
        sta     ,x
        ldx     #showc          ; no showcase monsters
        ldb     #14
        lda     #$FF
@shc    sta     ,x+
        decb
        bne     @shc
        lda     mz_lvl          ; seed 0, level 1: the showcase
        cmpa    #1
        bne     @own
        ldd     seed
        bne     @own
        ldd     seed+2
        bne     @own
        lbsr    showcase
@own    ldb     mz_lvl          ; the level's own items
        decb
        lslb
        ldx     #lvitems
        ldx     b,x
        stx     pip
@next   ldx     pip
        lda     ,x+
        stx     pip
        cmpa    #$FF
        beq     @fill
        sta     ikind
        lda     #3
        lbsr    ifree
        bcs     @next
        lbsr    additem
        bra     @next
@fill   lda     mz_lvl          ; 4 + n fillers
        adda    #4
        sta     pcnt
@fl     lda     #2
        lbsr    ifree
        bcs     @fnext
        std     pxy
        ldd     #10             ; pick(FILLER)
        lbsr    rndn
        ldx     #filler
        lda     b,x
        sta     ikind
        ldd     pxy
        lbsr    additem
@fnext  dec     pcnt
        bne     @fl
        rts

* ---- monsters: the rest of the reference's buildLevel ----
* placemons: the level's monsters in its LEVELS order, each free(8); level 5's king on the far cell;
* seed 0's showcase monsters (asleep); then every monster but the king carries loot if RNG() < 0.35.
placemons
        clr     nmons
        ldb     mz_lvl
        decb
        lslb
        ldx     #lvmons
        ldx     b,x
        stx     pip
@group  ldx     pip             ; (kind, how many) pairs, $FF ends
        lda     ,x+
        cmpa    #$FF
        beq     @boss
        sta     mkind
        lda     ,x+
        sta     pcnt
        stx     pip
@one    lda     #8
        lbsr    ifree
        bcs     @nofree
        clr     mflags
        lbsr    addmon
@nofree dec     pcnt
        bne     @one
        bra     @group
@boss   lda     mz_lvl          ; the Hollow King waits on level 5's far cell
        cmpa    #5
        bne     @show
        lda     #M_KING
        sta     mkind
        clr     mflags
        lda     farx
        ldb     fary
        lbsr    addmon
@show   clr     mkind           ; seed 0's showcase: one of each kind, asleep, in order
        ldx     #showc
@sc     lda     ,x
        cmpa    #$FF
        beq     @scn
        ldb     1,x
        pshs    x
        lda     #MF_DORMANT
        sta     mflags
        lda     ,x
        lbsr    addmon
        puls    x
@scn    leax    2,x
        inc     mkind
        lda     mkind
        cmpa    #7
        blo     @sc
        lda     nmons           ; loot: RNG() < 0.35 means the 32-bit value is below $5999999A
        beq     @done
        sta     pcnt
        ldx     #mons
@loot   stx     pip
        lda     2,x
        cmpa    #M_KING
        beq     @nl
        lbsr    rng32
        ldd     rngout
        cmpd    #$5999
        blo     @carry
        bhi     @nl
        ldd     rngout+2
        cmpd    #$999A
        bhs     @nl
@carry  ldd     #11             ; pick(LOOT)
        lbsr    rndn
        ldx     #loot
        lda     b,x
        ldx     pip
        sta     7,x
@nl     ldx     pip
        leax    MONREC,x
        dec     pcnt
        bne     @loot
@done   rts

* LEVELS[n].mons as (kind, count) pairs, in the reference's key order
lvmons  fdb     lvm1,lvm2,lvm3,lvm4,lvm5
lvm1    fcb     M_MOULD,4,M_CRAWLER,4,M_SKELETON,2,$FF
lvm2    fcb     M_MOULD,2,M_CRAWLER,3,M_SKELETON,3,M_HOUND,2,$FF
lvm3    fcb     M_SKELETON,3,M_HOUND,3,M_WRAITH,2,$FF
lvm4    fcb     M_HOUND,2,M_WRAITH,3,M_GOLEM,2,$FF
lvm5    fcb     M_WRAITH,2,M_GOLEM,3,$FF
loot    fcb     K_HERB,K_HERB,K_MENDING,K_MENDING,K_TORCH,K_LANTERN,K_VIGOR,K_DAGGER,K_AXE,K_SWORD,K_BUCKLER

* ifree: A = minimum distance from the start. The reference's free(minD): up to 5000 random cells,
* the first open one that far away and not used yet. Returns A = x, B = y and C clear, or C set.
ifree   sta     fmin
        ldd     #5000
        std     ftry
@try    ldd     mz_n
        lbsr    rndn            ; rnd(0, S*S - 1)
        std     fi
        lslb
        rola
        addd    #dist
        tfr     d,x
        ldd     ,x
        bmi     @no             ; a wall, or out of reach
        tsta
        bne     @far
        cmpb    fmin
        blo     @no
@far    ldd     fi
        addd    #used
        tfr     d,x
        tst     ,x
        bne     @no
        inc     ,x
        ldd     fi              ; x, y = i % S, i / S
        clr     fy
@div    cmpd    mz_s16
        blo     @dd
        subd    mz_s16
        inc     fy
        bra     @div
@dd     tfr     b,a
        ldb     fy
        andcc   #$FE
        rts
@no     ldd     ftry
        subd    #1
        std     ftry
        bne     @try
        orcc    #1
        rts

* showcase: seed 0's level 1 lines one sleeping monster of each kind along the path to the ladder,
* at path steps 3, 5, ... 15 (the reference's showcase). Needs the distances from the far cell, so
* dist is kept in dist2 meanwhile.
showcase
        ldx     #dist           ; keep the distances from the start
        ldu     #dist2
        ldy     mz_n
@save   ldd     ,x++
        std     ,u++
        leay    -1,y
        bne     @save
        ldd     far
        lbsr    bfs             ; dist = steps to the far cell
        lda     #1
        sta     scx
        sta     scy
        clr     sstep
@walk   lda     scx             ; tf = steps left from here; stop at the far cell
        ldb     scy
        lbsr    cellidx
        std     sidx
        lslb
        rola
        addd    #dist
        tfr     d,x
        ldd     ,x
        lble    @done
        subd    #1
        std     stf             ; the next cell on the path has tf - 1
        lda     sstep           ; steps 3, 5, ... 15: a showcase cell
        cmpa    #3
        blo     @step
        cmpa    #15
        bhi     @step
        bita    #1
        beq     @step
        suba    #3              ; slot (step - 3) / 2, 2 bytes each: (step - 3)
        ldx     #showc
        ldb     scx
        stb     a,x
        inca
        ldb     scy
        stb     a,x
        ldd     sidx
        addd    #used
        tfr     d,x
        lda     #1
        sta     ,x
@step   inc     sstep
        clr     sd
@dir    ldb     sd              ; the first direction (N, E, S, W) that goes one step closer
        ldx     #dx1
        lda     scx
        adda    b,x
        sta     snx
        ldx     #dy1
        lda     scy
        adda    b,x
        tfr     a,b
        lda     snx
        lbsr    cellidx
        lslb
        rola
        addd    #dist
        tfr     d,x
        ldd     ,x
        cmpd    stf
        beq     @go
        inc     sd
        lda     sd
        cmpa    #4
        blo     @dir
        bra     @done           ; (can't happen on a real path)
@go     ldb     sd
        ldx     #dx1
        lda     scx
        adda    b,x
        sta     scx
        ldx     #dy1
        lda     scy
        adda    b,x
        sta     scy
        lbra    @walk
@done   ldx     #dist2          ; put back the distances from the start
        ldu     #dist
        ldy     mz_n
@back   ldd     ,x++
        std     ,u++
        leay    -1,y
        bne     @back
        rts

* LEVELS[n].items and FILLER, as kind numbers
lvitems fdb     lvi1,lvi2,lvi3,lvi4,lvi5
lvi1    fcb     K_AXE,K_BUCKLER,K_TORCH,K_TORCH,K_MENDING,K_RELIC,$FF
lvi2    fcb     K_SWORD,K_TORCH,K_LANTERN,K_MENDING,K_VIGOR,K_RELIC,$FF
lvi3    fcb     K_HAMMER,K_TOWER,K_LANTERN,K_MENDING,K_MENDING,K_RELIC,$FF
lvi4    fcb     K_RUNE,K_LANTERN,K_MENDING,K_VIGOR,K_RELIC,$FF
lvi5    fcb     K_LANTERN,K_MENDING,K_MENDING,K_RELIC,$FF
filler  fcb     K_HERB,K_HERB,K_HERB,K_TORCH,K_TORCH,K_MENDING,K_LANTERN,K_BUCKLER,K_AXE,K_DAGGER

