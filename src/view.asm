* The corridor view: a port of the wall part of the reference's renderMain, including its glide
* shift: vshift = 1 or 2 pulls every depth 1/3 or 2/3 of a cell closer (the reference's shift
* of -1/3, -2/3), clipping at the eye. Depth tables are in thirds of a cell.
* Draws into the screen mapped at SCRCPU, rows 0 to VIEWH-1. Depth geometry comes from the
* tables in build/tables.asm (vl, vr, vt, vb, vol, vor).
*
*   render   draw the view from (px, py) facing pdir, seeing up to vrange cells

* LINE x0,y0,x1,y1: memory operands (x 16-bit, y 8-bit)
LINE    macro
        ldd     \1
        std     <lx0
        lda     \2
        sta     <ly0
        ldd     \3
        std     <lx1
        lda     \4
        sta     <ly1
        lbsr    dline
        endm

* iswall: A = x, B = y (signed). Returns A = 1 and NE for wall or outside the maze, else A = 0, EQ.
iswall  cmpa    mz_s            ; unsigned: negative values count as outside too
        bhs     @out
        cmpb    mz_s
        bhs     @out
        pshs    x
        lbsr    cellad
        lda     ,x
        puls    x,pc
@out    lda     #1
        rts

render
        ifdef   LINELOG
        ldd     #lnlog
        std     lnlogp
        endc
        lbsr    clrview
        tst     vturn
        beq     drawview
* Turn pan, halfway: the old view slides out one side and the new one slides in from the other,
* each shifted half a screen and clipped at the screen edges (the reference's renderView at v = 1/2).
        lda     #1
        sta     vclip
        lda     pdir
        pshs    a
        ldd     #-320           ; turning right: the old view moves left
        tst     vturn
        bpl     @old
        ldd     #320            ; turning left: it moves right
@old    std     vxoff
        lbsr    drawview
        lda     tdir1
        sta     pdir
        ldd     #0              ; the new view comes from the other side
        subd    vxoff
        std     vxoff
        lbsr    drawview
        puls    a
        sta     pdir
        clr     vclip
        lda     #$AA            ; the seam between them, half bright as in the reference
        lbsr    setpat
        ldd     #320
        std     <lx0
        std     <lx1
        clr     <ly0
        lda     #VIEWH-1
        sta     <ly1
        lbra    line

drawview
        lda     #WALLCOL
        lbsr    setcol
        lda     vrange          ; see one cell further while gliding forward
        tst     vshift
        beq     @rng
        inca
@rng    sta     erange
        ldb     pdir            ; forward step and the two side directions
        ldx     #dx1
        lda     b,x
        sta     vfx
        ldx     #dy1
        lda     b,x
        sta     vfy
        incb
        andb    #3
        stb     vrdir
        addb    #2
        andb    #3
        stb     vldir
* Visible cells straight ahead, up to the light range or the first wall
        clr     ncells
        lda     px
        ldb     py
@scan   std     tcx
        lbsr    iswall
        bne     @scanned
        ldx     #cellxy
        ldb     ncells
        lslb
        abx
        ldd     tcx
        std     ,x
        inc     ncells
        lda     ncells
        cmpa    erange
        bhi     @scanned
        ldd     tcx
        adda    vfx
        addb    vfy
        bra     @scan
@scanned
        clr     ci
@cell   lda     ci
        cmpa    ncells
        bhs     @back
        ldx     #cellxy
        ldb     ci
        lslb
        abx
        ldd     ,x
        std     tcx
        lda     ci              ; near edge depth in thirds, clipped at the eye: n3 = max(0, 3ci - shift)
        ldb     #3
        mul
        subb    vshift
        bcc     @n3
        clrb
@n3     stb     n3
        lbsr    cellpat         ; this cell's walls are shaded by their near edge's depth
        lda     ci              ; far edge: f3 = 3(ci+1) - shift (always in front of the eye)
        inca
        ldb     #3
        mul
        subb    vshift
        stb     f3
        clra
        lbsr    side            ; left
        lda     #1
        lbsr    side            ; right
        inc     ci
        bra     @cell
* The wall at the end of the corridor, if it's within range
@back   lda     ncells
        cmpa    erange
        lbhi    @done
        ldb     #3
        mul
        subb    vshift
        stb     f3
        lbsr    cellpat         ; the end wall is shaded by its own depth
        ldb     f3
        lslb
        ldx     #vl
        abx
        ldd     ,x
        std     xn
        ldd     vr-vl,x         ; same depth in the right-edge table
        std     xf
        ldb     f3
        ldx     #vt
        lda     b,x
        sta     nt
        ldx     #vb
        lda     b,x
        sta     nb
        LINE    xn,nt,xf,nt
        LINE    xn,nb,xf,nb
        LINE    xn,nt,xn,nb
        LINE    xf,nt,xf,nb
@done   lbra    contents

* contents: what's in each visible cell, far to near (the reference's second loop). So far: ladders.
contents
        lda     ncells
@cell   deca
        bmi     @end
        sta     ci
        ldx     #cellxy
        ldb     ci
        lslb
        abx
        ldd     ,x
        std     tcx
        lda     ci              ; near edge in thirds: 3ci - shift (-2 when gliding past your own cell)
        ldb     #3
        mul
        subb    vshift
        stb     lbase
        bpl     @pat
        clrb
@pat    lbsr    cellpat         ; shaded like the cell's walls (near edge)
        lda     mz_lvl          ; down ladder: the far cell, on levels 1-4
        cmpa    #5
        bhs     @up
        ldd     tcx
        cmpa    farx
        bne     @up
        cmpb    fary
        bne     @up
        clra
        ldb     lbase
        lbsr    ladder
@up     lda     mz_lvl          ; up ladder: (1,1), on levels 2-5
        cmpa    #1
        beq     @next
        ldd     tcx
        cmpd    #$0101
        bne     @next
        lda     #1
        ldb     lbase
        lbsr    ladder
@next   lbsr    cellitems       ; items on the floor
        lda     ci
        bra     @cell
@end    rts

* ladder: A = 0 for a down ladder (a hole in the floor), 1 for an up ladder (in the ceiling);
* B = the cell's near edge in thirds (-2 up). Trapezoid outline, two rails and three rungs.
ladder  sta     lup
        lda     #LADCOL
        lbsr    setcol
        addb    #2
        lda     #LTABROW
        mul
        addd    #ltab
        tfr     d,u
        stu     lptr
        ldx     #lady           ; the 5 y positions, floor or ceiling
        ldb     #5
@ys     lda     ,u
        tst     lup
        beq     @y
        lda     1,u
@y      sta     ,x+
        leau    4,u
        decb
        bne     @ys
        ldu     lptr
        ldb     2,u             ; outline: near and far corners
        lbsr    @minus
        std     lxl0
        ldb     2,u
        lbsr    @plus
        std     lxr0
        ldb     18,u
        lbsr    @minus
        std     lxl4
        ldb     18,u
        lbsr    @plus
        std     lxr4
        ldb     3,u             ; rails
        lbsr    @minus
        std     lrl0
        ldb     3,u
        lbsr    @plus
        std     lrr0
        ldb     19,u
        lbsr    @minus
        std     lrl4
        ldb     19,u
        lbsr    @plus
        std     lrr4
        LINE    lxl0,lady,lxr0,lady
        LINE    lxr0,lady,lxr4,lady+4
        LINE    lxr4,lady+4,lxl4,lady+4
        LINE    lxl4,lady+4,lxl0,lady
        LINE    lrl0,lady,lrl4,lady+4
        LINE    lrr0,lady,lrr4,lady+4
        lda     lady            ; rungs only if the ladder is at least 6 rows deep; packed any
        suba    lady+4          ; tighter, their dots merge into a solid patch
        bpl     @deep
        nega
@deep   cmpa    #6
        blo     @done
        lda     #1              ; rungs at positions 1-3
        sta     lj
@rung   ldu     lptr
        lda     lj
        lsla
        lsla
        adda    #3
        ldb     a,u
        lbsr    @minus
        std     lrl0
        lda     lj
        lsla
        lsla
        adda    #3
        ldb     a,u
        lbsr    @plus
        std     lrr0
        ldx     #lady
        lda     lj
        ldb     a,x
        stb     lyr
        LINE    lrl0,lyr,lrr0,lyr
        inc     lj
        lda     lj
        cmpa    #4
        lblo    @rung
@done   rts
@minus  clra                    ; D = 320 - B
        pshs    d
        ldd     #320
        subd    ,s++
        rts
@plus   clra                    ; D = 320 + B
        addd    #320
        rts

* cellitems: the items in cell (tcx, tcy), as the reference: on the floor at depth d + 0.45,
* side by side if there are several, in ITEMCOL, shaded like the cell (pattern already set).
cellitems
        clr     icnt            ; how many are here?
        ldx     #items
        lda     nitems
        lbeq    @none
        sta     iloop
@count  ldd     ,x
        cmpd    tcx
        bne     @nc
        inc     icnt
@nc     leax    ITEMREC,x
        dec     iloop
        bne     @count
        lda     icnt
        lbeq    @none
        ldb     lbase           ; this depth's floor y, scales and spacing
        addb    #2
        lda     #ITABROW
        mul
        addd    #itab
        tfr     d,x
        tst     ,x
        beq     @none           ; too close (gliding past)
        lda     1,x
        sta     icy
        lda     2,x
        sta     isx
        lda     3,x
        sta     isy
        lda     4,x
        sta     ihalf
        lda     #ITEMCOL
        lbsr    setcol
        clr     ij              ; j-th item here
        ldx     #items
        stx     iptr2
        lda     nitems
        sta     iloop
@each   ldx     iptr2
        ldd     ,x
        cmpd    tcx
        bne     @skip
        lda     ij              ; centre x = 320 + (2j - n + 1) * half spacing
        lsla
        suba    icnt
        inca
        ldb     ihalf
        tsta
        bpl     @pos
        nega
        mul
        pshs    d
        ldd     #320
        subd    ,s++
        bra     @cx
@pos    mul
        addd    #320
@cx     std     icx
        ldx     iptr2
        ldb     2,x
        andb    #$7F            ; (the top bit is the item's XP flag)
        lbsr    drawicon
        inc     ij
@skip   ldx     iptr2
        leax    ITEMREC,x
        stx     iptr2
        dec     iloop
        bne     @each
@none   rts

* drawicon: B = item kind. Draws its icon centred at icx with its floor at icy, scaled by isx, isy
* (pixels per 1/100 unit, times 256). Lines go through dline, so they're clipped during a pan.
drawicon
        ldx     #icons
        lslb
        ldx     b,x
        lda     ,x+
        sta     inp
@poly   lda     ,x+
        sta     inpt
        bsr     ipoint          ; first point
        ldd     ipx
        std     iqx
        lda     ipy
        sta     iqy
        dec     inpt
@pt     bsr     ipoint
        stx     iptr
        ldd     iqx
        std     <lx0
        lda     iqy
        sta     <ly0
        ldd     ipx
        std     <lx1
        std     iqx
        lda     ipy
        sta     <ly1
        sta     iqy
        lbsr    dline
        ldx     iptr
        dec     inpt
        bne     @pt
        dec     inp
        bne     @poly
        rts

* ipoint: X = an icon point (x, y in 1/100 units). Sets ipx, ipy on screen; X moves past it.
ipoint  lda     ,x+
        bpl     @xp
        nega
        ldb     isx
        mul
        tfr     a,b
        clra
        pshs    d
        ldd     icx
        subd    ,s++
        bra     @xs
@xp     ldb     isx
        mul
        tfr     a,b
        clra
        addd    icx
@xs     std     ipx
        lda     ,x+
        bpl     @yp
        nega                    ; a little below the floor
        ldb     isy
        mul
        adda    icy
        cmpa    #VIEWH-1
        bls     @ys
        lda     #VIEWH-1
        bra     @ys
@yp     ldb     isy
        mul
        pshs    a
        lda     icy
        suba    ,s+
@ys     sta     ipy
        rts

* cellpat: B = depth in thirds. Sets the dot pattern for that depth and the current light.
cellpat pshs    b
        lda     vlight          ; light row: 0 = no light, else the range
        beq     @row
        lda     vrange
@row    ldb     #VPATW
        mul
        addb    ,s+
        adca    #0
        ldx     #vpat
        lda     d,x
        lbra    setpat

* side: A = 0 for the left wall of cell ci, 1 for the right. Cell position in tcx, tcy;
* near and far edge depths (in thirds) in n3, f3.
side    sta     sside
        ldx     #vl
        tst     sside
        beq     @lr
        ldx     #vr
@lr     ldb     n3
        lslb
        ldd     b,x
        std     xn
        ldb     f3
        lslb
        ldd     b,x
        std     xf
        ldx     #vt
        ldb     n3
        lda     b,x
        sta     nt
        ldb     f3
        lda     b,x
        sta     ft
        ldx     #vb
        ldb     n3
        lda     b,x
        sta     nb
        ldb     f3
        lda     b,x
        sta     fb
        ldb     vldir           ; the cell beside this one
        tst     sside
        beq     @sd
        ldb     vrdir
@sd     ldx     #dx1
        lda     b,x
        adda    tcx
        sta     ssx
        ldx     #dy1
        lda     b,x
        adda    tcy
        sta     ssy
        tfr     a,b
        lda     ssx
        lbsr    iswall
        beq     @open
* solid wall beside: its top and bottom edges, far edge, and near edge unless it's at the eye
        LINE    xn,nt,xf,ft
        LINE    xn,nb,xf,fb
        LINE    xf,ft,xf,fb
        tst     n3
        beq     @ret
        LINE    xn,nt,xn,nb
@ret    rts
* opening beside: the doorway's two edges, and the far wall of the side passage if there is one
@open   tst     n3
        beq     @o2
        LINE    xn,nt,xn,nb
@o2     LINE    xf,ft,xf,fb
        lda     ssx
        adda    vfx
        ldb     ssy
        addb    vfy
        lbsr    iswall
        beq     @ret
        ldb     f3
        lslb
        tst     sside
        bne     @right
        ldx     #vol            ; xo = max(xn, outer)
        ldd     b,x
        cmpd    xn
        bge     @xo
        ldd     xn
        bra     @xo
@right  ldx     #vor            ; xo = min(xn, outer)
        ldd     b,x
        cmpd    xn
        ble     @xo
        ldd     xn
@xo     std     xo
        LINE    xo,ft,xf,ft
        LINE    xo,fb,xf,fb
        rts

* View variables
        ifndef  STARTLIGHT
STARTLIGHT equ  0               ; timing walk only: its light (the game starts dark, as the reference)
        endc
vlight  fcb     0               ; the burning light's full range: 7 lantern, 4 torch, 0 none
vrange  fcb     1               ; how far you see now (lightRange; at least your own cell)
lbase   fcb     0               ; contents: cell's near edge in thirds (signed)
icnt    fcb     0               ; cellitems: items in this cell
iloop   fcb     0
ij      fcb     0
iptr2   fdb     0
icx     fdb     0               ; drawicon: centre x, floor y, scales
icy     fcb     0
isx     fcb     0
isy     fcb     0
ihalf   fcb     0
inp     fcb     0
inpt    fcb     0
iptr    fdb     0
ipx     fdb     0
ipy     fcb     0
iqx     fdb     0
iqy     fcb     0
lup     fcb     0               ; ladder: 0 down, 1 up
lptr    fdb     0
lady    fcb     0,0,0,0,0       ; ladder y at its 5 positions
lyr     fcb     0
lj      fcb     0
lxl0    fdb     0
lxr0    fdb     0
lxl4    fdb     0
lxr4    fdb     0
lrl0    fdb     0
lrr0    fdb     0
lrl4    fdb     0
lrr4    fdb     0
vshift  fcb     0               ; glide: how many thirds of a cell to pull the view closer (0-2)
erange  fcb     0               ; range for this frame (one more while gliding)
n3      fcb     0               ; near and far edge of the current cell, in thirds of a cell
f3      fcb     0
vfx     fcb     0               ; forward step
vfy     fcb     0
vldir   fcb     0
vrdir   fcb     0
ncells  fcb     0
ci      fcb     0
cellxy  fill    0,2*12
tcx     fcb     0               ; tcx, tcy stored as a pair
tcy     fcb     0
sside   fcb     0
ssx     fcb     0
ssy     fcb     0
xn      fdb     0
xf      fdb     0
xo      fdb     0
nt      fcb     0
nb      fcb     0
ft      fcb     0
fb      fcb     0

        ifdef   LINELOG
lnlogp  fdb     lnlog
lnlog   fill    0,6*100
        endc

* dline: draw lx0,ly0 - lx1,ly1. When vclip is set, first shift x by vxoff (signed) and clip the
* line to x 0-639 (y is never out of range in the view).
dline   tst     vclip
        lbeq    line
        ldd     <lx0
        addd    vxoff
        std     <lx0
        ldd     <lx1
        addd    vxoff
        std     <lx1
        cmpd    <lx0            ; make x0 <= x1 (signed)
        bge     @ord
        ldd     <lx0
        ldx     <lx1
        std     <lx1
        stx     <lx0
        lda     <ly0
        ldb     <ly1
        sta     <ly1
        stb     <ly0
@ord    ldd     <lx1
        bmi     @skip           ; all left of the screen
        ldd     <lx0
        cmpd    #VIEWW-1
        bgt     @skip           ; all right of it
        tsta
        bpl     @lok
* x0 < 0: y0 += (y1 - y0) * (0 - x0) / (x1 - x0), x0 = 0
        ldd     #0
        subd    <lx0
        std     mdb
        ldd     <lx1
        subd    <lx0
        std     mdc
        lda     <ly1
        suba    <ly0
        bsr     sdmul           ; B = (y1 - y0) * mdb / mdc, signed
        addb    <ly0
        stb     <ly0
        ldd     #0
        std     <lx0
@lok    ldd     <lx1
        cmpd    #VIEWW-1
        ble     @rok
* x1 > 639: y1 -= (y1 - y0) * (x1 - 639) / (x1 - x0), x1 = 639
        subd    #VIEWW-1
        std     mdb
        ldd     <lx1
        subd    <lx0
        std     mdc
        lda     <ly1
        suba    <ly0
        bsr     sdmul
        negb
        addb    <ly1
        stb     <ly1
        ldd     #VIEWW-1
        std     <lx1
@rok    lbra    line
@skip   rts

* sdmul: A = signed a (-135..135), mdb, mdc = 16-bit with 0 <= mdb <= mdc, mdc > 0.
* Returns B = a * mdb / mdc, rounded toward zero, with a's sign.
sdmul   tsta
        bpl     muldiv
        nega
        bsr     muldiv
        negb
        rts

* muldiv: A = a (0-255). Returns B = a * mdb / mdc (floor); needs mdb <= mdc so the result fits.
muldiv  sta     mda
        ldb     mdb+1           ; 24-bit product a * mdb in mdp
        mul
        std     mdp+1
        lda     mda
        ldb     mdb
        mul
        addb    mdp+1
        adca    #0
        stb     mdp+1
        sta     mdp
        ldd     #0              ; long division by mdc, one bit at a time
        std     mdr
        clr     mdq
        lda     #24
        sta     mdn
@bit    lsl     mdp+2
        rol     mdp+1
        rol     mdp
        rol     mdr+1
        rol     mdr
        ldd     mdr
        subd    mdc
        bcs     @zero
        std     mdr
        orcc    #1              ; quotient bit 1
        bra     @shift
@zero   andcc   #$FE            ; quotient bit 0
@shift  rol     mdq
        dec     mdn
        bne     @bit
        ldb     mdq
        rts

vclip   fcb     0               ; 1 while drawing a pan frame: shift and clip lines
vxoff   fdb     0               ; x shift for the view being drawn
vturn   fcb     0               ; turning: 1 right, -1 left, 0 not turning
tdir1   fcb     0               ; the direction being turned to
mda     fcb     0
mdb     fdb     0
mdc     fdb     0
mdp     fcb     0,0,0
mdr     fdb     0
mdq     fcb     0
mdn     fcb     0
