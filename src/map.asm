* Overhead maps (the reference's renderMap) and the cells you've seen (its markSeen).
*
*   vmode     0 the corridor, 1 YOUR MAP (only what you've seen; the DUNGEON MAP item),
*             2 FULL MAZE (REVEAL: everything, unseen walls dotted)
*   markseen  mark the cells you can see now
*   mapdraw   draw the map on the page being drawn: title on row 0, maze on rows 1-21, legend row 22
*   seensave / seenload / seenclear   each level's seen cells live in BANKLVL between visits
*
* Colours: walls green (unseen ones in 50% dots), ladders the red/green mix as in the corridor (V down,
* ^ up), you a light blue arrow. Items (blue/green diamonds) and monsters (red letters) come later.

* markseen: as the reference: each open cell straight ahead within the light range, and the cells
* either side of it
markseen
        ldb     pdir
        ldx     #dx1
        lda     b,x
        sta     msfx
        ldx     #dy1
        lda     b,x
        sta     msfy
        incb
        andb    #3
        stb     msr
        addb    #2
        andb    #3
        stb     msl
        clr     msd
        lda     px
        ldb     py
@cell   std     mscx
        lbsr    iswall
        bne     @end
        ldd     mscx
        bsr     mark
        ldb     msl
        bsr     @side
        ldb     msr
        bsr     @side
        inc     msd
        lda     msd
        cmpa    vrange
        bhi     @end
        ldd     mscx
        adda    msfx
        addb    msfy
        bra     @cell
@end    rts
@side   ldx     #dx1            ; B = direction: mark the neighbour that way
        lda     b,x
        adda    mscx
        pshs    a
        ldx     #dy1
        lda     b,x
        adda    mscy
        tfr     a,b
        puls    a
        bra     mark

* mark: A = x, B = y. Mark that cell seen, if it's inside the maze.
mark    cmpa    mz_s
        bhs     @out
        cmpb    mz_s
        bhs     @out
        pshs    a
        lda     mz_s
        mul
        addb    ,s+
        adca    #0
        addd    #seen
        tfr     d,x
        lda     #1
        sta     ,x
@out    rts

* seenslot: X = this level's slot in the level bank (mapped in the bank window; put BANKCOM back after)
seenslot
        lda     #BANKLVL
        sta     MMUT0+6
        lda     mz_lvl
        deca
        lsla                    ; 1K per level
        lsla
        clrb
        addd    #BANKWIN
        tfr     d,x
        rts

* seensave: keep the current level's seen cells
seensave
        bsr     seenslot
        ldu     #seen
        ldy     #31*31
@copy   lda     ,u+
        sta     ,x+
        leay    -1,y
        bne     @copy
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* seenload: bring back the current level's seen cells
seenload
        bsr     seenslot
        ldu     #seen
        ldy     #31*31
@copy   lda     ,x+
        sta     ,u+
        leay    -1,y
        bne     @copy
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* itemslot: X = this level's item list in the level bank (after the 5 seen areas, 256 bytes each)
itemslot
        lda     #BANKLVL
        sta     MMUT0+6
        ldb     mz_lvl
        decb
        clra
        exg     a,b             ; (n - 1) * 256
        addd    #BANKWIN+5*1024
        tfr     d,x
        rts

* itemsave / itemload: keep / bring back the current level's items (count, then the records)
itemsave
        bsr     itemslot
        ldu     #nitems
        ldy     #1+MAXITEMS*ITEMREC
@copy   lda     ,u+
        sta     ,x+
        leay    -1,y
        bne     @copy
        lda     #BANKCOM
        sta     MMUT0+6
        rts

itemload
        bsr     itemslot
        ldu     #nitems
        ldy     #1+MAXITEMS*ITEMREC
@copy   lda     ,x+
        sta     ,u+
        leay    -1,y
        bne     @copy
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* monslot: X = this level's monster list in the level bank (after the items, 288 bytes each)
monslot lda     #BANKLVL
        sta     MMUT0+6
        lda     mz_lvl
        deca
        ldb     #288/2
        mul
        lslb
        rola
        addd    #BANKWIN+5*1024+5*256
        tfr     d,x
        rts

* monsave / monload: keep / bring back the current level's monsters (count, then the records)
monsave bsr     monslot
        ldu     #nmons
        ldy     #1+MAXMONS*MONREC
@copy   lda     ,u+
        sta     ,x+
        leay    -1,y
        bne     @copy
        lda     #BANKCOM
        sta     MMUT0+6
        rts

monload bsr     monslot
        ldu     #nmons
        ldy     #1+MAXMONS*MONREC
@copy   lda     ,x+
        sta     ,u+
        leay    -1,y
        bne     @copy
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* seenclear: a new game: nothing seen on any level
seenclear
        lda     #BANKLVL
        sta     MMUT0+6
        ldx     #BANKWIN
        ldd     #0
@clr    std     ,x++
        cmpx    #BANKWIN+5*1024
        blo     @clr
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* mapdraw: the whole map screen (rows 0-22) on the page being drawn
mapdraw lbsr    clrfull
        lda     mz_lvl          ; this level's geometry
        deca
        ldb     #MAPTABW
        mul
        addd    #maptab
        tfr     d,x
        ldb     1,x
        stb     mch
        ldb     2,x
        stb     mcw
        ldd     3,x
        std     mox
        ldd     5,x
        std     moy             ; oy, V half-width
        ldd     7,x
        std     mvt             ; V top, V bottom
        ldd     9,x
        std     mrx             ; arrow x, y
        ldd     11,x
        std     mbx             ; arrow back x, y
        ldd     13,x
        std     mix             ; item diamond x, y
        lda     #WALLCOL        ; walls you've seen: solid
        lbsr    setcol
        lda     #$FF
        lbsr    setpat
        lda     #1
        sta     mwant
        lbsr    edges
        lda     vmode           ; REVEAL: the rest too, dotted
        cmpa    #2
        bne     @lad
        lda     #$AA
        lbsr    setpat
        clr     mwant
        lbsr    edges
@lad    lda     #$FF
        lbsr    setpat
        lda     #LADCOL
        lbsr    setcol
        lda     mz_lvl          ; down ladder (levels 1-4): a V
        cmpa    #5
        bhs     @up
        lda     farx
        ldb     fary
        lbsr    shown
        beq     @up
        clr     mlup
        lda     farx            ; (shown used A and B)
        ldb     fary
        lbsr    vmark
@up     lda     mz_lvl          ; up ladder (levels 2-5): a ^
        cmpa    #1
        beq     @you
        lda     #1
        tfr     a,b
        lbsr    shown
        beq     @you
        lda     #1
        sta     mlup
        tfr     a,b             ; (1,1)
        lbsr    vmark
@you    lda     vmode           ; REVEAL: every item, as a diamond, and every monster, as its letter
        cmpa    #2
        bne     @arrow
        lbsr    diamonds
        lbsr    monletters
@arrow  lda     #TXBLUE         ; you: an arrow pointing the way you face, light blue
        lbsr    setcol
        lbsr    arrow
        lsr     mrx             ; and a half-size red one inside it (Steve)
        lsr     mry
        lsr     mbx
        lsr     mby
        lda     #TXRED
        lbsr    setcol
        lbsr    arrow
        lda     #TXGREEN        ; title
        sta     textmask
        lbsr    mbstart
        ldx     #m_yourmap
        lda     vmode
        cmpa    #2
        bne     @t
        ldx     #m_fullmap
@t      lbsr    mbstr
        clra
        ldb     mz_lvl
        lbsr    mbnum
        lda     vmode           ; REVEAL: how many foes and items (the reference's legend counts)
        cmpa    #2
        bne     @tdone
        ldx     #m_sp3
        lbsr    mbstr
        clra
        ldb     nmons
        lbsr    mbnum
        ldx     #m_foes
        lbsr    mbstr
        clra
        ldb     nitems
        lbsr    mbnum
        ldx     #m_itemsn
        lbsr    mbstr
@tdone  ldu     mbp
        clr     ,u
        clra
        ldy     #mbuf
        lbsr    rowstr
        lda     #TXBLUE         ; legend
        sta     textmask
        ldy     #m_maplegend
        lda     vmode
        cmpa    #2
        beq     @l
        ldy     #m_mapclose
@l      lda     #22
        lbra    rowstr

* diamonds: a diamond on each item's cell (REVEAL), in ITEMCOL
diamonds
        lda     #ITEMCOL
        lbsr    setcol
        ldx     #items
        lda     nitems
        lbeq    @end
        sta     dloop
@each   stx     dptr
        lda     ,x
        ldb     1,x
        lbsr    centre
        ldd     mxc             ; corners: top / bottom at the centre x, left / right at the centre y
        std     dtx
        clra
        ldb     mix
        addd    mxc
        std     drx
        clra
        ldb     mix
        pshs    d
        ldd     mxc
        subd    ,s++
        std     dlx
        lda     myc
        suba    miy
        sta     dty
        lda     myc
        adda    miy
        sta     dby
        ldd     dtx             ; top - right
        std     <lx0
        ldx     drx
        lda     dty
        ldb     myc
        bsr     dseg
        ldd     drx             ; right - bottom
        std     <lx0
        ldx     dtx
        lda     myc
        ldb     dby
        bsr     dseg
        ldd     dtx             ; bottom - left
        std     <lx0
        ldx     dlx
        lda     dby
        ldb     myc
        bsr     dseg
        ldd     dlx             ; left - top
        std     <lx0
        ldx     dtx
        lda     myc
        ldb     dty
        bsr     dseg
        ldx     dptr
        leax    ITEMREC,x
        dec     dloop
        lbne    @each
@end    rts

* dseg: a line from (lx0, A) to (X, B)
dseg    stx     <lx1
        sta     <ly0
        stb     <ly1
        lbra    line

* monletters: each monster as a small red letter in its cell, the reference's map letters (S mould,
* C crawler, B skeleton, H hound, W wraith, G golem, K king), drawn with lines to fit the cell; a
* short light blue mark at the top right if it carries something
monletters
        lda     nmons
        lbeq    @end
        sta     mlcnt
        ldx     #mons
@each   stx     mlp
        lda     ,x              ; the cell's top left, inset: x + 2, y + 1; usable cw - 4 by ch - 2
        ldb     mcw
        mul
        addd    mox
        addd    #2
        std     mlx
        ldx     mlp
        lda     1,x
        ldb     mch
        mul
        addb    moy
        incb
        stb     mly
        lda     #TXRED
        lbsr    setcol
        ldx     mlp
        ldb     2,x
        lslb
        ldx     #mletters
        ldx     b,x
        lda     ,x+             ; polylines
        sta     mlpn
@poly   lda     ,x+
        sta     mlpt
        bsr     @pt
        ldd     mpx
        std     mqx
        lda     mpy
        sta     mqy
        dec     mlpt
@seg    bsr     @pt
        stx     mlq
        ldd     mqx
        std     <lx0
        lda     mqy
        sta     <ly0
        ldd     mpx
        std     <lx1
        std     mqx
        lda     mpy
        sta     <ly1
        sta     mqy
        lbsr    line
        ldx     mlq
        dec     mlpt
        bne     @seg
        dec     mlpn
        bne     @poly
        ldx     mlp             ; carries something: a short mark at the top right of the cell
        lda     7,x
        cmpa    #$FF
        beq     @next
        lda     #TXBLUE
        lbsr    setcol
        ldd     mlx
        addb    mcw
        adca    #0
        subd    #4
        std     <lx1
        subd    #2
        std     <lx0
        lda     mly
        deca
        sta     <ly0
        sta     <ly1
        lbsr    line
@next   ldx     mlp
        leax    MONREC,x
        dec     mlcnt
        lbne    @each
@end    rts
@pt     lda     ,x+             ; a letter point (0-4, 0-4) to the screen
        ldb     mcw
        subb    #4
        mul
        lsra
        rorb
        lsra
        rorb
        addd    mlx
        std     mpx
        lda     ,x+
        ldb     mch
        subb    #2
        mul
        lsrb
        lsrb
        addb    mly
        stb     mpy
        rts

* The map letters, on a 0-4 grid (y down): polylines, then points
mletters fdb    ml_s,ml_c,ml_b,ml_h,ml_w,ml_g,ml_k
ml_s    fcb     1,6,4,0,0,0,0,2,4,2,4,4,0,4
ml_c    fcb     1,4,4,0,0,0,0,4,4,4
ml_b    fcb     2,6,0,0,0,4,3,4,4,3,3,2,0,2,4,3,2,4,1,3,0,0,0
ml_h    fcb     3,2,0,0,0,4,2,4,0,4,4,2,0,2,4,2
ml_w    fcb     1,5,0,0,1,4,2,2,3,4,4,0
ml_g    fcb     1,6,4,0,0,0,0,4,4,4,4,2,2,2
ml_k    fcb     2,2,0,0,0,4,3,4,0,0,2,4,4

* shown: A = x, B = y. NE if that cell goes on the map (REVEAL shows everything, YOUR MAP what's seen).
shown   pshs    a
        lda     vmode
        cmpa    #2
        puls    a
        beq     @yes
        pshs    a
        lda     mz_s
        mul
        addb    ,s+
        adca    #0
        addd    #seen
        tfr     d,x
        tst     ,x
        rts
@yes    lda     #1
        rts

* centre: A = x, B = y (cell). Sets mxc, myc = the cell's centre in pixels.
centre  pshs    b
        ldb     mcw
        mul
        addd    mox
        pshs    d
        clra
        ldb     mcw
        lsrb
        addd    ,s++
        std     mxc
        puls    a
        ldb     mch
        mul
        addb    moy
        adca    #0
        pshs    b
        ldb     mch
        lsrb
        addb    ,s+
        stb     myc
        rts

* vmark: a ladder mark at A = x, B = y: a solid triangle (Steve), pointing down for the down ladder,
* or up if mlup is set; filled with a horizontal line per row, most of the cell's size
vmark   pshs    d
        lbsr    centre
        puls    d
        lda     mcw             ; half its width: 3/8 of the cell
        ldb     #3
        mul
        lsrb
        lsrb
        lsrb
        stb     mhw
        lda     mch             ; its height: the cell's, less a row top and bottom
        suba    #2
        sta     mth
        lda     myc             ; its top row
        ldb     mch
        lsrb
        pshs    b
        suba    ,s+
        inca
        sta     mty
        clr     mtr             ; row by row: width falls from the base to the point
@row    lda     mth             ; this row's half-width: mhw x (rows to the point) / height
        suba    mtr             ;   down: rows left;  up: rows done + 1
        tst     mlup
        beq     @hw
        lda     mtr
        inca
@hw     ldb     mhw
        mul
        clr     mtq
@div    cmpb    mth             ; (small: divide by subtraction)
        blo     @dq
        subb    mth
        inc     mtq
        bra     @div
@dq     clra
        ldb     mtq
        pshs    d
        ldd     mxc
        subd    ,s
        std     <lx0
        ldd     mxc
        addd    ,s++
        std     <lx1
        lda     mty
        adda    mtr
        sta     <ly0
        sta     <ly1
        lbsr    line
        inc     mtr
        lda     mtr
        cmpa    mth
        blo     @row
        rts

* arrow: you, as the reference's triangle (outline): the point a little ahead of the centre, the back
* corners behind it and to the sides
arrow   lda     px
        ldb     py
        lbsr    centre
        ldb     pdir
        ldx     #dx1
        lda     b,x
        sta     mdx
        ldx     #dy1
        lda     b,x
        sta     mdy
        lda     mdx             ; point: (xc + dx*rx, yc + dy*ry)
        ldb     mrx
        lbsr    smul
        addd    mxc
        std     mtipx
        lda     mdy
        ldb     mry
        lbsr    smul
        addb    myc
        stb     mtip
        lda     mdx             ; back centre: (xc - dx*rx, yc - dy*ry)
        nega
        ldb     mrx
        lbsr    smul
        addd    mxc
        std     mbkx
        lda     mdy
        nega
        ldb     mry
        lbsr    smul
        addb    myc
        stb     mbky
        lda     mdy             ; corners: back centre +/- (dy*bx, -dx*by)
        ldb     mbx
        lbsr    smul
        std     moffx
        lda     mdx
        nega
        ldb     mby
        lbsr    smul
        stb     moffy
        ldd     mbkx            ; corner 1 = back + off
        addd    moffx
        std     mc1x
        lda     mbky
        adda    moffy
        sta     mc1y
        ldd     mbkx            ; corner 2 = back - off
        subd    moffx
        std     mc2x
        lda     mbky
        suba    moffy
        sta     mc2y
        ldd     mtipx           ; point - corner 1 - corner 2 - point
        std     <lx0
        lda     mtip
        sta     <ly0
        ldd     mc1x
        std     <lx1
        lda     mc1y
        sta     <ly1
        lbsr    line
        ldd     mc1x
        std     <lx0
        lda     mc1y
        sta     <ly0
        ldd     mc2x
        std     <lx1
        lda     mc2y
        sta     <ly1
        lbsr    line
        ldd     mc2x
        std     <lx0
        lda     mc2y
        sta     <ly0
        ldd     mtipx
        std     <lx1
        lda     mtip
        sta     <ly1
        lbra    line

* smul: A = -1, 0 or 1, B = 0-255. D = A * B (signed 16-bit).
smul    tsta
        beq     @zero
        bmi     @neg
        clra
        rts
@neg    clra
        pshs    d
        ldd     #0
        subd    ,s++
        rts
@zero   clrb
        rts

* edges: walls around every open cell whose seen-ness matches mwant (1 seen, 0 not), as the
* reference: a line along each side that has a wall next to it
edges   ldx     #grid
        stx     mgp
        ldx     #seen
        stx     msp
        clr     my
        lda     moy
        sta     mypix
@row    clr     mx
        ldd     mox
        std     mxpix
@col    ldx     mgp
        tst     ,x
        lbne    @next           ; a wall itself: nothing to draw
        ldy     msp
        lda     ,y
        beq     @unseen
        lda     #1
@unseen cmpa    mwant
        lbne    @next
        ldb     mz_s            ; above
        negb
        tst     b,x
        beq     @below
        ldd     mxpix
        std     <lx0
        addb    mcw
        adca    #0
        std     <lx1
        lda     mypix
        sta     <ly0
        sta     <ly1
        lbsr    line
        ldx     mgp
@below  ldb     mz_s
        tst     b,x
        beq     @left
        ldd     mxpix
        std     <lx0
        addb    mcw
        adca    #0
        std     <lx1
        lda     mypix
        adda    mch
        sta     <ly0
        sta     <ly1
        lbsr    line
        ldx     mgp
@left   tst     -1,x
        beq     @right
        ldd     mxpix
        std     <lx0
        std     <lx1
        lda     mypix
        sta     <ly0
        adda    mch
        sta     <ly1
        lbsr    line
        ldx     mgp
@right  tst     1,x
        beq     @next
        ldd     mxpix
        addb    mcw
        adca    #0
        std     <lx0
        std     <lx1
        lda     mypix
        sta     <ly0
        adda    mch
        sta     <ly1
        lbsr    line
@next   ldx     mgp
        leax    1,x
        stx     mgp
        ldx     msp
        leax    1,x
        stx     msp
        ldd     mxpix
        addb    mcw
        adca    #0
        std     mxpix
        inc     mx
        lda     mx
        cmpa    mz_s
        lblo    @col
        lda     mypix
        adda    mch
        sta     mypix
        inc     my
        lda     my
        cmpa    mz_s
        lblo    @row
        rts

* Variables
vmode   fcb     0
msfx    fcb     0
msfy    fcb     0
msl     fcb     0
msr     fcb     0
msd     fcb     0
mscx    fcb     0               ; mscx, mscy together
mscy    fcb     0
mch     fcb     0
mcw     fcb     0
mox     fdb     0
moy     fcb     0               ; moy, mvx together
mvx     fcb     0
mvt     fcb     0               ; mvt, mvb together
mvb     fcb     0
mrx     fcb     0               ; mrx, mry together
mry     fcb     0
mbx     fcb     0               ; mbx, mby together
mby     fcb     0
mix     fcb     0               ; mix, miy together: item diamond size
miy     fcb     0
dloop   fcb     0
dptr    fdb     0
dtx     fdb     0               ; diamond corners
drx     fdb     0
dlx     fdb     0
dty     fcb     0
dby     fcb     0
mwant   fcb     0
mgp     fdb     0
msp     fdb     0
mx      fcb     0
my      fcb     0
mxpix   fdb     0
mypix   fcb     0
mxc     fdb     0
myc     fcb     0
mlup    fcb     0
mend    fcb     0
mtip    fcb     0
mtipx   fdb     0
mdx     fcb     0
mdy     fcb     0
mbkx    fdb     0
mbky    fcb     0
moffx   fdb     0
moffy   fcb     0
mc1x    fdb     0
mc1y    fcb     0
mc2x    fdb     0
mc2y    fcb     0
mlcnt   fcb     0               ; monletters
mhw     fcb     0               ; vmark: half-width, height, top row, row, quotient
mth     fcb     0
mty     fcb     0
mtr     fcb     0
mtq     fcb     0
mlp     fdb     0
mlq     fdb     0
mlx     fdb     0
mly     fcb     0
mlpn    fcb     0
mlpt    fcb     0
mpx     fdb     0
mpy     fcb     0
mqx     fdb     0
mqy     fcb     0

* clrfull: clear rows 0-183 (everything above the command line): the view, then the text rows
clrfull lbsr    clrview
        ldu     #SCRCPU+184*ROWB
        ldd     #0
        ldx     #0
        ldy     #0
@clr    pshu    d,x,y
        cmpu    #SCRCPU+VIEWBYTES
        bhi     @clr
        rts
