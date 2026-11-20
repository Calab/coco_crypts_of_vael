* Attack pictures: one frame of the reference's drawSwing (your blow) and drawStrike (a monster's),
* drawn over the corridor view and held for a moment (FXHOLD), then the view is redrawn without it.
* The pictures are in bank BANKSND (src/fxpics.asm, from tools/mkfx.py: already in screen terms and
* clipped to the view); each polyline is copied into ptbuf with that bank mapped, then drawn with
* BANKCOM back (the line routine needs its tables).

        ifndef  FXHOLD          ; (a test build can keep pictures up longer: -DFXHOLD=...)
FXHOLD  equ     15              ; ticks a picture stays up (the reference's swing lasts 0.3 s)
        endc

* fxswing: (from ATTACK) your blow with hand ch: the item in it swung, or a fist / shield thrust.
* The pictures are for the right hand; the left hand's is the mirror image.
fxswing ldx     #hands
        lda     ch
        ldb     a,x
        andb    #$7F
        cmpb    #$7F            ; empty
        bne     @k
        ldb     #FX_FIST
@k      tfr     b,a
        ldb     ch
        eorb    #1              ; flip for the left hand
        bra     fxset

* fxstrike: (from mattack) the monster at mp strikes from side mrel. A = 0 a hit, 1 a miss (faint),
* 2 a hit your shield blocked (sparks too). The reference sweeps the mark either way at random.
fxstrike
        pshs    a
        ldx     mp
        ldb     MKND,x
        ldx     #mstyle
        ldb     b,x
        stb     fxs             ; 0 claw, 1 blade, 2 crush
        lda     fxs
        lsla
        lsla
        adda    mrel
        adda    #FX_STRIKE      ; swept the first way: as stored
        pshs    a
        lbsr    rand
        tfr     a,b
        puls    a
        andb    #1
        beq     @set
        ldb     fxs             ; the other way: a crush looks the same
        cmpb    #2
        beq     @no
        ldb     mrel
        bitb    #1
        bne     @side
        ldb     #1              ; front or behind: flipped about the mark's centre
        bra     @set
@side   lda     fxs             ; a side: its own picture (a flip would run off the screen)
        lsla
        lsrb
        pshs    b
        adda    ,s+
        adda    #FX_STRIKE2
@no     clrb
@set    bsr     fxset
        puls    a
        cmpa    #1
        bne     @nf
        inc     fxfaint
@nf     cmpa    #2
        bne     @r
        lda     mrel
        adda    #FX_SPARK
        sta     fxpic2
@r      rts
mstyle  fcb     2,0,1,0,0,2,1   ; by monster kind (the reference's STRIKE_STYLE): crush, claw, blade, ...

* fxset: show picture A (flipped if B is nonzero) over the view from the next frame
fxset   tst     sleeping        ; (nothing to see while asleep)
        bne     @r
        sta     fxpic
        stb     fxflip
        clr     fxfaint
        lda     #$FF
        sta     fxpic2
        ldd     ticks
        addd    #FXHOLD
        std     fxuntil
        lda     #1
        sta     fxon
        sta     vdirty
@r      rts

* fxflash: (when you're hurt) the reference's flash, the view washed with colour for a moment. Here
* the black (palette entry 0) turns dim yellow for B ticks (Steve's colour; the reference's is its
* green): no drawing, so it costs nothing.
FLASHRGB equ    $06             ; dim yellow on RGB (low red + low green)
FLASHCMP equ    $04             ; composite: low intensity, hue 4 (between green 2 and red 7)
fxflash tst     sleeping
        bne     @r
        clra
        addd    ticks
        std     flashend
        lda     #FLASHRGB
        ldb     monitor
        cmpb    #'C
        bne     @c
        lda     #FLASHCMP
@c      sta     PALETTE
        sta     flashon
@r      rts

* flashoff: the black back (before a tune, which stops the main loop)
flashoff
        tst     flashon
        beq     @r
        clr     flashon
        lda     palsh
        sta     PALETTE
@r      rts

* fxtick: (main loop) take the flash and the picture down when their time is up
fxtick  tst     flashon
        beq     @p
        ldd     ticks
        subd    flashend
        bmi     @p
        bsr     flashoff
@p      tst     fxon
        beq     @r
        ldd     ticks
        subd    fxuntil
        bmi     @r
        clr     fxon
        lda     #1
        sta     vdirty
@r      rts

* fxdraw: (drawframe, after the corridor) the picture, if one is up
fxdraw  tst     fxon
        beq     @r
        lda     fxpic
        ldb     fxflip
        bsr     fxpic1
        lda     fxpic2
        cmpa    #$FF
        beq     @r
        clr     fxfaint
        clrb
        bsr     fxpic1
@r      rts

* fxpic1: draw picture A, flipped (x = M - x) if B is nonzero
fxpic1  stb     fxfl
        lsla
        ldb     #BANKSND
        stb     MMUT0+6
        ldx     #FXTAB
        ldx     a,x
        ldd     ,x++
        std     fxm
@poly   ldb     #BANKSND
        stb     MMUT0+6
        lda     ,x+             ; points (0: the end)
        beq     @done
        sta     fxn
        sta     fxc
        ldd     ,x++
        sta     fxcol
        stb     fxpat
        ldu     #ptbuf
@pt     ldb     ,x+             ; x / 2.5 -> x
        lda     #5
        mul
        lsra
        rorb
        tst     fxfl
        beq     @nf
        std     fxt
        ldd     fxm
        subd    fxt
@nf     std     ,u++
        lda     ,x+
        sta     ,u+
        dec     fxc
        bne     @pt
        stx     fxp
        lda     #BANKCOM
        sta     MMUT0+6
        lda     fxcol
        lbsr    setcol
        lda     fxpat
        tst     fxfaint         ; a miss: faint
        beq     @pat
        lda     #$88
@pat    lbsr    setpat
        ldu     #ptbuf
        dec     fxn             ; (segments: one fewer than points)
@seg    ldd     ,u
        std     <lx0
        lda     2,u
        sta     <ly0
        ldd     3,u
        std     <lx1
        lda     5,u
        sta     <ly1
        pshs    u
        lbsr    line
        puls    u
        leau    3,u
        dec     fxn
        bne     @seg
        ldx     fxp
        bra     @poly
@done   lda     #BANKCOM
        sta     MMUT0+6
        rts

flashon fcb     0               ; the hurt flash is on
flashend fdb    0
fxon    fcb     0               ; a picture is up
fxpic   fcb     0
fxflip  fcb     0
fxpic2  fcb     $FF             ; a second picture (sparks), $FF none
fxfaint fcb     0
fxuntil fdb     0
fxs     fcb     0
fxfl    fcb     0
fxm     fdb     0
fxn     fcb     0
fxc     fcb     0
fxcol   fcb     0
fxpat   fcb     0
fxt     fdb     0
fxp     fdb     0
