* Hands, pack, light, health and experience; the item commands (the reference's GET, DROP, STOW,
* PULL, USE, EXAMINE, applyUse, gainXP) and the pack view.
*
* An item is held as one byte: its kind (K_ numbers, maze.asm), plus $80 once it has given its
* pick-up XP (the reference's xpDone). Empty hand = $FF.

HANDE   equ     $FF             ; empty hand
PACKMAX equ     8
XPFLAG  equ     $80

* Item types, by kind (the reference's ITEMS types)
T_WEAPON equ    1
T_SHIELD equ    2
T_LIGHT  equ    3
T_POTION equ    4
T_MAP    equ    5
T_TREAS  equ    6
T_GOAL   equ    7
itype   fcb     T_WEAPON,T_WEAPON,T_WEAPON,T_WEAPON,T_WEAPON,T_SHIELD,T_SHIELD
        fcb     T_LIGHT,T_LIGHT,T_POTION,T_POTION,T_POTION,T_MAP,T_TREAS,T_GOAL

* newplayer: the reference's newGame: 100/100 health, empty hands, a torch and the map in the pack,
* no light
newplayer
        ldd     #100
        std     hp
        std     maxhp
        ldd     #0
        std     xp
        std     acc
        std     stime           ; and the simulation's clock and state
        std     fatig
        std     regen
        std     lasthurt
        std     lastmove
        std     nextwarn
        std     nextsound
        std     atkready
        std     atkready+2
        std     hbnext
        clr     hbbig
        sta     strain
        std     strain+1
        clr     fainted
        clr     lastrank
        clr     kills
        lda     #HANDE
        sta     hands
        sta     hands+1
        lda     #K_TORCH
        sta     pack
        lda     #K_MAP
        sta     pack+1
        lda     #2
        sta     npack
        lbra    lightoff

* ---- light ----
* lightoff: no light (you still see your own cell)
lightoff
        clr     vlight
        lda     #1
        sta     vrange
        lda     #HANDE
        sta     lkind
        rts

* lightrange: the reference's lightRange: the full range until the last 45 seconds, then
* ceil(range * seconds left / 45), at least 1. Sets vrange; NE if it changed.
lightrange
        lda     vrange
        pshs    a
        ldd     lrem
        cmpd    #45
        blo     @fade
        lda     vlight
        bra     @set
@fade   lda     vlight          ; (range * left + 44) / 45
        mul                     ; B = left (< 45), A = range: D = range * left
        addd    #44
        clr     ltmp45
@div    cmpd    #45
        blo     @q
        subd    #45
        inc     ltmp45
        bra     @div
@q      lda     ltmp45
        bne     @set
        inca
@set    sta     vrange
        cmpa    ,s+
        rts

* gameclock: called from the main loop. Counts real seconds of play (not while paused, asking Y/N
* or after the game ends) and burns the light.
gameclock
        ldd     ticks           ; ticks since last time
        pshs    d
        subd    lastt
        std     dtick
        puls    d
        std     lastt
        lda     gmode
        cmpa    #1
        bne     @ret
        tst     paused
        bne     @ret
        tst     pending
        bne     @ret
        ldd     stime           ; the play clock (monsters, healing, fatigue)
        addd    dtick
        std     stime
        ldd     acc
        addd    dtick
        std     acc
@sec    ldd     acc
        cmpd    #60
        blo     @ret
        subd    #60
        std     acc
        bsr     second
        bra     @sec
@ret    rts

* second: one second of play: the light burns
second  tst     vlight
        beq     @ret
        ldd     lrem
        subd    #1
        std     lrem
        bne     @burn
        lbsr    mbstart         ; "YOUR PITCH TORCH GUTTERS OUT. DARKNESS."
        ldx     #m_your
        lbsr    mbstr
        ldb     lkind
        lbsr    kname
        lbsr    mbstr
        ldx     #m_gutters
        lbsr    mbstr
        lbsr    mbsend
        lbsr    lightoff
        bra     @redraw
@burn   lbsr    lightrange
        beq     @ret
@redraw lda     #1
        sta     vdirty
@ret    rts

* ---- experience ----
* gainxp: D = XP. Rank = min(10, xp / 25); a new rank gets "YOU GROW MORE SKILLED!  (RANK n)".
gainxp  addd    xp
        std     xp
        bsr     rank
        cmpa    lastrank
        bls     @ret
        sta     lastrank
        lbsr    mbstart
        ldx     #m_skilled
        lbsr    mbstr
        tfr     a,b
        clra
        lbsr    mbnum
        ldx     #m_rparen
        lbsr    mbstr
        lbsr    mbsend
@ret    rts

* rank: A = min(10, xp / 25)
rank    ldd     xp
        clr     ltmp45
@div    cmpd    #25
        blo     @q
        subd    #25
        inc     ltmp45
        bra     @div
@q      lda     ltmp45
        cmpa    #10
        bls     @r
        lda     #10
@r      rts

* ---- health ----
* hurt: D = damage. Returns EQ if that killed you.
hurt    pshs    d
        ldd     hp
        subd    ,s++
        bgt     @alive
        ldd     #0
        std     hp
        lda     #1
        sta     statdirty
        clra                    ; EQ: dead
        rts
@alive  std     hp
        lda     #1
        sta     statdirty       ; NE
        rts

* die: Y = why. The reference's die: the end of the game; only RESTART (or QUIT) goes on.
die     lbsr    msg
        ldy     #m_perished
        lbsr    msg
        ldy     #m_restart
        lbsr    msg
        lda     #2
        sta     gmode
        clr     vmode
        lda     #1
        sta     vdirty
        rts

* ---- names and matching ----
* kname: B = item byte. X = its name.
kname   andb    #$7F
        lslb
        ldx     #inames
        ldx     b,x
        rts

* handname: A = hand. X = "LEFT" or "RIGHT".
handname
        ldx     #w_left
        tsta
        beq     @r
        ldx     #w_right
@r      rts

* itemmatch: B = item byte; tokens from tstart on are the words to match. EQ if every word starts
* one of the item's words or its kind word (the reference's itemMatches; no words matches anything).
itemmatch
        andb    #$7F
        stb     imk
        lda     tstart
@tok    cmpa    ntok
        bhs     @yes
        sta     itk
        lbsr    tokget
        stx     mtk
        stb     mtl
        ldb     imk
        lslb
        ldx     #inames
        ldx     b,x
        bsr     wordsin
        beq     @ok
        ldb     imk
        lslb
        ldx     #ikwords
        ldx     b,x
        bsr     wordsin
        beq     @ok
        lda     #1              ; NE
        rts
@ok     lda     itk
        inca
        bra     @tok
@yes    clra                    ; EQ
        rts

* wordsin: X = words separated by spaces. EQ if the token (mtk, mtl) starts one of them.
wordsin
@word   ldu     mtk
        ldb     mtl
        pshs    x
@c      lda     ,x
        beq     @fail
        cmpa    #$20
        beq     @fail
        cmpa    ,u+
        bne     @fail
        leax    1,x
        decb
        bne     @c
        puls    x
        clra                    ; EQ
        rts
@fail   puls    x
@skip   lda     ,x+
        beq     @no
        cmpa    #$20
        bne     @skip
        bra     @word
@no     lda     #1              ; NE
        rts

* needhand: token 1 as a hand. Returns A = 0 left, 1 right; or says "<VERB> LEFT OR RIGHT?" and
* returns C set.
needhand
        lbsr    handarg
        cmpa    #$FF
        beq     @ask
        andcc   #$FE
        rts
@ask    lbsr    mbstart
        lda     curverb
        lbsr    verbname
        lbsr    mbstr
        ldx     #m_leftright
        lbsr    mbstr
        lbsr    mbsend
        orcc    #1
        rts

* sayhand: message "<A> <hand> <B>": X = start, Y = end, A = hand ("YOUR " LEFT " HAND IS FULL.")
sayhand pshs    a,y
        lbsr    mbstart
        lbsr    mbstr
        lda     ,s
        lbsr    handname
        lbsr    mbstr
        puls    a,x
        lbsr    mbstr
        lbra    mbsend

* saything: message "<X><item name><Y>": B = item byte ("YOU DROP THE " DAGGER ".")
saything
        pshs    b,y
        lbsr    mbstart
        lbsr    mbstr
        ldb     ,s
        lbsr    kname
        lbsr    mbstr
        puls    b,x
        lbsr    mbstr
        lbra    mbsend

* saymon: message "<X><monster name><Y>": B = monster kind ("THE " SKELETON " IS IN THE WAY...")
saymon  pshs    b,y
        lbsr    mbstart
        lbsr    mbstr
        ldb     ,s
        lbsr    mbmon
        puls    b,x
        lbsr    mbstr
        lbra    mbsend

* ---- the commands ----
c_get   lbsr    needhand
        lbcs    @ret
        sta     ch
        ldx     #hands
        ldb     a,x
        cmpb    #HANDE
        beq     @free
        ldx     #m_your
        ldy     #m_handfull
        lbra    sayhand
@free   ldd     px              ; an item sharing a square with a monster can't be taken
        lbsr    monat
        bne     @clear
        ldx     #m_the
        ldy     #m_inway
        lbra    saymon
@clear  lda     #2              ; the first item here that fits the words after the hand
        sta     tstart
        ldx     #items
        lda     nitems
        beq     @none
        sta     gcnt
@find   stx     gptr
        ldd     ,x
        cmpd    px
        bne     @nf
        ldb     2,x
        lbsr    itemmatch
        beq     @take
@nf     ldx     gptr
        leax    ITEMREC,x
        dec     gcnt
        bne     @find
@none   ldb     pdir            ; is it under the monster ahead? (what monsters carry stays hidden)
        ldx     #dx1
        lda     b,x
        adda    px
        sta     gax
        ldx     #dy1
        lda     b,x
        adda    py
        sta     gay
        ldd     gax
        lbsr    monat
        bne     @nada
        stb     gmk
        ldx     #items
        lda     nitems
        beq     @nada
        sta     gcnt
@ahead  stx     gptr
        ldd     ,x
        cmpd    gax
        bne     @na
        ldb     2,x
        lbsr    itemmatch
        bne     @na
        ldb     gmk
        ldx     #m_the
        ldy     #m_guards
        lbra    saymon
@na     ldx     gptr
        leax    ITEMREC,x
        dec     gcnt
        bne     @ahead
@nada   ldy     #m_nothing
        lbra    msg
@take   ldx     gptr            ; off the floor...
        ldb     2,x
        stb     gkind
        lbsr    takeitem
        lda     ch              ; ...into your hand
        ldx     #hands
        ldb     gkind
        stb     a,x
        bitb    #XPFLAG         ; the first time anyone picks it up: XP (not the crown)
        bne     @said
        andb    #$7F
        ldx     #itype
        lda     b,x
        cmpa    #T_GOAL
        beq     @said
        ldb     gkind
        orb     #XPFLAG
        lda     ch
        ldx     #hands
        stb     a,x
        ldd     #3
        lbsr    gainxp
@said   lbsr    mbstart         ; "YOU TAKE THE DAGGER IN YOUR LEFT HAND."
        ldx     #m_youtake
        lbsr    mbstr
        ldb     gkind
        lbsr    kname
        lbsr    mbstr
        ldx     #m_inyour
        lbsr    mbstr
        lda     ch
        lbsr    handname
        lbsr    mbstr
        ldx     #m_handdot
        lbsr    mbstr
        lbsr    mbsend
        lda     #1
        sta     vdirty
        sta     statdirty
        lda     gkind           ; the crown: you've won
        anda    #$7F
        cmpa    #K_CROWN
        lbeq    win
@ret    rts

* takeitem: X = an item record on the floor. Removes it (the rest move down).
takeitem
        leau    ITEMREC,x
        pshs    x
        ldd     #items+MAXITEMS*ITEMREC
        pshs    d
@mv     cmpu    ,s
        bhs     @done
        lda     ,u+
        sta     ,x+
        bra     @mv
@done   leas    4,s
        dec     nitems
        rts

c_drop  lbsr    needhand
        bcs     @ret
        sta     ch
        ldx     #hands
        ldb     a,x
        cmpb    #HANDE
        bne     @drop
        ldx     #m_your
        ldy     #m_handempty
        lbra    sayhand
@drop   stb     ikind           ; onto the floor where you stand
        lda     #HANDE
        ldx     #hands
        pshs    b
        ldb     ch
        sta     b,x
        ldd     px
        lbsr    additem
        puls    b
        ldx     #m_youdrop
        ldy     #m_dot
        lbsr    saything
        lda     #1
        sta     vdirty
        sta     statdirty
@ret    rts

c_stow  lbsr    needhand
        bcs     @ret
        sta     ch
        ldx     #hands
        ldb     a,x
        cmpb    #HANDE
        bne     @have
        ldx     #m_your
        ldy     #m_handempty
        lbra    sayhand
@have   lda     npack
        cmpa    #PACKMAX
        blo     @room
        ldy     #m_packfull
        lbra    msg
@room   ldx     #pack
        stb     a,x
        inc     npack
        lda     #HANDE
        pshs    b
        ldb     ch
        ldx     #hands
        sta     b,x
        puls    b
        ldx     #m_youstow
        ldy     #m_dot
        lbsr    saything
        lda     #1
        sta     statdirty
        sta     vdirty          ; (the pack view, if it's open)
@ret    rts

c_pull  lbsr    needhand
        bcs     @ret
        sta     ch
        ldx     #hands
        ldb     a,x
        cmpb    #HANDE
        beq     @free
        ldx     #m_your
        ldy     #m_handfull
        lbra    sayhand
@free   lda     #2
        sta     tstart
        clr     gcnt
@find   lda     gcnt
        cmpa    npack
        bhs     @none
        ldx     #pack
        ldb     a,x
        lbsr    itemmatch
        beq     @pull
        inc     gcnt
        bra     @find
@none   ldy     #m_nosuch
        tst     npack
        bne     @say
        ldy     #m_packempty
@say    lbra    msg
@pull   lda     gcnt
        lbsr    packtake        ; B = the item
        lda     ch
        ldx     #hands
        stb     a,x
        ldx     #m_youpull
        ldy     #m_dot
        lbsr    saything
        lda     #1
        sta     statdirty
        sta     vdirty
@ret    rts

* packtake: A = pack slot. Returns B = that item, removed from the pack (the rest move down).
packtake
        ldx     #pack
        ldb     a,x
        pshs    b
@mv     inca
        cmpa    npack
        bhs     @done
        ldb     a,x
        deca
        stb     a,x
        inca
        bra     @mv
@done   dec     npack
        puls    b,pc

c_use   lbsr    handarg         ; USE LEFT / RIGHT
        cmpa    #$FF
        beq     @words
        sta     ch
        ldx     #hands
        ldb     a,x
        cmpb    #HANDE
        bne     @hand
        ldx     #m_your
        ldy     #m_handempty
        lbra    sayhand
@hand   clr     usewhere        ; consume: from the hand
        lbra    apply
@words  lda     ntok            ; USE <item name>
        cmpa    #2
        bhs     @find
        ldy     #m_usewhat
        lbra    msg
@find   lda     #1
        sta     tstart
        clr     ch              ; in your hands first
@hands  ldx     #hands
        lda     ch
        ldb     a,x
        cmpb    #HANDE
        beq     @nh
        lbsr    itemmatch
        beq     @hand2
@nh     inc     ch
        lda     ch
        cmpa    #2
        blo     @hands
        clr     gcnt            ; then your pack
@pk     lda     gcnt
        cmpa    npack
        bhs     @none
        ldx     #pack
        ldb     a,x
        lbsr    itemmatch
        beq     @inpack
        inc     gcnt
        bra     @pk
@none   ldy     #m_nousable
        lbra    msg
@hand2  ldx     #hands
        lda     ch
        ldb     a,x
        bra     @hand
@inpack lda     #1              ; consume: from the pack, slot gcnt
        sta     usewhere
        ldx     #pack
        lda     gcnt
        ldb     a,x
        lbra    apply

* apply: B = the item, usewhere = 0 (hand ch) or 1 (pack slot gcnt). The reference's applyUse.
apply   stb     gkind
        andb    #$7F
        ldx     #itype
        lda     b,x
        cmpa    #T_LIGHT
        beq     @light
        cmpa    #T_POTION
        lbeq    @potion
        cmpa    #T_TREAS
        lbeq    @treas
        cmpa    #T_MAP
        lbeq    @map
        cmpa    #T_GOAL
        beq     @nothing
        ldy     #m_fight        ; weapons and shields
        lbra    msg
@nothing
        ldy     #m_nothinghap
        lbra    msg
@light  lbsr    consume         ; it burns: torch 4 cells for 200 s, lantern 7 for 420 s
        lda     #4
        ldx     #200
        ldb     gkind
        andb    #$7F
        stb     lkind
        cmpb    #K_LANTERN
        bne     @lt
        lda     #7
        ldx     #420
@lt     sta     vlight
        stx     lrem
        lbsr    lightrange
        ldx     #m_the
        ldy     #m_flares
        ldb     gkind
        lbsr    saything
        lda     #1
        sta     vdirty
        rts
@potion bsr     consume
        ldb     gkind
        andb    #$7F
        cmpb    #K_VIGOR
        beq     @vigor
        ldx     #50             ; mending draught 50, healing herb 20
        cmpb    #K_MENDING
        beq     @heal
        ldx     #20
@heal   tfr     x,d
        addd    hp
        cmpd    maxhp
        bls     @hp
        ldd     maxhp
@hp     std     hp
        ldy     #m_warmth
        bra     @said
@vigor  ldd     maxhp           ; vigor tonic: 20 more health, and 20 more most health
        addd    #20
        std     maxhp
        ldd     hp
        addd    #20
        std     hp
        ldy     #m_stronger
@said   lda     #1
        sta     statdirty
        lbra    msg
@treas  bsr     consume         ; golden relic: 15 XP
        ldd     #15
        lbsr    gainxp
        ldy     #m_ancient
        lbra    msg
@map    lda     #1              ; YOUR MAP (it stays in your hand or pack)
        sta     vmode
        sta     vdirty
        ldy     #m_unfold
        lbra    msg

* consume: the item being used is gone, from the hand or the pack slot
consume lda     #1
        sta     statdirty
        sta     vdirty
        tst     usewhere
        bne     @pack
        lda     #HANDE
        ldb     ch
        ldx     #hands
        sta     b,x
        rts
@pack   lda     gcnt
        lbra    packtake

c_examine
        lda     #3              ; the pack view
        sta     vmode
        sta     vdirty
        rts

* ---- the pack view (EXAMINE): in the view area, as the reference's renderPack ----
packview
        lbsr    clrview
        lda     #TXGREEN
        sta     textmask
        lbsr    mbstart         ; YOUR PACK  (n/8)              ON THE FLOOR
        ldx     #m_yourpack
        lbsr    mbstr
        clra
        ldb     npack
        lbsr    mbnum
        ldx     #m_of8
        lbsr    mbstr
        ldu     mbp
        clr     ,u
        ldd     #(1<<8)|1
        ldy     #mbuf
        lbsr    printat
        ldd     #(1<<8)|21
        ldy     #m_floor
        lbsr    printat
        lda     #TXBLUE
        sta     textmask
        tst     npack           ; the pack, numbered
        bne     @list
        ldd     #(3<<8)|2
        ldy     #m_pempty
        lbsr    printat
        bra     @floor
@list   clr     gcnt
@pl     lda     gcnt
        cmpa    npack
        bhs     @floor
        lbsr    mbstart
        clra
        ldb     gcnt
        incb
        lbsr    mbnum
        ldx     #m_dotsp
        lbsr    mbstr
        ldx     #pack
        lda     gcnt
        ldb     a,x
        lbsr    kname
        lbsr    mbstr
        ldu     mbp
        clr     ,u
        lda     gcnt
        adda    #3
        ldb     #1
        ldy     #mbuf
        lbsr    printat
        inc     gcnt
        bra     @pl
@floor  lda     #3              ; what's on the floor here
        sta     prow
        ldx     #items
        lda     nitems
        beq     @fnone
        sta     gcnt
@fl     stx     gptr
        ldd     ,x
        cmpd    px
        bne     @fn
        lda     prow
        cmpa    #11
        bhs     @fn
        ldb     2,x
        lbsr    kname
        tfr     x,y
        lda     prow
        ldb     #21
        lbsr    printat
        inc     prow
@fn     ldx     gptr
        leax    ITEMREC,x
        dec     gcnt
        bne     @fl
@fnone  lda     prow
        cmpa    #3
        bne     @stats
        ldd     #(3<<8)|22
        ldy     #m_fnothing
        lbsr    printat
@stats  lda     #TXGREEN
        sta     textmask
        lbsr    mbstart         ; LIGHT: PITCH TORCH (120S)
        ldx     #m_light
        lbsr    mbstr
        tst     vlight
        bne     @lit
        ldx     #m_lnone
        lbsr    mbstr
        bra     @lsay
@lit    ldb     lkind
        lbsr    kname
        lbsr    mbstr
        ldx     #m_lparen
        lbsr    mbstr
        ldd     lrem
        lbsr    mbnum
        ldx     #m_secs
        lbsr    mbstr
@lsay   ldu     mbp
        clr     ,u
        ldd     #(12<<8)|1
        ldy     #mbuf
        lbsr    printat
        lbsr    mbstart         ; FACING NORTH   DEPTH 1   FOES SLAIN 0
        ldx     #m_facing2
        lbsr    mbstr
        ldb     pdir
        lda     #6
        mul
        addd    #dirname
        tfr     d,x
        lbsr    mbstr
        ldx     #m_depth3
        lbsr    mbstr
        clra
        ldb     mz_lvl
        lbsr    mbnum
        ldx     #m_slain
        lbsr    mbstr
        clra
        ldb     kills
        lbsr    mbnum
        ldu     mbp
        clr     ,u
        ldd     #(13<<8)|1
        ldy     #mbuf
        lbsr    printat
        lbsr    mbstart         ; RANK 0 (XP 0)   DMG +0   DODGE 0%
        ldx     #m_rank
        lbsr    mbstr
        lbsr    rank
        pshs    a
        tfr     a,b
        clra
        lbsr    mbnum
        ldx     #m_xp
        lbsr    mbstr
        ldd     xp
        lbsr    mbnum
        ldx     #m_dmg
        lbsr    mbstr
        clra
        ldb     ,s
        lbsr    mbnum
        ldx     #m_dodge
        lbsr    mbstr
        puls    a               ; dodge = min(50, rank * 5) %
        ldb     #5
        mul
        cmpb    #50
        bls     @dg
        ldb     #50
@dg     clra
        lbsr    mbnum
        ldx     #m_pct
        lbsr    mbstr
        ldu     mbp
        clr     ,u
        ldd     #(14<<8)|1
        ldy     #mbuf
        lbsr    printat
        lbsr    mbstart         ; SEED 12345
        ldx     #m_seedlbl
        lbsr    mbstr
        ldd     seed
        std     num32
        ldd     seed+2
        std     num32+2
        lbsr    mbnum32
        ldu     mbp
        clr     ,u
        ldd     #(15<<8)|1
        ldy     #mbuf
        lbsr    printat
        lda     #TXBLUE
        sta     textmask
        ldd     #(16<<8)|1
        ldy     #m_lookret
        lbra    printat

* ---- status rows: hands, health and the heart ----
* paintstat: row 21: "L: item" from the left, "R: item" ending at the right (held items light blue,
* empty hands green, as the reference's yellow / green), and in the middle the heart (columns 15-16,
* red) and HP (from column 17). An item name over 12 letters shows its kind word instead
* (none do now; MENDING BREW was renamed to fit). Row 22: WINDED / EXHAUSTED, centred. Blank on the title.
HEARTCOL equ    15
paintstat
        ldx     #sbuf
        clr     ,x
        lda     #TXGREEN
        sta     textmask
        lda     #HANDROW
        ldy     #sbuf
        lbsr    rowstr
        lda     #STATROW
        ldy     #sbuf
        lbsr    rowstr
        lda     gmode
        bne     @play
        rts
@play   clra                    ; left hand
        bsr     @hand
        lda     #1              ; right hand
        bsr     @hand
        lbsr    mbstart         ; HP
        ldd     hp
        lbsr    mbnum
        ldx     #m_slash
        lbsr    mbstr
        ldd     maxhp
        lbsr    mbnum
        ldu     mbp
        clr     ,u
        lda     #TXGREEN
        sta     textmask
        ldd     #(HANDROW<<8)|(HEARTCOL+2)
        ldy     #mbuf
        lbsr    printat
        lbsr    drawheart
        lbsr    fatlevel        ; row 22: WINDED / EXHAUSTED
        tsta
        beq     @ret
        ldy     #m_winded
        deca
        beq     @fw
        ldy     #m_exhausted
@fw     lda     #STATROW
        lbra    center
@ret    rts
@hand   sta     ch              ; A = hand: "L: name" / "R: name"
        lbsr    mbstart
        ldx     #m_lcolon
        tsta
        beq     @lr
        ldx     #m_rcolon
@lr     lbsr    mbstr
        ldx     #hands
        lda     ch
        ldb     a,x
        lda     #TXGREEN
        cmpb    #HANDE
        bne     @held
        ldx     #m_empty
        bra     @nm
@held   pshs    b
        lbsr    kname
        tfr     x,u             ; too long? the kind word
        lbsr    slen
        puls    b
        cmpb    #12
        bls     @full
        andb    #$7F
        lslb
        ldx     #ikwords
        ldx     b,x
@full   lda     #TXBLUE
@nm     sta     textmask
        lbsr    mbstr
        ldu     mbp
        clr     ,u
        tfr     u,d
        subd    #mbuf           ; length
        tst     ch
        beq     @left
        negb                    ; right hand: ends at column 39
        addb    #40
        bra     @put
@left   clrb
@put    lda     #HANDROW
        ldy     #mbuf
        lbra    printat

* drawheart: the heart at row 21, columns 15-16, on the page mapped: big while it beats, else
* the smaller one (and the smaller one, still, once the game is over)
drawheart
        lda     #TXRED
        sta     textmask
        ldd     #(HANDROW<<8)|HEARTCOL
        lbsr    textpos
        lda     #CH_HEART2
        ldb     gmode           ; (still once the game is over)
        cmpb    #1
        bne     @h
        tst     hbbig
        beq     @h
        lda     #CH_HEART
@h      lbsr    putc
        leax    4,x
        inca
        lbra    putc

* heartbeat: from the main loop, as the reference's: a beat every (180 + 920 x health^1.5) ms
* (health as a share of the most), quicker when fatigued (/ (1 + fatigue / 6)), at least 150 ms;
* the big heart shows for 100 ms of each beat. Only while playing and the status row is showing.
heartbeat
        lda     gmode
        cmpa    #1
        bne     @ret
        lda     paused
        ora     pending
        bne     @ret
        lda     vmode           ; a map covers the status row
        cmpa    #1
        beq     @ret
        cmpa    #2
        beq     @ret
        tst     hbbig           ; the end of a beat
        beq     @due
        ldd     ticks
        subd    hboff
        bmi     @due
        clr     hbbig
        bsr     hbshow
@due    ldd     stime           ; a new beat?
        subd    hbnext
        bmi     @ret
        lda     #1
        sta     hbbig
        ldd     ticks
        addd    #6
        std     hboff
        bsr     hbperiod
        addd    stime
        std     hbnext
        bra     hbshow
@ret    rts

* hbshow: redraw the heart on both screen pages
hbshow  lda     back
        pshs    a
        clra
        lbsr    mappage
        bsr     drawheart
        lda     #1
        lbsr    mappage
        lbsr    drawheart
        puls    a
        lbra    mappage

* hbperiod: D = ticks to the next beat
hbperiod
        ldd     hp              ; health in 16ths of the most (0-16)
        lslb
        rola
        lslb
        rola
        lslb
        rola
        lslb
        rola
        clr     ltmp45
@div    cmpd    maxhp
        blo     @q
        subd    maxhp
        inc     ltmp45
        bra     @div
@q      ldb     ltmp45
        cmpb    #16
        bls     @t
        ldb     #16
@t      ldx     #hbbase
        ldb     b,x             ; the period at rest, ticks
        lda     #180            ; x 180 / (180 + fatigue x 30)
        mul
        std     hbn
        ldd     fatig
        addd    #180
        std     hbd
        clr     ltmp45
        ldd     hbn
@d2     cmpd    hbd
        blo     @q2
        subd    hbd
        inc     ltmp45
        bra     @d2
@q2     ldb     ltmp45
        cmpb    #9              ; at least 150 ms
        bhs     @ok
        ldb     #9
@ok     clra
        rts

* (180 + 920 x max(0.02, n/16)^1.5) ms in ticks, for health n/16 of the most
hbbase  fcb     11,12,13,15,18,20,23,27,30,34,38,42,47,51,56,61,66

* Variables
hands   fcb     HANDE,HANDE     ; left, right
npack   fcb     0
pack    fill    0,PACKMAX
lkind   fcb     HANDE           ; the light burning (its kind), $FF none
lrem    fdb     0               ; seconds of light left
hp      fdb     100
maxhp   fdb     100
xp      fdb     0
lastrank fcb    0
kills   fcb     0
lastt   fdb     0               ; gameclock: ticks last time, and ticks not yet made into seconds
acc     fdb     0
dtick   fdb     0
hbbig   fcb     0               ; the heart: beating (big) now?
hboff   fdb     0               ; when this beat's big heart goes (ticks)
hbnext  fdb     0               ; when the next beat comes (stime)
hbn     fdb     0
hbd     fdb     0
ltmp45  fcb     0
imk     fcb     0
itk     fcb     0
mtk     fdb     0
mtl     fcb     0
tstart  fcb     0               ; first word of an item name in the command
ch      fcb     0               ; the hand
gcnt    fcb     0
gptr    fdb     0
gkind   fcb     0
usewhere fcb    0
prow    fcb     0
curverb fcb     0               ; the verb being run (for "<VERB> LEFT OR RIGHT?")
gax     fcb     0               ; GET: the cell ahead (gax, gay together)
gay     fcb     0
gmk     fcb     0
