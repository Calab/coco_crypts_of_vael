* Text: 8x8 characters (4 bits per pixel on screen, 1 bit per pixel in the font), 40 columns x 24 rows.
* The font and its expansion table come from build/font.asm (generated from src/font.txt).

* textpos: A = row (0-23), B = column (0-39). Returns X = screen address of that cell.
textpos pshs    b
        ldb     #5
        mul                     ; D = row*5
        tfr     b,a
        clrb                    ; D = row*1280 (8 lines of 160 bytes)
        addd    #SCRCPU
        tfr     d,x
        puls    b
        lslb
        lslb                    ; column*4 bytes
        abx
        rts

* putc: A = character code, X = cell address. Draws in the colour of textmask
* ($55 colour 1, $AA colour 2, $FF colour 3). Overwrites the whole cell. Preserves all registers.
putc    pshs    d,x,y,u
        tfr     x,u             ; U = screen
        suba    #FONT_FIRST
        cmpa    #FONT_COUNT
        blo     @known
        clra                    ; unknown codes draw as a space
@known  ldb     #16
        mul
        addd    #font
        tfr     d,y             ; Y = this character's 8 rows of 2 bytes
        lda     #8
        sta     putcrow
@row    ldb     ,y+             ; left 8 pixels
        ldx     #fontexp
        abx
        lda     ,x
        ldb     256,x
        anda    textmask
        andb    textmask
        std     ,u
        ldb     ,y+             ; right 8 pixels
        ldx     #fontexp
        abx
        lda     ,x
        ldb     256,x
        anda    textmask
        andb    textmask
        std     2,u
        leau    ROWB,u
        dec     putcrow
        bne     @row
        puls    d,x,y,u,pc

* puts: Y = zero-terminated string, X = cell address. Returns X just past the last character.
puts    pshs    a,y
@next   lda     ,y+
        beq     @end
        bsr     putc
        leax    4,x
        bra     @next
@end    puls    a,y,pc

* putrange: A = first character code, B = how many, X = cell address. Returns X past the last.
putrange
        pshs    d
@next   bsr     putc
        leax    4,x
        inca
        decb
        bne     @next
        puls    d,pc

* clrscr: clear the whole screen page to colour 0.
clrscr  pshs    d,x,y,u
        ldu     #SCRCPU+SCRBYTES
        ldd     #0
        tfr     d,x
        tfr     d,y
@next   pshu    d,x,y           ; 6 bytes at a time; 30720 = 5120 x 6
        cmpu    #SCRCPU
        bne     @next
        puls    d,x,y,u,pc

* numstr32: write the 32-bit value at num32 in decimal (no leading zeros) at U. U advances past
* it (not zero-terminated). Destroys num32.
numstr32
        pshs    d,x
        ldx     #pow10
        clr     numnz
@digit  clr     numdig
@sub    ldd     num32           ; while num32 >= power of ten: subtract
        cmpd    ,x
        blo     @show
        bhi     @do
        ldd     num32+2
        cmpd    2,x
        blo     @show
@do     ldd     num32+2
        subd    2,x
        std     num32+2
        ldd     num32
        sbcb    1,x
        sbca    ,x
        std     num32
        inc     numdig
        bra     @sub
@show   lda     numdig
        bne     @put
        tst     numnz
        bne     @put
        cmpx    #pow10+36       ; always write the units digit
        bne     @skip
@put    inc     numnz           ; once a digit is written, zeros after it are written too
        adda    #'0
        sta     ,u+
@skip   leax    4,x
        cmpx    #pow10+40
        bne     @digit
        puls    d,x,pc

* numstr: D = 16-bit value, written like numstr32
numstr  std     num32+2
        clr     num32
        clr     num32+1
        bra     numstr32

* putnum32 / putnum: print a number at X (screen cell). X advances.
putnum  std     num32+2
        clr     num32
        clr     num32+1
putnum32
        pshs    y,u
        ldu     #numtmp
        bsr     numstr32
        clr     ,u
        ldy     #numtmp
        lbsr    puts
        puls    y,u,pc

* rowstr: A = text row, Y = zero-terminated string. Draws it from column 0 and fills the rest of
* the row with spaces, in textmask's colour.
rowstr  pshs    d,y
        clrb
        lbsr    textpos
        leau    160,x           ; end of the row
        lbsr    puts
@pad    pshs    u
        cmpx    ,s++
        bhs     @done
        lda     #$20
        lbsr    putc
        leax    4,x
        bra     @pad
@done   puls    d,y,pc

pow10   fqb     1000000000,100000000,10000000,1000000,100000,10000,1000,100,10,1
num32   fqb     0
numtmp  fill    0,12
numdig  fcb     0
numnz   fcb     0
