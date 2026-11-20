* The simulation: monsters, health, fatigue, fainting, combat (the reference's update, exert,
* checkFaint, monsterAttack, attack, killMonster). Times are in 60ths of a second of play (stime),
* which stops while paused, while a Y/N question is up and once the game is over.
*
*   simulate   from the main loop: fatigue eases, resting heals, fainting, the monsters act
*   pbfs       after you move: steps from you to every cell (the reference's pdist), in dist
*   exert      a step's cost: fatigue and strain
*   c_attack   ATTACK LEFT / RIGHT
*   c_xxx      XXX: kill the monster in front of or beside you (test)

* Monster record fields (MONREC)
MX      equ     0
MY      equ     1
MKND    equ     2
MHP     equ     3               ; 2
MCARRY  equ     7
MFLAGS  equ     8
MNEXTMV equ     9               ; 2: when it next moves (stime)
MNEXTAT equ     11              ; 2: when it can next attack

FAINTHP equ     10
FAT1    equ     30              ; fatigue is kept times 30, so easing 2 a second is 1 a tick

* Per kind: move time, attack time (ticks), hit (out of 256), damage low, high, XP for the kill
mstats  fcb     114,132,154,1,3,2       ; slime mould   1900 ms, 2200 ms, 0.60, 1-3
        fcb     57,102,179,2,5,4        ; gloomcrawler   950, 1700, 0.70, 2-5
        fcb     87,78,184,3,7,6         ; skeleton      1450, 1300, 0.72, 3-7
        fcb     36,120,192,4,9,10       ; bone hound     600, 2000, 0.75, 4-9
        fcb     48,90,205,6,11,10       ; ash wraith     800, 1500, 0.80, 6-11
        fcb     96,132,192,8,15,20      ; iron golem    1600, 2200, 0.75, 8-15
        fcb     60,96,205,10,18,45      ; hollow king   1000, 1600, 0.80, 10-18
MSTATW  equ     6

* Shield blocks: the damage after a block, by damage 0-24 (the reference's Math.round, from JS)
blockb  fcb     1,1,1,2,3,4,4,5,6,6,7,8,8,9,10,11,11,12,13,13,14,15,15,16,17   ; buckler 0.3
blockt  fcb     1,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12         ; tower 0.5

* Your blows: hit (out of 256), damage low, high, arm ready again after (ticks): weapons by kind
* 0-4, then the bare hand, then a shield
wstats  fcb     236,3,7,36              ; dagger    0.92  3-7   600 ms
        fcb     220,5,10,42             ; hand axe  0.86  5-10  700
        fcb     225,6,12,45             ; sword     0.88  6-12  750
        fcb     200,9,18,60             ; hammer    0.78  9-18 1000
        fcb     230,14,24,45            ; rune      0.90 14-24  750
        fcb     218,1,3,39              ; bare hand 0.85  1-3   650
        fcb     218,2,5,54              ; a shield  0.85  2-5   900

* ---- random numbers for play (they needn't match the web version) ----
* rand: A = 0-255
rand    pshs    b,x,u
        lbsr    rng32
        lda     rngout
        puls    b,x,u,pc

* rndab: A = low, B = high (high - low < 255). A = a random number from low to high.
rndab   pshs    a,x,u
        subb    ,s
        incb
        clra
        lbsr    rndn
        tfr     b,a
        adda    ,s
        puls    b,x,u
        rts

* ---- distances from you ----
* pbfs: steps from you to every cell (dist, in the scratch bank; -1 = unreachable)
pbfs    lda     #BANKSCR
        sta     MMUT0+6
        lda     px
        ldb     py
        lbsr    cellidx
        lbsr    bfs
        lda     #BANKCOM
        sta     MMUT0+6
        rts

* pdat: A = x, B = y. D = steps from you to that cell (signed; -1 = unreachable). Keeps X.
pdat    pshs    x
        lbsr    cellidx
        lslb
        rola
        addd    #dist
        tfr     d,x
        lda     #BANKSCR
        sta     MMUT0+6
        ldd     ,x
        pshs    a
        lda     #BANKCOM
        sta     MMUT0+6
        puls    a,x,pc

* ---- the body ----
* exert: a step: fatigue up one, and strain (0.355 + 0.02 f + 0.125 f^2 health a step, f the
* fatigue) wears away health; warnings when you're breathing hard. Strain is kept in 1/256ths of
* a health point (3 bytes); with F = fatigue x 30: 91 + 44 F / 256 + 9 F^2 / 256.
exert   ldd     fatig
        addd    #FAT1
        cmpd    #60*FAT1
        bls     @f
        ldd     #60*FAT1
@f      std     fatig
        std     m_x+2           ; 9 F^2
        std     m_y+2
        ldd     #0
        std     m_x
        std     m_y
        lbsr    imul32
        ldd     m_res
        std     m_x
        ldd     m_res+2
        std     m_x+2
        ldd     #0
        std     m_y
        ldd     #9
        std     m_y+2
        lbsr    imul32
        ldd     strain+1        ; strain += 9 F^2 / 256
        addd    m_res+1
        std     strain+1
        lda     strain
        adca    m_res
        sta     strain
        lda     fatig+1         ; strain += 44 F / 256 (F = hi:lo; 44 F / 256 = hi*44 + lo*44 / 256)
        ldb     #44
        mul
        sta     etmp
        lda     fatig
        ldb     #44
        mul
        addb    etmp
        adca    #0
        addd    #91             ; and the 0.355
        addd    strain+1
        std     strain+1
        lda     strain
        adca    #0
        sta     strain
        ldd     strain          ; whole points of strain come off your health
        beq     @warn
        pshs    d
        clr     strain
        clr     strain+1
        puls    d
        lbsr    hurt
        bne     @alive
        ldy     #m_burst
        lbra    die
@alive  lbsr    checkfaint
@warn   ldd     stime           ; warnings, now and then
        subd    nextwarn
        bmi     @ret
        ldd     fatig
        cmpd    #8*FAT1
        blo     @hard
        ldd     stime
        addd    #180
        std     nextwarn
        ldy     #m_hammers
        lbra    msg
@hard   cmpd    #4*FAT1
        blo     @ret
        ldd     stime
        addd    #240
        std     nextwarn
        ldy     #m_breathing
        lbra    msg
@ret    rts

* fatlevel: A = 0 rested, 1 winded (fatigue 4+), 2 exhausted (8+)
fatlevel
        ldd     fatig
        cmpd    #8*FAT1
        bhs     @two
        cmpd    #4*FAT1
        bhs     @one
        clra
        rts
@one    lda     #1
        rts
@two    lda     #2
        rts

* checkfaint: the reference's checkFaint: you black out at 10 health and come round above it
checkfaint
        tst     fainted
        bne     @in
        ldd     hp
        beq     @ret
        cmpd    #FAINTHP
        bhi     @ret
        lda     #1
        sta     fainted
        sta     vdirty
        clr     vmode
        ldy     #m_faint
        lbra    msg
@in     ldd     hp
        cmpd    #FAINTHP
        bls     @ret
        clr     fainted
        lda     #1
        sta     vdirty
        ldy     #m_senses
        lbra    msg
@ret    rts

* ---- every time round the main loop ----
simulate
        lda     gmode
        cmpa    #1
        lbne    @ret
        lda     paused
        ora     pending
        lbne    @ret
        lbsr    freshen
        lbsr    fatlevel        ; fatigue eases (WINDED / EXHAUSTED come and go on the status row)
        sta     etmp
        ldd     fatig
        subd    dtick
        bcc     @fs
        ldd     #0
@fs     std     fatig
        lbsr    fatlevel
        cmpa    etmp
        beq     @rest
        lda     #1
        sta     statdirty
@rest   ldd     stime           ; resting heals 1 a 1.2 s: not hurt for 3 s, still for 1.5 s, rested
        subd    lasthurt
        cmpd    #180
        ble     @noreg
        ldd     stime
        subd    lastmove
        cmpd    #90
        ble     @noreg
        ldd     fatig
        cmpd    #5*FAT1
        bhs     @noreg
        ldd     hp
        cmpd    maxhp
        bhs     @noreg
        ldd     regen
        addd    dtick
        std     regen
        cmpd    #72
        blo     @noreg
        ldd     #0
        std     regen
        ldd     hp
        addd    #1
        std     hp
        lda     #1
        sta     statdirty
@noreg  lbsr    checkfaint
        lbsr    crytick         ; monsters call out now and then
        lbra    monsters
@ret    rts

* ---- the monsters ----
monsters
        lda     nmons
        lbeq    @ret
        clr     mi
@each   lda     mi
        ldb     #MONREC
        mul
        addd    #mons
        tfr     d,x
        stx     mp
        lda     MX,x            ; how far from you (by the passages)
        ldb     MY,x
        lbsr    pdat
        std     mdist
        ldx     mp
        lda     MFLAGS,x        ; asleep: it wakes when you come right up to it
        bita    #MF_DORMANT
        beq     @awake
        ldd     mdist
        cmpd    #1
        lbhi    @next
        lda     MFLAGS,x
        anda    #$FF-MF_DORMANT
        sta     MFLAGS,x
        ldd     stime
        addd    #24             ; 400 ms
        std     MNEXTMV,x
        ldd     stime
        addd    #36             ; 600 ms
        std     MNEXTAT,x
        ldb     MKND,x
        ldx     #m_the
        ldy     #m_stirs
        lbsr    saymon
        lbra    @next
@awake  ldd     stime           ; its turn yet?
        subd    MNEXTMV,x
        lbmi    @next
        ldb     MKND,x          ; next turn in move x (0.8 to 1.2)
        lda     #MSTATW
        mul
        ldu     #mstats
        leau    d,u
        stu     mst
        lda     ,u              ; move
        ldb     #205            ; x 0.8
        mul
        sta     etmp
        lda     ,u              ; + 0 to 0.4 x move
        ldb     #102
        mul
        tfr     a,b
        clra
        lbsr    rndn            ; (rndn takes D = n; 0..n-1)
        addb    etmp
        clra
        addd    stime
        ldx     mp
        std     MNEXTMV,x
        ldd     mdist           ; next to you, or in your cell: fight
        cmpd    #1
        lbhi    @far
        bne     @fight
        ldd     px              ; one step away: into your cell if no other monster is there
        lbsr    monat
        beq     @fight
        ldx     mp
        ldd     px
        std     MX,x
        lbsr    soonatk
        lda     #1
        sta     vdirty
        lbra    @next
@fight  ldx     mp              ; its blow, if its arm is ready
        ldd     stime
        subd    MNEXTAT,x
        lbmi    @next
        ldu     mst
        ldb     1,u
        clra
        addd    stime
        std     MNEXTAT,x
        lbsr    mattack
        lbra    @next
@far    clr     mchase          ; chase you if it sees you down a hall, or you're close by passages
        ldd     mdist
        lble    @opts
        lbsr    los
        bne     @near
        ldb     #6              ; it sees you: 20 cells if you carry a light, 6 if not
        tst     vlight
        beq     @sight
        ldb     #20
@sight  clra
        cmpd    mdist
        blt     @near
        inc     mchase
        bra     @opts
@near   ldb     mz_lvl          ; within 14 + 2 x depth steps
        lslb
        addb    #14
        clra
        cmpd    mdist
        blt     @opts
        inc     mchase
@opts   clr     nmopt           ; which ways can it go?
        clr     md
@dir    ldx     mp
        ldb     md
        ldu     #dx1
        lda     b,u
        adda    MX,x
        sta     mnx
        ldu     #dy1
        lda     b,u
        adda    MY,x
        sta     mny
        tfr     a,b
        lda     mnx
        lbsr    iswall
        bne     @nd
        ldd     mnx
        lbsr    monat
        beq     @nd
        tst     mchase          ; chasing: only ways that get closer
        beq     @ok
        ldd     mnx
        lbsr    pdat
        cmpd    mdist
        bge     @nd
@ok     ldb     nmopt
        ldx     #mopts
        lda     md
        sta     b,x
        inc     nmopt
@nd     inc     md
        lda     md
        cmpa    #4
        blo     @dir
        lda     nmopt
        beq     @sound
        tst     mchase          ; wanderers only move 60% of their turns
        bne     @go
        lbsr    rand
        cmpa    #154
        bhs     @sound
@go     clra
        ldb     nmopt
        lbsr    rndn
        ldx     #mopts
        lda     b,x
        tfr     a,b
        ldx     mp
        ldu     #dx1
        lda     b,u
        adda    MX,x
        sta     MX,x
        ldu     #dy1
        lda     b,u
        adda    MY,x
        sta     MY,x
        ldd     mdist           ; you might see that: redraw if it was near, or on the full map
        cmpd    #10
        bls     @seen
        lda     vmode
        cmpa    #2
        bne     @moved
@seen   lda     #1
        sta     vdirty
@moved  ldx     mp
        lda     MX,x
        ldb     MY,x
        lbsr    pdat
        cmpd    #1
        bne     @sound
        lbsr    soonatk
@sound  tst     mchase          ; "YOU HEAR RATTLING BONES NEARBY..." now and then
        beq     @next
        ldd     mdist
        cmpd    #5
        bgt     @next
        ldd     stime
        subd    nextsound
        ble     @next
        ldd     stime
        addd    #540            ; 9 s
        std     nextsound
        lbsr    mbstart
        ldx     #m_youhear
        lbsr    mbstr
        ldx     mp
        ldb     MKND,x
        lslb
        ldx     #msounds
        ldx     b,x
        lbsr    mbstr
        ldx     #m_nearby
        lbsr    mbstr
        lbsr    mbsend
@next   lda     gmode           ; (stop if that killed you)
        cmpa    #1
        bne     @ret
        inc     mi
        lda     mi
        cmpa    nmons
        lblo    @each
@ret    rts

* soonatk: the monster at mp has just come next to you: it can't strike for 500 ms
soonatk ldx     mp
        ldd     stime
        addd    #30
        pshs    d
        ldd     MNEXTAT,x
        subd    ,s
        bpl     @keep
        ldd     ,s
        std     MNEXTAT,x
@keep   leas    2,s
        rts

* los: can the monster at mp see you straight down a hall (same row or column, nothing between)?
* EQ if it can.
los     ldx     mp
        lda     MX,x
        cmpa    px
        beq     @col
        lda     MY,x
        cmpa    py
        bne     @no
        lda     #1              ; same row: step toward you in x
        ldb     MX,x
        cmpb    px
        blo     @rx
        lda     #-1
@rx     sta     lsx
        clr     lsy
        bra     @walk
@col    clr     lsx             ; same column: step in y
        lda     #1
        ldb     MY,x
        cmpb    py
        blo     @ry
        lda     #-1
@ry     sta     lsy
@walk   lda     MX,x
        ldb     MY,x
@step   adda    lsx
        addb    lsy
        cmpa    px
        bne     @chk
        cmpb    py
        beq     @yes
@chk    pshs    d
        lbsr    iswall
        puls    d
        beq     @step
@no     lda     #1              ; NE
        rts
@yes    clra                    ; EQ
        rts

* mattack: the monster at mp strikes at you (the reference's monsterAttack)
mattack ldx     mp
        clr     mrel            ; where from: in your cell or in front 0, right 1, behind 2, left 3
        ldd     MX,x
        cmpd    px
        beq     @rel
        lda     MY,x            ; the reference's dirTo: north if above, east if right, ...
        cmpa    py
        bhs     @nn
        clra
        bra     @dt
@nn     lda     MX,x
        cmpa    px
        bls     @ne
        lda     #1
        bra     @dt
@ne     lda     MY,x
        cmpa    py
        bls     @nw
        lda     #2
        bra     @dt
@nw     lda     #3
@dt     suba    pdir
        anda    #3
        sta     mrel
@rel    ldu     mst
        lbsr    rand            ; does it hit?
        cmpa    2,u
        blo     @hits
        lda     #1              ; (a faint strike mark)
        lbsr    fxstrike
        ldx     #m_the          ; "THE SKELETON LUNGES AND MISSES." / "THE SKELETON MISSES FROM
        lbsr    mbstart         ; BEHIND." (agreed: shortened from "LUNGES FROM BEHIND AND MISSES")
        lbsr    mbstr
        lbsr    mbmname
        tst     mrel
        bne     @lsd
        ldx     #m_lunges
        lbsr    mbstr
        ldx     #m_misses
        bra     @lfr
@lsd    ldx     #m_missesw
        lbsr    mbstr
        lbsr    mbwhere
        ldx     #m_dot
@lfr    lbsr    mbstr
        lbra    mbsend
@hits   lbsr    rank            ; your dodge: rank x 5% (13/256), at most half
        ldb     #13
        mul
        cmpb    #128
        bls     @dg
        ldb     #128
@dg     stb     etmp
        lbsr    rand
        cmpa    etmp
        bhs     @struck
        lda     #1              ; (a faint strike mark)
        lbsr    fxstrike
        lbsr    mbstart         ; "YOU DEFTLY DODGE THE SKELETON." / "YOU DODGE A BLOW FROM BEHIND."
        tst     mrel            ; (agreed: the reference names it and says where, too long)
        bne     @dgs
        ldx     #m_dodge2
        lbsr    mbstr
        lbsr    mbmname
        bra     @dge
@dgs    ldx     #m_dodgeb
        lbsr    mbstr
        lbsr    mbwhere
@dge    ldx     #m_dot
        lbsr    mbstr
        lbra    mbsend
@struck ldu     mst             ; damage, less a shield's block if it came from in front
        lda     3,u
        ldb     4,u
        lbsr    rndab
        sta     mdmg
        clr     mblock
        tst     mrel
        bne     @dmg
        ldx     #blockt         ; the better shield in either hand
        lda     hands
        anda    #$7F
        cmpa    #K_TOWER
        beq     @blk
        lda     hands+1
        anda    #$7F
        cmpa    #K_TOWER
        beq     @blk
        ldx     #blockb
        lda     hands
        anda    #$7F
        cmpa    #K_BUCKLER
        beq     @blk
        lda     hands+1
        anda    #$7F
        cmpa    #K_BUCKLER
        bne     @dmg
@blk    ldb     mdmg
        lda     b,x
        sta     mdmg
        inc     mblock
@dmg    lda     #SFX_HURT
        lbsr    sfxa
        lda     mblock          ; the strike mark: a hit (0) or blocked (2: sparks too)
        lsla
        lbsr    fxstrike
        ldb     #3              ; the flash (50 ms, Steve; the reference's is 160)
        lbsr    fxflash
        ldd     stime
        std     lasthurt
        std     laststruck
        clra
        ldb     mdmg
        lbsr    hurt
        pshs    cc
        lbsr    mbstart         ; "THE SKELETON STRIKES!" / "SOMETHING STRIKES FROM BEHIND!"
        tst     mrel
        bne     @some
        ldx     #m_the
        lbsr    mbstr
        lbsr    mbmname
        bra     @strikes
@some   ldx     #m_something
        lbsr    mbstr
@strikes
        ldx     #m_strikes
        lbsr    mbstr
        lbsr    mbwhere
        ldx     #m_bang
        lbsr    mbstr
        tst     mblock
        beq     @send
        ldx     #m_blocked
        lbsr    mbstr
@send   lbsr    mbsend
        puls    cc
        bne     @alive
        lda     #2              ; dead (no extra reason, as the reference's die(null))
        sta     gmode
        clr     vmode
        lda     #1
        sta     vdirty
        sta     tunereq         ; the lose tune (Steve: it didn't play when a monster killed you)
        ldy     #m_perished
        lbsr    msg
        ldy     #m_restart
        lbra    msg
@alive  lbra    checkfaint

* mbmname: add the name of the monster at mp to the message being built
mbmname ldx     mp
        ldb     MKND,x
        lbra    mbmon

* mbwhere: add " FROM THE RIGHT" / " FROM BEHIND" / " FROM THE LEFT" (mrel 1-3)
mbwhere ldb     mrel
        beq     @r
        lslb
        ldx     #mwhere-2
        ldx     b,x
        lbsr    mbstr
@r      rts

* ---- your attack ----
c_attack
        lbsr    needhand
        lbcs    @ret
        sta     ch
        ldb     ch              ; arm ready?
        lslb
        ldx     #atkready
        abx
        stx     atkp
        ldd     stime
        subd    ,x
        bpl     @ready
        ldy     #m_notready
        lbra    msg
@ready  ldx     #hands          ; what's in that hand decides the blow
        lda     ch
        ldb     a,x
        andb    #$7F
        cmpb    #K_RUNE
        bls     @w              ; a weapon: kinds 0-4 (an empty hand, $7F, isn't)
        lda     #6              ; a shield
        cmpb    #K_BUCKLER
        beq     @r6
        cmpb    #K_TOWER
        beq     @r6
        lda     #5              ; anything else: the bare hand
@r6     tfr     a,b
@w      lda     #4
        mul
        addd    #wstats
        tfr     d,u
        stu     wst
        ldb     3,u             ; next blow with this arm
        clra
        addd    stime
        std     [atkp]
        inc     <swung           ; (the main loop lets the clock run through the swing's drawing, so
                                ; the recovery is the reference's in real time: Steve, too slow)
        lda     #SFX_SWING
        lbsr    sfxa
        lbsr    fxswing         ; the picture of the blow
        ldd     hp              ; swinging is exertion
        cmpd    #1
        bls     @find
        subd    #1
        std     hp
        lda     #1
        sta     statdirty
        lbsr    checkfaint
@find   ldd     px              ; your cell first, then the one ahead
        lbsr    monat
        beq     @got
        ldb     pdir
        ldx     #dx1
        lda     b,x
        adda    px
        sta     mnx
        ldx     #dy1
        lda     b,x
        adda    py
        tfr     a,b
        lda     mnx
        lbsr    monat
        beq     @got
        ldy     #m_emptyair
        lbra    msg
@got    stx     mp
        lda     MFLAGS,x        ; a sleeper wakes
        bita    #MF_DORMANT
        beq     @aim
        anda    #$FF-MF_DORMANT
        sta     MFLAGS,x
        ldd     stime
        addd    #36
        std     MNEXTMV,x
        ldb     MKND,x
        ldx     #m_the
        ldy     #m_awakens
        lbsr    saymon
@aim    ldu     wst             ; hit or miss
        lbsr    rand
        cmpa    ,u
        blo     @hit
        ldx     mp
        ldb     MKND,x
        ldx     #m_youmiss
        ldy     #m_dot
        lbra    saymon
@hit    lda     #SFX_HIT
        lbsr    sfxa
        lda     1,u             ; damage + your rank
        ldb     2,u
        lbsr    rndab
        sta     mdmg
        lbsr    rank
        adda    mdmg
        tfr     a,b
        clra
        ldx     mp
        pshs    d
        ldd     MHP,x
        subd    ,s++
        std     MHP,x
        bgt     @alive
        lbra    killmon
@alive  ldb     MKND,x
        ldx     #m_youhit
        ldy     #m_bang
        lbra    saymon
@ret    rts

* killmon: the monster at mp dies (the reference's killMonster)
killmon lda     #SFX_KILL
        lbsr    sfxa
        ldx     mp
        lda     MX,x
        sta     kx
        lda     MY,x
        sta     ky
        lda     MKND,x
        sta     kk
        lda     MCARRY,x
        sta     kc
        leau    MONREC,x        ; it goes from the list (the rest move down)
        ldd     #mons+MAXMONS*MONREC
        pshs    d
@mv     cmpu    ,s
        bhs     @mvd
        lda     ,u+
        sta     ,x+
        bra     @mv
@mvd    leas    2,s
        dec     nmons
        inc     kills
        lbsr    mbstart         ; "THE SKELETON CRUMBLES INTO A HEAP OF BONES!"
        ldx     #m_the
        lbsr    mbstr
        ldb     kk
        lbsr    mbmon
        ldx     #m_sp1
        lbsr    mbstr
        ldb     kk
        lslb
        ldx     #mdeaths
        ldx     b,x
        lbsr    mbstr
        lbsr    mbsend
        ldb     kk              ; XP, after the death message
        lda     #MSTATW
        mul
        ldx     #mstats+5
        ldb     d,x
        clra
        lbsr    gainxp
        ldd     maxhp           ; and 4 more most health, up to 250
        addd    #4
        cmpd    #250
        bls     @mh
        ldd     #250
@mh     std     maxhp
        lda     #1
        sta     statdirty
        sta     vdirty
        lda     kc              ; what it carried falls where it died
        cmpa    #$FF
        beq     @king
        sta     ikind
        ldd     kx
        lbsr    additem
        lbsr    mbstart         ; "IT DROPS A HEALING HERB!"
        ldx     #m_itdrops
        lbsr    mbstr
        ldb     kc
        lbsr    aname
        ldx     #m_bang
        lbsr    mbstr
        lbsr    mbsend
@king   lda     kk
        cmpa    #M_KING
        bne     @ret
        lda     #K_CROWN
        sta     ikind
        ldd     kx
        lbsr    additem
        ldy     #m_glows
        lbra    msg
@ret    rts

* XXX (test): kill the monster in your cell or ahead, or else any beside you
c_xxx   ldd     px
        lbsr    monat
        beq     @kill
        clr     md
@dir    ldb     md              ; ahead first (pdir), then the others
        addb    pdir
        andb    #3
        ldx     #dx1
        lda     b,x
        adda    px
        sta     mnx
        ldx     #dy1
        lda     b,x
        adda    py
        tfr     a,b
        lda     mnx
        lbsr    monat
        beq     @kill
        inc     md
        lda     md
        cmpa    #4
        blo     @dir
        ldy     #m_xxxnone
        lbra    msg
@kill   stx     mp
        lbra    killmon

* win: the crown in your hand (the reference's win)
win     lda     #2              ; the win tune
        sta     tunereq
        ldy     #m_won
        lbsr    msg
        ldy     #m_restart
        lbsr    msg
        lda     #2
        sta     gmode
        clr     vmode
        lda     #1
        sta     vdirty
        rts

* monwake: entering a level: every monster may act at once (the reference's nextMove 0)
monwake ldx     #mons
        lda     nmons
        beq     @ret
        sta     etmp
@each   ldd     stime
        std     MNEXTMV,x
        std     MNEXTAT,x
        leax    MONREC,x
        dec     etmp
        bne     @each
@ret    rts

* Variables
stime   fdb     0               ; 60ths of a second of play
fatig   fdb     0               ; fatigue x 30
strain  fcb     0,0,0           ; strain, in 1/256 health
regen   fdb     0
lasthurt fdb    0
laststruck fdb  0               ; when a monster last hit you (SLEEP refuses for 4 s)
lastmove fdb    0
nextwarn fdb    0
nextsound fdb   0
atkready fdb    0,0             ; when each arm can strike again
atkp    fdb     0
fainted fcb     0
etmp    fcb     0
mi      fcb     0
mp      fdb     0
mst     fdb     0
wst     fdb     0
mdist   fdb     0
mchase  fcb     0
nmopt   fcb     0
mopts   fcb     0,0,0,0
md      fcb     0
mnx     fcb     0               ; mnx, mny together
mny     fcb     0
lsx     fcb     0
lsy     fcb     0
mrel    fcb     0
mdmg    fcb     0
mblock  fcb     0
kx      fcb     0               ; kx, ky together
ky      fcb     0
kk      fcb     0
kc      fcb     0
