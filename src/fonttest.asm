* Font test screen (build with -D FONTTEST): every character in each colour, plus sample lines.
* Included from main.asm after the palette is chosen.

fontscr
        jsr     clrscr
        lda     #TXGREEN
        sta     textmask
        ldd     #(0<<8)|0
        ldy     #s_head
        jsr     printat
        ldy     #s_rgb
        lda     monitor
        cmpa    #'C
        bne     @mon
        ldy     #s_cmp
@mon    ldd     #(1<<8)|0
        jsr     printat

        lda     #TXGREEN
        ldb     #3
        bsr     charset
        lda     #TXRED
        ldb     #6
        bsr     charset
        lda     #TXBLUE
        ldb     #9
        bsr     charset

        ldx     #samples
@samp   lda     ,x+             ; colour mask, 0 ends the list
        beq     done
        sta     textmask
        ldd     ,x++            ; row, column
        ldy     ,x++            ; string
        pshs    x
        jsr     printat
        puls    x
        bra     @samp

done    bra     done            ; test harness traps here


* charset: A = colour mask, B = first row. Shows every character on two rows.
charset sta     textmask
        pshs    b
        tfr     b,a
        clrb
        jsr     textpos
        lda     #FONT_FIRST
        ldb     #40
        jsr     putrange
        puls    a
        inca
        clrb
        jsr     textpos
        lda     #FONT_FIRST+40
        ldb     #FONT_COUNT-40
        jmp     putrange


s_head  fcn     "CRYPTS OF VAEL - FONT TEST"
s_rgb   fcn     "MONITOR: RGB"
s_cmp   fcn     "MONITOR: COMPOSITE"

* Sample lines: colour mask, row, column, string
samples fcb     TXGREEN,12,0
        fdb     sm1
        fcb     TXGREEN,13,0
        fdb     sm2
        fcb     TXGREEN,14,0
        fdb     sm3
        fcb     TXRED,15,0
        fdb     sm4
        fcb     TXBLUE,16,0
        fdb     sm5
        fcb     TXGREEN,17,0
        fdb     sm6
        fcb     TXGREEN,19,0
        fdb     sm7
        fcb     TXGREEN,21,0
        fdb     sm8
        fcb     TXBLUE,23,0
        fdb     sm9
        fcb     0

sm1     fcn     "YOU DESCEND INTO THE CRYPTS OF VAEL."
sm2     fcn     "SOMEWHERE BELOW, THE HOLLOW KING GUARDS"
sm3     fcn     "THE EMBER CROWN."
sm4     fcn     "THE SKELETON HITS YOU FOR 5! (HP 95)"
sm5     fcn     "YOU SEE AN OIL LANTERN [LEFT HAND]."
sm6     fcn     "TRY: PULL LEFT TORCH, USE LEFT"
sm7     fcc     "HP 100/100 "
        fcb     CH_BULLET
        fcc     " DEPTH 1 "
        fcb     CH_BULLET
        fcn     " 0:00"
sm8     fcc     "> PULL LEFT TORCH"
        fcb     CH_CURSOR,0
sm9     fcn     "0123456789 +-=/%:;'?!()<>#$&*"

