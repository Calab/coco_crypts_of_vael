* Messages and the text rows under the view.
*
*   rows 17-20  message log: the last 4 lines, word-wrapped to 40 columns. Lines from the latest two
*               messages are green, older ones light blue (the reference dims all but the last two).
*   rows 21-22  status: the hands, then health (paintstat, in items.asm)
*   row 23      command line
*
* Text rows are drawn on both screen pages (they don't change when the view flips). Changes only
* set a "dirty" flag; paintdirty redraws what changed.
*
*   msg      Y = zero-terminated message: add it to the log
*   mbstart / mbstr / mbnum / mbnum32 / mbsend   build a message with numbers in it
*   paintdirty   redraw the dirty text rows on both pages

LOGTOP  equ     17
LOGROWS equ     4
HANDROW equ     21              ; what's in each hand
STATROW equ     22              ; health
CMDROW  equ     23
LOGW    equ     41              ; bytes per log line (40 + terminator)

* msg: Y = zero-terminated message (up to 255 characters). Word-wraps it into the log.
msg     tst     sleeping        ; asleep: held back (the last three are kept, in sleeplog)
        lbne    sleepmsg
        pshs    d,x,y,u
        inc     msgcnt
@line   tfr     y,x             ; length of what's left
        clrb
@len    lda     ,x+
        beq     @lend
        incb
        bra     @len
@lend   cmpb    #40
        bls     @last
        ldb     #40             ; too long: break at the last space within 40 columns
@sp     lda     b,y
        cmpa    #$20
        beq     @brk
        decb
        bne     @sp
        ldb     #40             ; no space at all: break at 40
        bsr     pushline
        leay    b,y
        bra     @line
@brk    bsr     pushline        ; the line ends before the space; the next starts after it
        leay    b,y
        leay    1,y
        bra     @line
@last   tstb
        beq     @done
        bsr     pushline
@done   lda     #1
        sta     logdirty
        puls    d,x,y,u,pc

* sleepmsg: asleep: keep the message (up to 63 characters) in the next of three sleeplog slots
sleepmsg
        pshs    d,x,y
        lda     slhead
        ldb     #64
        mul
        addd    #sleeplog
        tfr     d,x
        ldb     #63
@copy   lda     ,y+
        sta     ,x+
        beq     @end
        decb
        bne     @copy
        clr     ,x
@end    lda     slhead
        inca
        cmpa    #3
        blo     @h
        clra
@h      sta     slhead
        lda     nslog
        cmpa    #3
        bhs     @n
        inc     nslog
@n      puls    d,x,y,pc

* pushline: Y = text, B = length (0-40). Scrolls the log up and adds the line at the bottom.
pushline
        pshs    d,x,y,u
        ldx     #logtxt         ; scroll the text: lines 1-4 -> 0-3
        ldu     #logtxt+LOGW
        ldb     #(LOGROWS-1)*LOGW
@scroll lda     ,u+
        sta     ,x+
        decb
        bne     @scroll
        ldx     #logage         ; and the ages
        ldb     #LOGROWS-1
@ages   lda     1,x
        sta     ,x+
        decb
        bne     @ages
        lda     msgcnt
        sta     ,x
        ldx     #logtxt+(LOGROWS-1)*LOGW
        ldb     1,s             ; length
        beq     @end
@copy   lda     ,y+
        sta     ,x+
        decb
        bne     @copy
@end    clr     ,x
        puls    d,x,y,u,pc

* logclear: empty the log
logclear
        pshs    d,x
        ldx     #logtxt
        ldb     #LOGROWS*LOGW
@clr    clr     ,x+
        decb
        bne     @clr
        lda     #1
        sta     logdirty
        puls    d,x,pc

* Message builder: mbstart, then any of mbstr (X = string), mbnum (D), mbnum32 (num32), then
* mbsend adds it to the log.
mbstart pshs    u
        ldu     #mbuf
        stu     mbp
        puls    u,pc
mbstr   pshs    a,x,u
        ldu     mbp
@copy   lda     ,x+
        beq     @end
        sta     ,u+
        bra     @copy
@end    stu     mbp
        puls    a,x,u,pc
mbnum   std     num32+2
        clr     num32
        clr     num32+1
mbnum32 pshs    u
        ldu     mbp
        lbsr    numstr32
        stu     mbp
        puls    u,pc
mbsend  pshs    y,u
        ldu     mbp
        clr     ,u
        ldy     #mbuf
        lbsr    msg
        puls    y,u,pc

* paintdirty: redraw the dirty text rows on both screen pages
paintdirty
        lda     logdirty
        ora     statdirty
        ora     cmddirty
        beq     @none
        lda     back            ; the page being drawn stays mapped afterwards
        pshs    a
        clra
        bsr     @page
        lda     #1
        bsr     @page
        puls    a
        lbsr    mappage
        clr     cmddirty
        lda     vmode
        cmpa    #1
        beq     @none
        cmpa    #2
        beq     @none
        clr     logdirty
        clr     statdirty
@none   rts
@page   lbsr    mappage
        lda     vmode           ; a map covers the log and status rows: they wait until it closes
        cmpa    #1
        beq     @nostat
        cmpa    #2
        beq     @nostat
        tst     logdirty
        beq     @nolog
        lbsr    paintlog
@nolog  tst     statdirty
        beq     @nostat
        lbsr    paintstat
@nostat tst     cmddirty
        beq     @nocmd
        lbsr    paintcmd
@nocmd  rts

paintlog
        ldy     #logtxt
        ldx     #logage
        lda     #LOGTOP
@row    pshs    a,x
        ldb     msgcnt          ; from the latest two messages: green; older: light blue
        subb    ,x
        cmpb    #2
        ldb     #TXGREEN
        blo     @col
        ldb     #TXBLUE
@col    stb     textmask
        lbsr    rowstr
        puls    a,x
        leay    LOGW,y
        leax    1,x
        inca
        cmpa    #LOGTOP+LOGROWS
        blo     @row
        rts

* strcpy: copy the zero-terminated string at X to U (without the terminator). U advances.
strcpy  lda     ,x+
        beq     @end
        sta     ,u+
        bra     strcpy
@end    rts

* paintcmd: "> " + what's typed + the cursor; on the title, a hint after the cursor while empty
paintcmd
        ldu     #sbuf
        lda     #'>
        sta     ,u+
        lda     #$20
        sta     ,u+
        ldx     #iline
        ldb     ilen
        beq     @cur
@copy   lda     ,x+
        sta     ,u+
        decb
        bne     @copy
@cur    lda     #CH_CURSOR
        sta     ,u+
        clr     ,u
        lda     #TXGREEN
        sta     textmask
        lda     #CMDROW
        ldy     #sbuf
        lbsr    rowstr
        tst     gmode           ; title with nothing typed: show the hint in blue after the cursor
        bne     @end
        tst     ilen
        bne     @end
        lda     #TXBLUE
        sta     textmask
        ldd     #(CMDROW<<8)|4
        lbsr    textpos
        ldy     #s_seedhint
        lbsr    puts
@end    rts

* Variables
logage  fill    0,LOGROWS
msgcnt  fcb     0
logdirty fcb    0
statdirty fcb   0
cmddirty fcb    0
sleeping fcb    0               ; SLEEP is running: messages go to sleeplog
nslog   fcb     0               ; how many are kept there (up to 3)
slhead  fcb     0               ; the slot the next one goes in
mbp     fdb     mbuf
mbuf    fill    0,128
sbuf    fill    0,48
