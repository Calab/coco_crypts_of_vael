* Keyboard.
*
* CoCo 3 matrix: column = PIA0B bit (write 0 to select), row = PIA0A bit (reads 0 when down).
*   row 0: @ A B C D E F G     row 4: 0 1 2 3 4 5 6 7
*   row 1: H I J K L M N O     row 5: 8 9 : ; , - . /
*   row 2: P Q R S T U V W     row 6: ENTER CLEAR BREAK ALT CTRL F1 F2 SHIFT
*   row 3: X Y Z up down left right space
*
* During play the 60 Hz interrupt calls kbscan, which reads all 8 columns and turns every key that
* has gone down since the last scan into a character code in a 16-byte buffer; getkey takes them
* out. Codes: printable ASCII, KCR (ENTER), KBS (left arrow), KCLR (SHIFT+left arrow or CLEAR),
* KBRK (BREAK). The other arrows, ALT, CTRL, F1, F2 and SHIFT give nothing for now.

KCR     equ     13
KBS     equ     8
KCLR    equ     21
KBRK    equ     3

* askmon: wait for R or C (polled; used before interrupts are on). Returns A = 'R' or 'C'.
askmon
monwait lda     #%11111011      ; column 2: R is in row 2
        sta     PIA0B
        lda     PIA0A
        bita    #%00000100
        beq     monr
        lda     #%11110111      ; column 3: C is in row 0
        sta     PIA0B
        lda     PIA0A
        bita    #%00000001
        beq     monc
        bra     monwait
monr    lda     #'R
        bra     mondone
monc    lda     #'C
mondone ldb     #$FF            ; deselect all columns
        stb     PIA0B
        rts

* kbscan: called from the IRQ. Uses all registers (the IRQ saves them).
kbscan  ldx     #kbprev
        lda     #$FE
        sta     kbcol
        clr     kbidx
@col    lda     kbcol
        sta     PIA0B
        lda     PIA0A
        ora     #$80            ; bit 7 is the joystick comparator, not a key
        tfr     a,b             ; B = now (0 = down)
        coma
        anda    ,x              ; A = keys up last time and down now
        stb     ,x+
        beq     @next
        clrb                    ; B = row
@row    lsra
        bcc     @nrow
        pshs    a,b,x
        lslb                    ; kmap index: row * 8 + column
        lslb
        lslb
        addb    kbidx
        ldx     #kmap
        lda     b,x
        beq     @skip
        cmpa    #KBS
        bne     @push
        ldb     kbprev+7        ; SHIFT held (column 7, row 6, last scan)? then it's "clear line"
        bitb    #$40
        bne     @push
        lda     #KCLR
@push   bsr     kbput
@skip   puls    a,b,x
@nrow   incb
        tsta
        bne     @row
@next   lda     kbcol           ; next column: $FE, $FD, $FB ... $7F
        lsla
        ora     #1
        sta     kbcol
        inc     kbidx
        lda     kbidx
        cmpa    #8
        blo     @col
        lda     #$FF
        sta     PIA0B
        rts

* kbput: A = character. Adds it to the buffer (dropped if the buffer is full).
kbput   ldb     kbhead
        incb
        andb    #15
        cmpb    kbtail
        beq     @full
        pshs    b
        ldb     kbhead
        ldx     #kbuf
        sta     b,x
        puls    b
        stb     kbhead
@full   rts

* getkey: A = next character, or 0 (and EQ) if none is waiting.
getkey
        ifdef   AUTOKEYS
        ldx     akeyp           ; testing: type the script instead ('/' = ENTER), stop at its end
        lda     ,x+
        lbeq    walkdone
        stx     akeyp
        cmpa    #'/
        bne     @key
        lda     #KCR
@key    rts
        else
        ldb     kbtail
        cmpb    kbhead
        beq     @none
        ldx     #kbuf
        lda     b,x
        incb
        andb    #15
        stb     kbtail
        tsta
        rts
@none   clra
        rts
        endc

* kbflush: forget anything typed so far
kbflush ldb     kbhead
        stb     kbtail
        rts

* Key codes by row and column
kmap    fcc     "@ABCDEFG"
        fcc     "HIJKLMNO"
        fcc     "PQRSTUVW"
        fcb     'X,'Y,'Z,0,0,KBS,0,$20
        fcc     "01234567"
        fcc     "89:;,-./"
        fcb     KCR,KCLR,KBRK,0,0,0,0,0

kbprev  fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; last scan, per column (0 = down)
kbcol   fcb     0
kbidx   fcb     0
kbhead  fcb     0
kbtail  fcb     0
kbuf    fill    0,16
