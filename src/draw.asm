* Line drawing on the 320x192, 16-colour screen mapped at SCRCPU (2 pixels per byte, the left one
* in the high nibble; 160 bytes per row).
* Inputs (direct page): lx0, ly0, lx1, ly1 (x 0-639, y 0-191): callers use logical x 0-639 and
* line halves it on entry (lx0/lx1 are changed). The colour is set with setcol: the palette entry
* in both nibbles ($11, $EE...; the entries are listed in main.asm). Each pixel replaces only its own
* Lines are dotted by lpat (set with setpat): each bit, from the top, covers 1 pixel along a
* mostly-horizontal line or 1 row of a steep one; $FF draws solid lines at full speed.
* Horizontal lines use the same pattern anchored to the screen (byte column & 3), so lines at the
* same depth line up.
*
*   setcol   A = colour byte (palette entry in both nibbles)
*   setpat   A = dot pattern ($FF solid, $EE 75%, $AA 50%, $88 25%, $80 12%)
*   line     any line; horizontal and vertical ones take fast paths
*   clrview  clear the 3D view (rows 0 to VIEWH-1) to colour 0

* Direct-page variables ($0D00-$0DFF)
lx0     equ     $0D00           ; 2
ly0     equ     $0D02
lx1     equ     $0D03           ; 2
ly1     equ     $0D05
lcol    equ     $0D06
ldx     equ     $0D07           ; 2: dx
ldy     equ     $0D09           ; 2: dy
lystep  equ     $0D0B           ; 2: +160 or -160
lerr    equ     $0D0D           ; 2
lmask   equ     $0D0F
lrmask  equ     $0D10
lcnt    equ     $0D11
ltmp    equ     $0D12           ; 2
lpat    equ     $0D14           ; dot pattern
lpcur   equ     $0D15           ; pattern, rotated as the line is drawn
lpm     equ     $0D17           ; 4: pattern as byte masks for horizontal lines
lpk     equ     $0D1B           ; horizontal lines: which of the 4 masks is next
ldx8    equ     $0D20           ; fast lines: dx and dy as bytes
ldy8    equ     $0D21
lkeep   equ     $0D22           ; fast steep / vertical lines: the bits to keep, and the pixel to set
lset    equ     $0D23

* setcol: A = colour byte (the palette entry in both nibbles)
setcol  sta     <lcol
        rts

* setpat: A = dot pattern. Also works out the 4 byte masks horizontal lines use.
setpat  pshs    d,u
        ifdef   NODOTS
        lda     #$FF            ; (test: every line solid)
        endc
        sta     <lpat
        sta     <ltmp
        ldu     #lpm
        ldb     #4
@mask   clra
        lsl     <ltmp           ; left pixel of this byte
        bcc     @a
        ora     #$F0
@a      lsl     <ltmp           ; right pixel
        bcc     @b
        ora     #$0F
@b      sta     ,u+
        decb
        bne     @mask
        puls    d,u,pc

line
        ifdef   LINELOG
        pshs    d,x             ; debug: record x0,y0,x1,y1 (6 bytes) at lnlogp
        ldx     lnlogp
        cmpx    #lnlog+6*100
        bhs     @nolog
        ldd     <lx0
        std     ,x
        ldd     <ly0            ; ly0, lx1 high byte
        std     2,x
        ldd     <lx1+1          ; lx1 low byte, ly1
        std     4,x
        leax    6,x
        stx     lnlogp
@nolog  puls    d,x
        endc
        lsr     <lx0            ; logical x 0-639 to the screen's 0-319
        ror     <lx0+1
        lsr     <lx1
        ror     <lx1+1
        ldd     <lx1
        subd    <lx0
        bhs     @ordered
        ldd     <lx0            ; swap the ends so x0 <= x1
        ldx     <lx1
        std     <lx1
        stx     <lx0
        lda     <ly0
        ldb     <ly1
        sta     <ly1
        stb     <ly0
        ldd     <lx1
        subd    <lx0
@ordered std    <ldx
        lbeq    vline0          ; dx = 0
        lda     <ly1
        suba    <ly0
        lbeq    hline0          ; dy = 0
        bhs     @down
        nega
        ldx     #-ROWB
        bra     @dy
@down   ldx     #ROWB
@dy     stx     <lystep
        tfr     a,b
        clra
        std     <ldy
        lbsr    pixaddr
        ldd     <ldx
        cmpd    <ldy
        blo     @ymajor
* x-major: one pixel per x step
        addd    #1
        tfr     d,y
        ldd     <ldx
        lsra
        rorb
        std     <lerr
        lda     <lpat
        inca
        lbne    @xpat           ; dotted
        ifndef  NOFAST
        ldd     <ldx            ; solid and up to 255 wide: the fast way (xfast)
        tsta
        lbeq    xfast
        endc
@xloop  lda     ,x
        eora    <lcol
        anda    <lmask
        eora    ,x
        sta     ,x
        com     <lmask          ; $F0 <-> $0F: the other pixel; $F0 means a new byte
        bpl     @xstep
        leax    1,x
@xstep  ldd     <lerr
        subd    <ldy
        bpl     @xnoy
        addd    <ldx
        std     <lerr
        ldd     <lystep
        leax    d,x
        leay    -1,y
        bne     @xloop
        rts
@xnoy   std     <lerr
        leay    -1,y
        bne     @xloop
        rts
* y-major: one pixel per y step
@ymajor ldd     <ldy
        addd    #1
        tfr     d,y
        ldd     <ldy
        lsra
        rorb
        std     <lerr
        lda     <lpat
        inca
        lbne    @ypat           ; dotted
        ifndef  NOFAST
        lbra    yfast           ; solid: the fast way
        endc
@yloop  lda     ,x
        eora    <lcol
        anda    <lmask
        eora    ,x
        sta     ,x
        ldd     <lystep
        leax    d,x
        ldd     <lerr
        subd    <ldx
        bpl     @ynox
        addd    <ldy
        std     <lerr
        com     <lmask          ; $F0 <-> $0F: the other pixel; $F0 means a new byte
        bpl     @ynext
        leax    1,x
@ynext  leay    -1,y
        bne     @yloop
        rts
@ynox   std     <lerr
        leay    -1,y
        bne     @yloop
        rts
* dotted x-major: a pattern bit per pixel
@xpat   lda     <lpat
        sta     <lpcur
@xpl    tst     <lpcur
        bpl     @xps
        lda     ,x
        eora    <lcol
        anda    <lmask
        eora    ,x
        sta     ,x
@xps    lda     <lpcur
        lsla
        adca    #0
        sta     <lpcur
        com     <lmask
        bpl     @xpe
        leax    1,x
@xpe    ldd     <lerr
        subd    <ldy
        bpl     @xpn
        addd    <ldx
        std     <lerr
        ldd     <lystep
        leax    d,x
        leay    -1,y
        bne     @xpl
        rts
@xpn    std     <lerr
        leay    -1,y
        bne     @xpl
        rts
* dotted y-major: a pattern bit per row
@ypat   lda     <lpat
        sta     <lpcur
@ypl    tst     <lpcur
        bpl     @yps
        lda     ,x
        eora    <lcol
        anda    <lmask
        eora    ,x
        sta     ,x
@yps    lda     <lpcur
        lsla
        adca    #0
        sta     <lpcur
        ldd     <lystep
        leax    d,x
        ldd     <lerr
        subd    <ldx
        bpl     @ypn
        addd    <ldy
        std     <lerr
        com     <lmask          ; $F0 <-> $0F: the other pixel; $F0 means a new byte
        bpl     @ypx
        leax    1,x
@ypx    leay    -1,y
        bne     @ypl
        rts
@ypn    std     <lerr
        leay    -1,y
        bne     @ypl
        rts


* xfast: a solid, mostly horizontal line up to 255 pixels wide (from line). The pixels that land in
* one screen byte are gathered and the byte written once (B collects them), and the loop is unrolled
* by pixel position (2 per byte), so each pixel is a constant mask. A = Bresenham's error, kept as
* 0..dx-1, started so the same pixels come out as the general loop. Y = pixels left, X = the byte,
* lmask = the first pixel.
xfast   stb     <ldx8
        lda     <ldy+1
        sta     <ldy8
        lda     <ldx8           ; error = dx - dx/2 - 1
        lsra
        nega
        adda    <ldx8
        deca
        pshs    a
        ldu     #xdtab          ; down or up the screen
        tst     <lystep
        bpl     @dir
        ldu     #xutab
@dir    lda     <lmask          ; start at the first pixel's position in its byte
        bmi     @go             ; $F0: the left pixel
        leau    2,u
@go     ldu     ,u
        puls    a
        clrb
        jmp     ,u

xdtab   fdb     xd0,xd1
xutab   fdb     xu0,xu1

* xflush: write the gathered pixels (B) of the byte at X in lcol; B = 0 after. Keeps A.
xflush  pshs    a,b
        lda     ,x
        eora    <lcol
        anda    1,s
        eora    ,x
        sta     ,x
        puls    a,b
        clrb
        rts

xd0    orb     #$F0
        leay    -1,y
        beq     xdend
        adda    <ldy8
        bcs     xd0s
        cmpa    <ldx8
        bhs     xd0s
xd1    orb     #$0F
        leay    -1,y
        beq     xdend
        adda    <ldy8
        bcs     xd1s
        cmpa    <ldx8
        bhs     xd1s
        bsr     xflush          ; next byte
        leax    1,x
        bra     xd0
xd0s   suba    <ldx8           ; next row
        bsr     xflush
        leax    ROWB,x
        bra     xd1
xd1s   suba    <ldx8           ; next row
        bsr     xflush
        leax    ROWB+1,x
        bra     xd0
xdend   bra     xflush

xu0    orb     #$F0
        leay    -1,y
        beq     xuend
        adda    <ldy8
        bcs     xu0s
        cmpa    <ldx8
        bhs     xu0s
xu1    orb     #$0F
        leay    -1,y
        beq     xuend
        adda    <ldy8
        bcs     xu1s
        cmpa    <ldx8
        bhs     xu1s
        bsr     xflush          ; next byte
        leax    1,x
        bra     xu0
xu0s   suba    <ldx8           ; next row
        bsr     xflush
        leax    -ROWB,x
        bra     xu1
xu1s   suba    <ldx8           ; next row
        bsr     xflush
        leax    -ROWB+1,x
        bra     xu0
xuend   bra     xflush

* masks: from lmask and lcol, lkeep = the bits to keep, lset = the pixel's bits in the colour
masks   lda     <lmask
        coma
        sta     <lkeep
        lda     <lmask
        anda    <lcol
        sta     <lset
        rts

* yfast: a solid, steep line (from line; dy <= 135, so dx and dy fit in a byte). Each
* pixel is keep / set with the masks worked out once per column; B = Bresenham's error (0..dy-1,
* started so the same pixels come out as the general loop), Y = pixels left.
yfast   lda     <ldx+1
        sta     <ldx8
        lda     <ldy+1
        sta     <ldy8
        bsr     masks
        ldb     <ldy8           ; error = dy - dy/2 - 1
        lsrb
        negb
        addb    <ldy8
        decb
        tst     <lystep
        bmi     @up
@dn     lda     ,x              ; down the screen
        anda    <lkeep
        ora     <lset
        sta     ,x
        leay    -1,y
        beq     @done
        leax    ROWB,x
        addb    <ldx8
        bcs     @dstep
        cmpb    <ldy8
        blo     @dn
@dstep  subb    <ldy8
        bsr     @right
        bra     @dn
@up     lda     ,x              ; up the screen
        anda    <lkeep
        ora     <lset
        sta     ,x
        leay    -1,y
        beq     @done
        leax    -ROWB,x
        addb    <ldx8
        bcs     @ustep
        cmpb    <ldy8
        blo     @up
@ustep  subb    <ldy8
        bsr     @right
        bra     @up
@done   rts
@right  com     <lmask          ; one pixel right: the other nibble, or the next byte
        bpl     @rm
        leax    1,x
@rm     pshs    b
        bsr     masks
        puls    b,pc

* pixaddr: X = screen address of (lx0, ly0), lmask = that pixel's bits. Uses D, U.
pixaddr ldb     <ly0
        ldx     #rowaddr
        abx
        abx
        ldx     ,x
        ldd     <lx0            ; 2 pixels per byte
        lsra
        rorb
        leax    d,x
        ldb     <lx0+1
        andb    #1
        ldu     #pixmask
        lda     b,u
        sta     <lmask
        rts

* vline0: vertical line at lx0 from ly0 to ly1 (either order)
vline0  lda     <ly0
        ldb     <ly1
        cmpa    <ly1
        bls     @ok
        sta     <ly1
        stb     <ly0
@ok     ldb     <ly1
        subb    <ly0
        incb
        stb     <lcnt
        bsr     pixaddr
        ifndef  NOFAST
        lda     <lpat           ; solid: keep / set masks, unrolled by 2
        inca
        bne     @slow
        lbsr    masks
        ldb     <lcnt
        lsrb
        bcc     @pair
        lda     ,x              ; an odd count: one row first
        anda    <lkeep
        ora     <lset
        sta     ,x
        leax    ROWB,x
        tstb
        beq     @vdone
@pair   lda     ,x
        anda    <lkeep
        ora     <lset
        sta     ,x
        lda     ROWB,x
        anda    <lkeep
        ora     <lset
        sta     ROWB,x
        leax    2*ROWB,x
        decb
        bne     @pair
@vdone  rts
@slow
        endc
        lda     <lpat
        sta     <lpcur
@loop   tst     <lpcur          ; dotted: a pattern bit per row ($FF: every row)
        bpl     @skip
        lda     ,x
        eora    <lcol
        anda    <lmask
        eora    ,x
        sta     ,x
@skip   lda     <lpcur
        lsla
        adca    #0
        sta     <lpcur
        leax    ROWB,x
        dec     <lcnt
        bne     @loop
        rts

* hline0: horizontal line from lx0 to lx1 (lx0 <= lx1) at ly0, whole bytes in the middle
hline0  lda     <lpat
        inca
        bne     hlinep          ; dotted
        lbsr    pixaddr
        ldb     <lx0+1
        andb    #1
        ldu     #lmaskl
        lda     b,u
        sta     <lmask
        ldd     <lx1            ; bytes from the first to the last: (x1 >> 1) - (x0 >> 1)
        lsra
        rorb
        std     <ltmp
        ldd     <lx0
        lsra
        rorb
        pshs    d
        ldd     <ltmp
        subd    ,s++
        stb     <lcnt
        ldb     <lx1+1
        andb    #1
        ldu     #lmaskr
        lda     b,u
        tst     <lcnt
        bne     @multi
        anda    <lmask          ; both ends in one byte
        sta     <lmask
        bra     plotm
@multi  sta     <lrmask
        bsr     plotm
        leax    1,x
        dec     <lcnt
        beq     @last
        lda     <lcol
@fill   sta     ,x+
        dec     <lcnt
        bne     @fill
@last   lda     <lrmask
        sta     <lmask
* plotm: set the lmask pixels of the byte at X to lcol
plotm   lda     ,x
        eora    <lcol
        anda    <lmask
        eora    ,x
        sta     ,x
        rts

* hlinep: dotted horizontal line, a byte at a time, using the pattern's byte masks by screen column
hlinep  lbsr    pixaddr
        ldd     <lx0            ; first byte column
        lsra
        rorb
        std     <ltmp
        andb    #3
        stb     <lpk
        ldd     <lx1            ; bytes after the first: (x1 >> 1) - (x0 >> 1)
        lsra
        rorb
        subd    <ltmp
        stb     <lcnt
        ldb     <lx0+1          ; end masks
        andb    #1
        ldu     #lmaskl
        lda     b,u
        sta     <lmask
        ldb     <lx1+1
        andb    #1
        ldu     #lmaskr
        lda     b,u
        sta     <lrmask
        ldu     #lpm
@byte   ldb     <lpk
        lda     b,u
        anda    <lmask          ; left end on the first byte, else $FF
        tst     <lcnt
        bne     @mid
        anda    <lrmask         ; right end on the last byte
@mid    tsta
        beq     @next
        sta     <ltmp
        ldb     ,x
        eorb    <lcol
        andb    <ltmp
        eorb    ,x
        stb     ,x
@next   tst     <lcnt
        beq     @done
        dec     <lcnt
        leax    1,x
        lda     #$FF
        sta     <lmask
        ldb     <lpk
        incb
        andb    #3
        stb     <lpk
        bra     @byte
@done   rts

* clrview: clear rows 0 to VIEWH-1. VIEWBYTES = 21760 = 453 x 48 + 16. The byte counter runs
* 197 times on the first pass and 256 on the second (it starts from 0): 453 x 48 bytes.
clrview pshs    d,x,y,u
        ldu     #SCRCPU+VIEWBYTES
        lda     #VIEWBYTES/48-256
        sta     <lcnt
        lda     #2
        sta     <ltmp
        ldd     #0
        tfr     d,x
        tfr     d,y
@loop   pshu    d,x,y
        pshu    d,x,y
        pshu    d,x,y
        pshu    d,x,y
        pshu    d,x,y
        pshu    d,x,y
        pshu    d,x,y
        pshu    d,x,y
        dec     <lcnt
        bne     @loop
        dec     <ltmp
        bne     @loop
        pshu    d,x,y           ; the last 16 bytes
        pshu    d,x,y
        pshu    d,x
        puls    d,x,y,u,pc
