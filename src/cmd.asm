* The command line: typing, editing and the command parser (the reference's exec).
*
*   editkey  A = key from getkey. Edits the line; ENTER runs it (an empty line repeats the last
*            command during play). Sets vdirty when the view needs redrawing.
*
* Words match the reference's way: a word may be shortened to any prefix, and the first verb in
* the list that fits wins. Some must be typed in full (REVEAL, QUIT, XXX and the X test commands).

ILMAX   equ     37              ; longest line: "> " + 37 + cursor = 40 columns
MAXTOK  equ     8

editkey cmpa    #KCR
        lbeq    @enter
        cmpa    #KBS
        bne     @notbs
        tst     ilen
        beq     @ret
        dec     ilen
        bra     @dirty
@notbs  cmpa    #KCLR
        beq     @wipe
        cmpa    #KBRK
        beq     @wipe
        cmpa    #$20            ; printable: $20-$5F
        blo     @ret
        cmpa    #$5F
        bhi     @ret
        ldb     ilen
        cmpb    #ILMAX
        bhs     @ret
        ldx     #iline
        sta     b,x
        inc     ilen
@dirty  lda     #1
        sta     cmddirty
@ret    rts
@wipe   clr     ilen
        bra     @dirty
@enter  ldb     ilen            ; the line, zero-terminated
        ldx     #iline
        clr     b,x
        lda     gmode
        cmpa    #1
        bne     @run            ; on the title an empty line means a random seed; after the end, nothing
        tstb
        bne     @keep
        ldx     #lastcmd        ; empty: repeat the last command
        ldu     #iline
@rep    lda     ,x+
        sta     ,u+
        bne     @rep
        bra     @run
@keep   ldx     #iline          ; remember it
        ldu     #lastcmd
@save   lda     ,x+
        sta     ,u+
        bne     @save
@run    clr     ilen
        lda     #1
        sta     cmddirty
        lda     gmode
        lbeq    titlecmd
        cmpa    #2
        lbeq    overcmd
        lbra    docmd

* overcmd: after the game ends only RESTART (or QUIT) does anything, as the reference
overcmd lbsr    tokenize
        tst     ntok
        beq     @ret
        clra
        ldu     #w_restart
        lbsr    tokfull
        beq     @title
        clra
        ldu     #w_quit
        lbsr    tokfull
        beq     @title
        clra                    ; EXAMINE (abbreviated as usual): your pack and numbers (Steve);
        ldu     #verbs          ;   LOOK: back; REVEAL still works too, as the hidden test view
        lbsr    matchw
        cmpa    #V_EXAMINE
        lbeq    c_examine
        cmpa    #V_LOOK
        beq     @look
        cmpa    #V_REVEAL
        lbeq    c_reveal
        ldy     #m_over
        lbra    msg
@look   clr     vmode
        lda     #1
        sta     vdirty
        sta     logdirty
        sta     statdirty
        rts
@title  lbra    title
@ret    rts

* tokfull: A = token number, U = word. EQ if the token is exactly that word.
tokfull lbsr    tokget
        tstb
        beq     @no
@c      lda     ,u+
        beq     @no
        cmpa    ,x+
        bne     @no
        decb
        bne     @c
        tst     ,u
        rts
@no     lda     #1
        rts

* verbname: A = verb number. X = its word (from the verbs table).
verbname
        ldx     #verbs
@e      tsta
        beq     @here
        leax    1,x             ; past the flag, then the word
@w      tst     ,x+
        bne     @w
        deca
        bra     @e
@here   leax    1,x
        rts

* tokenize: split iline into words (tokp = start, tokl = length; ntok = how many)
tokenize
        clr     ntok
        ldx     #iline
@skip   lda     ,x
        beq     @end
        cmpa    #$20
        bne     @word
        leax    1,x
        bra     @skip
@word   ldb     ntok
        cmpb    #MAXTOK
        bhs     @end
        lslb
        ldu     #tokp
        stx     b,u
        clrb
@chars  lda     ,x
        beq     @wend
        cmpa    #$20
        beq     @wend
        incb
        leax    1,x
        bra     @chars
@wend   pshs    b
        ldb     ntok
        ldu     #tokl
        puls    a
        sta     b,u
        inc     ntok
        bra     @skip
@end    rts

* tokget: A = token number. Returns X = its start, B = its length (0 if there's no such token).
tokget  cmpa    ntok
        bhs     @none
        ldx     #tokl
        ldb     a,x
        pshs    b
        lsla
        ldx     #tokp
        ldx     a,x
        puls    b,pc
@none   clrb
        ldx     #iline
        rts

* tokis: A = token number, U = a word (zero-terminated). EQ if the token is a non-empty prefix of
* the word ("B" and "BACK" both fit "BACK").
tokis   pshs    d,x,u
        bsr     tokget
        tstb
        beq     @no
@cmp    lda     ,u+
        beq     @no             ; token is longer than the word
        cmpa    ,x+
        bne     @no
        decb
        bne     @cmp
        clra                    ; EQ
        puls    d,x,u,pc
@no     lda     #1              ; NE
        puls    d,x,u,pc

* matchw: A = token number, U = word table (entries: flag, word, 0; flag 1 = must be typed in full;
* the table ends with $FF). Returns A = index of the first word that fits, or $FF.
matchw  pshs    b,x,u
        bsr     tokget
        stx     mwtok
        stb     mwlen
        clr     mwi
        tstb
        beq     @none
@entry  lda     ,u+
        cmpa    #$FF
        beq     @none
        sta     mwfull
        ldx     mwtok
        ldb     mwlen
        pshs    u
@cmp    lda     ,u+
        beq     @fail           ; word shorter than the token
        cmpa    ,x+
        bne     @fail
        decb
        bne     @cmp
        tst     mwfull          ; full-word-only: the word must end here too
        beq     @hit
        tst     ,u
        bne     @fail
@hit    puls    u
        lda     mwi
        puls    b,x,u,pc
@fail   puls    u
@tail   lda     ,u+             ; skip the rest of this word
        bne     @tail
        inc     mwi
        bra     @entry
@none   lda     #$FF
        puls    b,x,u,pc

* handarg: token 1 as LEFT (A = 0) or RIGHT (A = 1), else A = $FF
handarg ldu     #w_left
        lda     #1
        bsr     tokis
        bne     @r
        clra
        rts
@r      ldu     #w_right
        lda     #1
        bsr     tokis
        bne     @no
        lda     #1
        rts
@no     lda     #$FF
        rts

* ---- the title: whatever is typed is the seed (blank = random) ----
titlecmd
        ldx     #iline          ; trim spaces at both ends, as the reference's trim()
@lead   lda     ,x
        cmpa    #$20
        bne     @trail
        leax    1,x
        bra     @lead
@trail  tfr     x,u             ; find the end
@end    lda     ,u+
        bne     @end
        leau    -1,u
@back   cmpu    #iline
        bls     @trimmed
        pshs    u
        cmpx    ,s++
        bhs     @trimmed
        lda     -1,u
        cmpa    #$20
        bne     @trimmed
        clr     ,-u
        bra     @back
@trimmed
        tst     ,x
        bne     @given
        lbsr    randseed
        bra     @go
@given  lbsr    parseseed       ; X = the seed text
        ldd     pseed
        std     seed
        ldd     pseed+2
        std     seed+2
@go     lbra    newgame

* ---- during play ----
docmd   lbsr    tokenize
        tst     ntok
        bne     @some
        rts
@some   tst     paused          ; any command un-pauses; a bare PAUSE just resumes
        beq     @nopause
        clr     paused
        lda     #1              ; redraw the view without "PAUSED"
        sta     vdirty
        ldy     #m_resumed
        lbsr    msg
        clra
        ldu     #verbs
        lbsr    matchw
        cmpa    #V_PAUSE
        bne     @nopause
        rts
@nopause
        tst     fainted         ; out cold: nothing you type does anything
        beq     @awake
        ldy     #m_uncon
        lbra    msg
@awake  lda     pending         ; waiting for Y or N?
        lbne    answer
* A new seed: a bare number, or SEED with something after it
        lda     ntok
        cmpa    #1
        bne     @seedw
        clra
        lbsr    tokget
@digits lda     ,x+             ; all digits?
        cmpa    #'0
        blo     @verb
        cmpa    #'9
        bhi     @verb
        decb
        bne     @digits
        clra
        lbsr    tokget
        lbsr    tokcopy         ; sbuf = the number
        bra     @askseed
@seedw  clra                    ; SEED (at least SE) followed by words: the words, single-spaced
        lbsr    tokget
        cmpb    #2
        blo     @verb
        ldu     #w_seed
        clra
        lbsr    tokis
        bne     @verb
        lbsr    joinargs
@askseed
        ldx     #sbuf
        lbsr    parseseed       ; the current game keeps its seed until the answer is Y
        ldd     pseed
        std     newseed
        ldd     pseed+2
        std     newseed+2
        lda     #1              ; ask in the middle of the view (drawframe's overlay)
        sta     pending
        sta     vdirty
        rts
@verb   clra
        ldu     #verbs
        lbsr    matchw
        cmpa    #$FF
        bne     @known
        ldy     #m_what
        lbra    msg
@known  sta     curverb
        lsla
        ldx     #vjump
        jmp     [a,x]

* answer: Y or N to "start over?" (pending 1) or "quit?" (pending 2)
answer  ldu     #w_yes
        clra
        lbsr    tokis
        beq     @yes
        ldu     #w_no
        clra
        lbsr    tokis
        beq     @no
        lda     pending         ; neither: ask again
        cmpa    #2
        beq     @askq
        lbsr    mbstart
        ldx     #m_startover
        lbsr    mbstr
        lbsr    mbnewseed
        ldx     #m_answeryn
        lbsr    mbstr
        lbra    mbsend
@askq   ldy     #m_quityn
        lbra    msg
@yes    lda     pending
        clr     pending
        cmpa    #2
        lbeq    title
        ldd     newseed
        std     seed
        ldd     newseed+2
        std     seed+2
        lbra    newgame
@no     lda     pending
        clr     pending
        ldb     #1              ; redraw the view without the question
        stb     vdirty
        ldy     #m_stay
        cmpa    #2
        bne     @say
        ldy     #m_presson
@say    lbra    msg

* mbnewseed: add the seed being asked about to the message being built
mbnewseed
        ldd     newseed
        std     num32
        ldd     newseed+2
        std     num32+2
        lbra    mbnum32

* tokcopy: X = text, B = length: copy to sbuf, zero-terminated
tokcopy ldu     #sbuf
@c      lda     ,x+
        sta     ,u+
        decb
        bne     @c
        clr     ,u
        rts

* joinargs: sbuf = tokens 1, 2, ... joined with single spaces (the reference's t.slice(1).join(' '))
joinargs
        ldu     #sbuf
        lda     #1
@tok    cmpa    ntok
        bhs     @end
        pshs    a
        lbsr    tokget
@c      lda     ,x+
        sta     ,u+
        cmpu    #sbuf+45
        bhs     @full
        decb
        bne     @c
        lda     #$20
        sta     ,u+
@full   puls    a
        inca
        bra     @tok
@end    cmpu    #sbuf
        beq     @z
        leau    -1,u            ; drop the last space
@z      clr     ,u
        rts

* ---- the commands (V_ numbers are positions in the verbs table) ----
V_PAUSE equ     13
V_REVEAL equ    1
V_LOOK  equ     9
V_EXAMINE equ   10

vjump   fdb     c_move,c_reveal,c_turn,c_attack,c_get,c_drop,c_stow,c_pull
        fdb     c_use,c_look,c_examine,c_descend,c_ascend,c_pause,c_quit,c_notyet
        fdb     c_notyet,c_notyet,c_seed,c_monitor,c_xxx,c_xlight,c_xjump,c_xdepth
        fdb     c_xinfo

c_notyet
        ldy     #m_notyet
        lbra    msg

c_look  tst     vmode           ; LOOK puts a map away (the reference's LOOK)
        beq     @ret
        clr     vmode
        lda     #1
        sta     vdirty
        sta     logdirty
        sta     statdirty
@ret    rts

c_reveal
        lda     #2              ; the whole maze (the reference's test view)
        bra     showmap

showmap sta     vmode
        lda     #1
        sta     vdirty
        rts

c_move  lda     #1              ; forward, or BACK / LEFT / RIGHT
        ldu     #w_back
        lbsr    tokis
        beq     @back
        lbsr    handarg
        ldb     pdir
        cmpa    #$FF
        beq     @fwd
        tsta                    ; sideways steps are instant (A = 2)
        bne     @right
        addb    #3
        bra     @side
@right  incb
@side   andb    #3
        lda     #2
        bra     @go
@back   ldb     pdir            ; glide back (A = 1)
        addb    #2
        andb    #3
        lda     #1
        bra     @go
@fwd    clra                    ; glide forward (A = 0)
@go     sta     mvmode
        lda     vmode           ; moving puts away the pack view (not a map), as mapSafeView
        cmpa    #3
        bne     @go2
        clr     vmode
@go2    lda     mvmode
        lbsr    step
        tsta
        beq     @moved
        ldd     #3              ; walking into stone hurts: 2-4 (the reference's rnd(2, 4))
        lbsr    rndn
        addd    #2
        lbsr    hurt
        bne     @ouch
        ldy     #m_dash
        lbra    die
@ouch   ldy     #m_ouch
        lbra    msg
@moved  lbsr    exert           ; the step's cost (the reference's move: exert, then the rest)
        lda     gmode
        cmpa    #1
        bne     @ret
        ldd     stime
        std     lastmove
        lbsr    pbfs            ; steps from you, for the monsters
        lda     #1
        sta     vdirty
        lbsr    meetmon         ; the reference's move: the monster here, the items, the ladder
        lbsr    seehere
        lbsr    ondown
        bne     @ret
        ldy     #m_ladder
        lbra    msg
@ret    rts

c_turn  lda     vmode           ; turning puts away the pack view (not a map)
        cmpa    #3
        bne     @t0
        clr     vmode
@t0     lda     #1
        ldu     #w_around
        lbsr    tokis
        beq     @around
        ldu     #w_back
        lda     #1
        lbsr    tokis
        beq     @around
        lbsr    handarg
        cmpa    #$FF
        bne     @lr
        ldy     #m_turnwhich
        lbra    msg
@lr     ldb     #1              ; turn left (A = 0) or right (A = 1)
        tsta
        bne     @rq
        ldb     #-1
        lda     pdir
        adda    #3
        bra     @t
@rq     lda     pdir
        inca
@t      anda    #3
        lbsr    turn
        lda     #1
        sta     vdirty
        rts
@around lda     pdir            ; two right quarter turns, each panned, as the reference does
        inca
        anda    #3
        ldb     #1
        lbsr    turn
        lbsr    drawframe
        lda     pdir
        inca
        anda    #3
        ldb     #1
        lbsr    turn
        lda     #1
        sta     vdirty
        rts

c_descend
        lbsr    ondown
        beq     @go
        ldy     #m_nodown
        lbra    msg
@go     lda     mz_lvl
        inca
        clrb                    ; arrive at the start
        lbsr    enterlevel
        lbsr    mbstart
        ldx     #m_climbdown
        lbsr    mbstr
        clra
        ldb     mz_lvl
        lbsr    mbnum
        ldx     #m_dot
        lbsr    mbstr
        lbsr    mbsend
        lda     mz_lvl
        cmpa    #5
        bne     @ret
        ldy     #m_tomb
        lbra    msg
@ret    rts

c_ascend
        lbsr    onup
        beq     @go
        ldy     #m_noup
        lbra    msg
@go     lda     mz_lvl
        deca
        ldb     #1              ; arrive at the down ladder
        lbsr    enterlevel
        lbsr    mbstart
        ldx     #m_climbup
        lbsr    mbstr
        clra
        ldb     mz_lvl
        lbsr    mbnum
        ldx     #m_dot
        lbsr    mbstr
        lbra    mbsend

c_pause lda     #1              ; "PAUSED" goes in the middle of the view (overlay)
        sta     paused
        sta     vdirty
* depthseed: "DEPTH n   SEED n" as a message (shown on PAUSE, later on EXAMINE too)
depthseed
        lbsr    mbstart
        ldx     #s_depth
        lbsr    mbstr
        clra
        ldb     mz_lvl
        lbsr    mbnum
        ldx     #m_seedsp
        lbsr    mbstr
        ldd     seed
        std     num32
        ldd     seed+2
        std     num32+2
        lbsr    mbnum32
        lbra    mbsend

c_quit  lda     #2              ; ask in the middle of the view (drawframe's overlay)
        sta     pending
        lda     #1
        sta     vdirty
        rts

c_seed  lbsr    mbstart         ; (SEED with words after it was handled before the verbs)
        ldx     #m_mazeseed
        lbsr    mbstr
        ldd     seed
        std     num32
        ldd     seed+2
        std     num32+2
        lbsr    mbnum32
        lbra    mbsend

c_monitor
        lda     #1
        ldu     #w_rgb
        lbsr    tokis
        beq     @rgb
        lda     #1
        ldu     #w_composite
        lbsr    tokis
        beq     @cmp
        ldy     #m_monwhich
        lbra    msg
@rgb    lda     #'R
        ldx     #rgbpal
        ldy     #m_monrgb
        bra     @set
@cmp    lda     #'C
        ldx     #cmppal
        ldy     #m_moncmp
@set    sta     monitor
        lbsr    setpal
        lbra    msg

* Test commands (typed in full)
c_xlight
        ldx     #lightnext      ; lantern -> torch -> none -> lantern (that burns for 999 s)
        ldb     vlight
        lda     b,x
        bne     @lit
        lbsr    lightoff
        bra     @set
@lit    sta     vlight
        ldb     #K_TORCH
        cmpa    #4
        beq     @k
        ldb     #K_LANTERN
@k      stb     lkind
        ldd     #999
        std     lrem
        lbsr    lightrange
@set    lda     #1
        sta     vdirty
        ldy     #m_lant
        lda     vlight
        cmpa    #7
        beq     @say
        ldy     #m_torch
        cmpa    #4
        beq     @say
        ldy     #m_none
@say    lbra    msg

c_xjump lbsr    jump
        lbsr    pbfs
        lda     #1
        sta     vdirty
        rts

c_xdepth
        lda     #1              ; XDEPTH n: build level n and stand at its start
        lbsr    tokget
        cmpb    #1
        bne     @bad
        lda     ,x
        suba    #'0
        cmpa    #1
        blo     @bad
        cmpa    #5
        bhi     @bad
        clrb
        lbra    enterlevel
@bad    ldy     #m_xdepth
        lbra    msg

c_xinfo lbsr    mbstart         ; AT x,y FACING dir. DRAW n/60 SEC.
        ldx     #m_at
        lbsr    mbstr
        clra
        ldb     px
        lbsr    mbnum
        ldx     #m_comma
        lbsr    mbstr
        clra
        ldb     py
        lbsr    mbnum
        ldx     #m_facing
        lbsr    mbstr
        ldb     pdir
        lda     #6
        mul
        addd    #dirname
        tfr     d,x
        lbsr    mbstr
        ldx     #m_draw
        lbsr    mbstr
        ldd     lastdraw
        lbsr    mbnum
        ldx     #m_sixty
        lbsr    mbstr
        lbra    mbsend

* meetmon: "YOU ARE FACE TO FACE WITH THE BONE HOUND!" (or "THE ... SLEEPS RIGHT HERE.") if a
* monster shares your new cell
meetmon ldd     px
        lbsr    monat
        bne     @ret
        lda     8,x
        pshs    a
        lbsr    mbstart
        puls    a
        bita    #MF_DORMANT
        bne     @asleep
        ldx     #m_face
        lbsr    mbstr
        lbsr    mbmon
        ldx     #m_bang
        bra     @end
@asleep ldx     #m_the
        lbsr    mbstr
        lbsr    mbmon
        ldx     #m_sleeps
@end    lbsr    mbstr
        lbra    mbsend
@ret    rts

* mbmon: B = monster kind: add its name to the message being built
mbmon   lslb
        ldx     #mnames
        ldx     b,x
        lbra    mbstr

* seehere: "YOU SEE A DAGGER, AN OIL LANTERN HERE." for the items where you stand (the reference's move)
seehere ldx     #items
        lda     nitems
        beq     @ret
        sta     shl
        clr     shn
@each   ldd     ,x
        cmpd    px
        bne     @skip
        pshs    x
        tst     shn             ; the first: start the message; later ones: a comma first
        bne     @more
        lbsr    mbstart
        ldx     #m_yousee
        lbsr    mbstr
        bra     @name
@more   ldx     #m_listsep
        lbsr    mbstr
@name   inc     shn
        ldx     ,s
        ldb     2,x
        lbsr    aname
        puls    x
@skip   leax    ITEMREC,x
        dec     shl
        bne     @each
        tst     shn
        beq     @ret
        ldx     #m_here
        lbsr    mbstr
        lbra    mbsend
@ret    rts

* aname: B = item kind. Adds "A name" or "AN name" (before a vowel) to the message being built.
aname   andb    #$7F
        lslb
        ldx     #inames
        ldx     b,x
        lda     ,x
        pshs    x
        ldx     #m_an
        cmpa    #'A
        beq     @art
        cmpa    #'E
        beq     @art
        cmpa    #'I
        beq     @art
        cmpa    #'O
        beq     @art
        cmpa    #'U
        beq     @art
        ldx     #m_a
@art    lbsr    mbstr
        puls    x
        lbra    mbstr

shl     fcb     0
shn     fcb     0

* ondown / onup: EQ if you're standing on the down ladder (levels 1-4) / up ladder (levels 2-5)
ondown  lda     mz_lvl
        cmpa    #5
        bhs     @no
        ldd     px
        cmpa    farx
        bne     @ret
        cmpb    fary
@ret    rts
@no     lda     #1              ; NE
        rts

onup    lda     mz_lvl
        cmpa    #1
        beq     @no
        ldd     px
        cmpd    #$0101
        rts
@no     lda     #1              ; NE
        rts

* ---- seeds ----
* parseseed: X = seed text. All digits: the number mod 2^32. Otherwise the FNV-1a hash of the
* text (already upper case), as the reference's parseSeed. Result in pseed.
parseseed
        pshs    x
@dig    lda     ,x+             ; all digits?
        beq     @number
        cmpa    #'0
        blo     @text
        cmpa    #'9
        bls     @dig
@text   puls    x
        ldd     #$811C          ; h = 2166136261
        std     pseed
        ldd     #$9DC5
        std     pseed+2
@char   lda     ,x+
        beq     @done
        eora    pseed+3         ; h ^= character
        sta     pseed+3
        pshs    x
        ldd     pseed           ; h = imul(h, 16777619)
        std     m_x
        ldd     pseed+2
        std     m_x+2
        ldd     #$0100
        std     m_y
        ldd     #$0193
        std     m_y+2
        lbsr    imul32
        ldd     m_res
        std     pseed
        ldd     m_res+2
        std     pseed+2
        puls    x
        bra     @char
@number puls    x               ; value = value * 10 + digit, all mod 2^32
        ldd     #0
        std     pseed
        std     pseed+2
@ndig   lda     ,x+
        beq     @done
        suba    #'0
        pshs    a,x
        ldd     pseed
        std     m_x
        ldd     pseed+2
        std     m_x+2
        ldd     #0
        std     m_y
        ldd     #10
        std     m_y+2
        lbsr    imul32
        puls    a,x
        tfr     a,b
        clra
        addd    m_res+2
        std     pseed+2
        ldd     m_res
        adcb    #0
        adca    #0
        std     pseed
        bra     @ndig
@done   rts

* randseed: a random seed from 100000 to 999999, as the reference's blank seed. The timing of
* key presses (spin) and the frame counter are the randomness.
randseed
        ldd     spin
        std     rngst
        ldd     ticks
        std     rngst+2
        ldd     #900            ; a = 0..899, b = 0..999: seed = 100000 + a*1000 + b
        lbsr    rndn
        std     m_x+2
        ldd     #0
        std     m_x
        std     m_y
        ldd     #1000
        std     m_y+2
        lbsr    imul32
        ldd     m_res           ; keep a*1000: rndn's RNG step reuses the multiply area
        std     seed
        ldd     m_res+2
        std     seed+2
        ldd     #1000
        lbsr    rndn
        addd    seed+2
        std     seed+2
        ldd     seed
        adcb    #0
        adca    #0
        std     seed
        ldd     seed+2          ; + 100000 ($186A0)
        addd    #$86A0
        std     seed+2
        ldd     seed
        adcb    #$01
        adca    #0
        std     seed
        rts

* Variables
iline   fill    0,ILMAX+1       ; the line being typed
ilen    fcb     0
lastcmd fill    0,ILMAX+1       ; the last command entered (an empty ENTER repeats it)
ntok    fcb     0
tokp    fill    0,2*MAXTOK
tokl    fill    0,MAXTOK
mwtok   fdb     0
mwlen   fcb     0
mwi     fcb     0
mwfull  fcb     0
pending fcb     0               ; waiting for Y/N: 1 start over in a new maze, 2 quit
newseed fqb     0               ; the seed being asked about
pseed   fqb     0               ; parseseed's result
paused  fcb     0
vdirty  fcb     0               ; the view needs redrawing
gmode   fcb     0               ; 0 title, 1 playing, 2 the game is over
spin    fdb     0               ; counts while waiting for keys (randomness for a blank seed)
mvmode  fcb     0               ; c_move: glide forward / back / sideways

* overlay: the Y/N question in the middle of the view, drawn on the page being drawn after the view
* (the reference's dark box with the question and its two answers)
overlay lda     #TXGREEN
        sta     textmask
        clr     obuf
        lda     #6              ; clear a band across the middle: text rows 6-11
@clr    pshs    a
        ldy     #obuf
        lbsr    rowstr
        puls    a
        inca
        cmpa    #12
        blo     @clr
        ldu     #obuf           ; the question
        lda     pending
        beq     @pause
        cmpa    #2
        beq     @quit
        ldx     #o_start
        lbsr    strcpy
        ldd     newseed
        std     num32
        ldd     newseed+2
        std     num32+2
        lbsr    numstr32
        lda     #'?
        sta     ,u+
        clr     ,u
        ldx     #o_starty
        ldy     #o_startn
        bra     @show
@quit   ldx     #o_quit
        lbsr    strcpy
        clr     ,u
        ldx     #o_quity
        ldy     #o_quitn
        bra     @show
@pause  lda     #7              ; PAUSED, and how to carry on
        ldy     #o_paused
        bsr     center
        lda     #9
        ldy     #o_resume
        bra     center
@show   pshs    x,y
        lda     #7
        ldy     #obuf
        bsr     center
        puls    x,y             ; the answers, lined up under each other, centred as a pair
        pshs    y
        tfr     y,u
        lbsr    slen            ; B = the longer of the two
        stb     ,-s
        tfr     x,u
        lbsr    slen
        cmpb    ,s+
        bhs     @wide
        ldb     -1,s
@wide   negb
        addb    #40
        lsrb
        pshs    b
        tfr     x,y
        lda     #9
        lbsr    textpos
        lbsr    puts
        puls    b
        puls    y
        lda     #10
        lbsr    textpos
        lbra    puts

* center: A = text row, Y = string. Draws it centred.
center  pshs    a
        tfr     y,u
        bsr     slen
        negb
        addb    #40
        lsrb
        puls    a
        lbsr    textpos
        lbra    puts

* slen: U = string. B = its length. Uses A.
slen    clrb
@n      lda     b,u
        beq     @end
        incb
        bra     @n
@end    rts

obuf    fill    0,42
