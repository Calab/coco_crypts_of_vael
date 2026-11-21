* Low code: $0000-$00FF (block $38). Nothing can be loaded here (Disk BASIC's direct page, used by
* DSKCON while the data file is read), so this is carried by the data file in the sound engine's
* image, at offset $0300 of bank BANKSND (tools/relocate.py), and sndcopy copies it down at start-up,
* after the data file is in. Code here must not run before that (it's only used in play).
* (Room made for the end screen, 2026-11-20: high code was full.)

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
        lda     #ITEMCOL
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
