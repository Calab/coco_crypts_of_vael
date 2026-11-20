* HELP: the commands on a full screen (view mode 4), as the reference's renderHelp. LOOK or an empty
* ENTER (editkey in cmd.asm, Steve) puts it away,
* so does moving or turning (as the pack view); it covers the message log and status rows like a map.
* The text is in bank BANKSND (src/helptext.asm); each line is copied into sbuf, then printed with
* BANKCOM mapped (the font).
HELPTAB equ     $DD40           ; (src/bank3e.asm)

c_help  lda     #4
        sta     vmode
        sta     vdirty
        rts

* helpdraw: (drawframe) the help screen
helpdraw
        lbsr    clrfull
        ldy     #HELPTAB
        clr     hrow
@line   lda     #BANKSND        ; the next line, into sbuf
        sta     MMUT0+6
        ldu     #sbuf
@cp     lda     ,y+
        sta     ,u+
        bne     @cp
        sty     hptr
        lda     #BANKCOM
        sta     MMUT0+6
        lda     sbuf
        cmpa    #$FF
        beq     @done
        lda     hrow
        clrb
        lbsr    textpos
        lda     #TXGREEN
        sta     textmask
        ldu     #sbuf
@ch     lda     ,u+
        beq     @next
        cmpa    #'{             ; heading colour
        bne     @t
@blue   ldb     #TXBLUE
        stb     textmask
        bra     @ch
@t      cmpa    #'~             ; the note: column 24
        bne     @b
        lda     hrow
        ldb     #24
        lbsr    textpos
        bra     @blue
@b      cmpa    #'|
        bne     @p
        lda     #$62            ; (the font's BAR)
@p      lbsr    putc
        leax    4,x
        bra     @ch
@next   inc     hrow
        ldy     hptr
        bra     @line
@done   rts
hrow    fcb     0
hptr    fdb     0
