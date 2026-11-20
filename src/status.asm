* The status rows (21 and 22) are built in SROW first and then drawn a cell at a time (sflush), so
* each cell goes straight from its old character to its new one. Text rows are drawn on the page
* being shown too; blanking the rows first and then writing on them made the hands and health flash
* (Steve). In the common bank (the font is needed anyway); SROW is the unused top of the bank.
*
* A character with bit 7 set is light blue; the heart's characters are red; the rest green.
SROW    equ     $DFB0           ; 80 bytes: row 21, then row 22

* sclear: both rows blank
sclear  pshs    d,x
        ldx     #SROW
        ldd     #$2020
@c      std     ,x++
        cmpx    #SROW+80
        blo     @c
        puls    d,x,pc

* sprint: as printat (A = row HANDROW or STATROW, B = column, Y = string), into SROW, in the colour
* of textmask (light blue or green)
sprint  pshs    d,x,y
        lda     textmask        ; TXBLUE ($FF): bit 7; TXGREEN ($55): none
        anda    #$80
        pshs    a
        lda     1,s
        suba    #HANDROW
        beq     @o
        lda     #40
@o      adda    2,s
        ldx     #SROW
        leax    a,x
@n      lda     ,y+
        beq     @e
        ora     ,s
        sta     ,x+
        bra     @n
@e      leas    1,s
        puls    d,x,y,pc

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
        rts

* sflush: draw both rows from SROW on the page mapped
sflush  pshs    d,x,y
        ldy     #SROW
        lda     #HANDROW
        bsr     @row
        lda     #STATROW
        bsr     @row
        puls    d,x,y,pc
@row    clrb
        lbsr    textpos
        ldb     #40
@c      lda     ,y+
        pshs    b
        ldb     #TXBLUE
        tsta
        bmi     @b
        ldb     #TXGREEN
        cmpa    #CH_HEART       ; (the heart's characters are the last ones)
        blo     @b
        ldb     #TXRED
@b      anda    #$7F
        stb     textmask
        puls    b
        lbsr    putc
        leax    4,x
        decb
        bne     @c
        rts
