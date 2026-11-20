* Test builds only (TESTCMDS): routines for the test commands, in the common bank (fixed code and
* high code have no room for them alongside the key script). They run with BANKCOM mapped, as
* commands do.

* jump (test command XJUMP): stand facing the far cell (the down ladder; on level 5, where the king
* waits), two cells away if the passage allows, else one.
jump    clr     tdir1
@dir    ldb     tdir1           ; one cell back from the ladder, against direction tdir1
        ldx     #dx1
        lda     farx
        suba    b,x
        sta     tx
        ldx     #dy1
        lda     fary
        suba    b,x
        sta     ty
        tfr     a,b
        lda     tx
        lbsr    iswall
        beq     @found
        inc     tdir1
        lda     tdir1
        cmpa    #4
        blo     @dir
@none   rts
@found  lda     tx              ; stand there, then try one more cell back
        sta     px
        lda     ty
        sta     py
        ldb     tdir1
        stb     pdir
        ldx     #dx1
        lda     tx
        suba    b,x
        sta     tx
        ldx     #dy1
        lda     ty
        suba    b,x
        sta     ty
        tfr     a,b
        lda     tx
        lbsr    iswall
        bne     @done
        lda     tx
        sta     px
        lda     ty
        sta     py
@done   rts
