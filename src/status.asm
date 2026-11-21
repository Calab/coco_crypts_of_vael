* The status rows (21 and 22) are built in SROW first and then drawn a cell at a time (sflush), so
* each cell goes straight from its old character to its new one. Text rows are drawn on the page
* being shown too; blanking the rows first and then writing on them made the hands and health flash
* (Steve). In the common bank (the font is needed anyway); SROW is in the direct page's free part.
*
* Each cell's colour byte is kept beside it in scol (fixed RAM, main.asm), so any text colour works.
SROW    equ     $0D80           ; 80 bytes ($0D80-$0DCF, filled before it's read): row 21, then row 22

* sclear: both rows blank
sclear  pshs    d,x,u
        ldx     #SROW
        ldu     #scol
        ldd     #$2020
@c      std     ,x++
        std     ,u++            ; (a space's colour doesn't show)
        cmpx    #SROW+80
        blo     @c
        puls    d,x,u,pc

* sprint: as printat (A = row HANDROW or STATROW, B = column, Y = string), into SROW, in the colour
* of textmask
sprint  pshs    d,x,y,u
        suba    #HANDROW
        beq     @o
        lda     #40
@o      adda    1,s
        ldx     #SROW
        leax    a,x
        ldu     #scol
        leau    a,u
        ldb     textmask
@n      lda     ,y+
        beq     @e
        sta     ,x+
        stb     ,u+
        bra     @n
@e      puls    d,x,y,u,pc

* sheart: the heart into SROW (as drawheart: big while it beats, small between, still after the game)
sheart  lda     #CH_HEART2
        ldb     gmode
        cmpb    #1
        bne     @h
        tst     hbbig
        beq     @h
        lda     #CH_HEART
@h      sta     SROW+HEARTCOL
        inca
        sta     SROW+HEARTCOL+1
        ldb     #TXRED
        stb     scol+HEARTCOL
        stb     scol+HEARTCOL+1
        rts

* sflush: draw both rows from SROW (colours from scol) on the page mapped
sflush  pshs    d,x,y,u
        ldy     #SROW
        ldu     #scol
        lda     #HANDROW
        bsr     @row
        lda     #STATROW
        bsr     @row
        puls    d,x,y,u,pc
@row    clrb
        lbsr    textpos
        ldb     #40
@c      lda     ,u+
        sta     textmask
        lda     ,y+
        lbsr    putc
        leax    4,x
        decb
        bne     @c
        rts
