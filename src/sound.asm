* Sound effects in the background: the GIME timer interrupts (FIRQ) about SRATE times a second and
* each interrupt puts one sample out through the 6-bit DAC, so sounds play while the game draws and
* reads keys. The timer only runs while a sound is playing.
*
* This code lives at $FC00-$FEED (block $3F, always mapped, below the interrupt vectors). LOADM can't
* load there, so tools/relocate.py takes it out of the .bin and the data file carries it (at the start
* of bank BANKSND); start copies it up (sndcopy). Every build variant gets its own data file with its
* own copy (Makefile's variant), so code here can call the game's routines. The game-side sound code
* (monster cries) lives here too.
*
* Two voices: 0 the heartbeat, 1 everything else (actions and monster cries; a cry never interrupts
* an action). Each steps a 16-bit phase and makes its wave from it on the spot (no tables): sawtooth,
* square, triangle, or noise (an 8-bit LFSR, a new value each time the phase wraps, so the phase step
* sets how coarse it is). Sample = wave x volume / 256; the volumes add up to 254 at most, and the bias
* (128 - volumes / 2) cancels their DC.
*
* Every STICK samples a tick: each voice counts down its segment, slides its pitch, decays its volume,
* and moves to its next segment when one ends. A sound is a list of segments in bank BANKSND
* (build/sfx.asm, from tools/mksfx.py): wave, phase step (2), step change per tick (2), volume, decay
* (volume x k / 256 per tick; 0 = hold), ticks; wave 0 ends the sound. The tick maps BANKSND in for
* a moment to read them and puts back whatever was mapped.

        include "sfxid.inc"     ; (from tools/mksfx.py: sound numbers, SRATE's timer count, STICK)

SNDDP   equ     $0D40           ; the engine's state, in the game's direct page
V0      equ     SNDDP           ; voice 0, 16 bytes
V1      equ     SNDDP+16        ; voice 1
VPH     equ     0               ; 2: phase
VIN     equ     2               ; 2: phase step
VWJ     equ     4               ; 2: its wave routine (vNoff when silent)
VVO     equ     6               ; 1: volume
VSEG    equ     7               ; 2: next segment (in BANKSND)
VDUR    equ     9               ; 1: ticks left in this segment; 0 = the voice is idle
VSL     equ     10              ; 2: step change per tick
VK      equ     12              ; 1: decay
VLV     equ     13              ; 1: loudness for this sound (x volume / 256)
VPRI    equ     14              ; 1: priority of the sound playing
VNZ     equ     15              ; 1: noise value held
s0      equ     SNDDP+32        ; voice 0's part of the sample
sout    equ     SNDDP+33        ; the next sample to put out
sbias   equ     SNDDP+34
scnt    equ     SNDDP+35        ; samples to the next tick
slfsr   equ     SNDDP+36        ; noise
smaster equ     SNDDP+37        ; SOUND volume (0-252)
srun    equ     SNDDP+38        ; the timer is running
stmp    equ     SNDDP+39
SNDEND  equ     SNDDP+40

BANKSND equ     $3E
SFXTAB  equ     $C400           ; in BANKSND: 2 bytes a sound (its segments), then voice and priority
DAC     equ     $FF20

        org     $FC00
* ---- the interrupt: one sample (only D and X used here, X saved) ----
firqh   pshs    d,x
        lda     FIRQENR         ; (acknowledges it)
        lda     <sout           ; the sample worked out last time: steady timing
        sta     DAC
        ldx     <V0+VWJ
        jmp     ,x
v0saw   ldd     <V0+VPH
        addd    <V0+VIN
        std     <V0+VPH
        ldb     <V0+VVO
        mul
        bra     v0d
v0sq    ldd     <V0+VPH
        addd    <V0+VIN
        std     <V0+VPH
        lsla
        lda     #0
        sbca    #0
        ldb     <V0+VVO
        mul
        bra     v0d
v0tri   ldd     <V0+VPH
        addd    <V0+VIN
        std     <V0+VPH
        lsla
        bcc     @t
        coma
@t      ldb     <V0+VVO
        mul
        bra     v0d
v0noi   ldd     <V0+VPH
        addd    <V0+VIN
        std     <V0+VPH
        bcc     @h
        lda     <slfsr
        lsra
        bcc     @n
        eora    #$B8
@n      sta     <slfsr
        sta     <V0+VNZ
@h      lda     <V0+VNZ
        ldb     <V0+VVO
        mul
        bra     v0d
v0off   clra
v0d     sta     <s0
        ldx     <V1+VWJ
        jmp     ,x
v1saw   ldd     <V1+VPH
        addd    <V1+VIN
        std     <V1+VPH
        ldb     <V1+VVO
        mul
        bra     v1d
v1sq    ldd     <V1+VPH
        addd    <V1+VIN
        std     <V1+VPH
        lsla
        lda     #0
        sbca    #0
        ldb     <V1+VVO
        mul
        bra     v1d
v1tri   ldd     <V1+VPH
        addd    <V1+VIN
        std     <V1+VPH
        lsla
        bcc     @u
        coma
@u      ldb     <V1+VVO
        mul
        bra     v1d
v1noi   ldd     <V1+VPH
        addd    <V1+VIN
        std     <V1+VPH
        bcc     @k
        lda     <slfsr
        lsra
        bcc     @m
        eora    #$B8
@m      sta     <slfsr
        sta     <V1+VNZ
@k      lda     <V1+VNZ
        ldb     <V1+VVO
        mul
        bra     v1d
v1off   clra
v1d     adda    <s0
        adda    <sbias
        anda    #$FC
        ora     #$02            ; (bit 1 is the serial output: keep it idle)
        sta     <sout
        dec     <scnt
        beq     stick
        puls    d,x
        rti

* ---- a tick: segments, slides, decays, the bias; the timer stops when both voices are idle ----
stick   lda     #STICK
        sta     <scnt
        pshs    y,u
        lda     MMUT0+6         ; (the segments are in BANKSND: map it in for this tick)
        anda    #$3F            ; (some GIMEs read the top 2 bits back as junk)
        pshs    a
        ldy     #V0
        ldx     #v0tab
        bsr     svoice
        ldy     #V1
        ldx     #v1tab
        bsr     svoice
        puls    a
        sta     MMUT0+6
        lda     <V0+VVO         ; bias = 128 - (volumes) / 2
        adda    <V1+VVO
        lsra
        nega
        adda    #128
        sta     <sbias
        lda     <V0+VDUR        ; anything still playing?
        ora     <V1+VDUR
        bne     @r
        clr     TIMERHI         ; no: the timer stops (a count of 0) and the sound is switched off
        clr     TIMERLO
        clr     <srun
        lbsr    sndquiet
@r      puls    y,u
        puls    d,x
        rti

* svoice: one voice's tick. Y = the voice, X = its wave routines.
svoice  lda     VDUR,y
        beq     @r              ; idle
        deca
        sta     VDUR,y
        beq     @next
        ldd     VIN,y           ; slide
        addd    VSL,y
        std     VIN,y
        ldb     VK,y            ; decay
        beq     @r
        lda     VVO,y
        mul
        sta     VVO,y
@r      rts
@next   lda     #BANKSND        ; the next segment
        sta     MMUT0+6
        ldu     VSEG,y
        ldb     ,u+
        beq     @end
        ldd     b,x             ; (wave numbers are 2, 4, 6, 8, 10)
        std     VWJ,y
        ldd     ,u++
        std     VIN,y
        ldd     ,u++
        std     VSL,y
        lda     ,u+             ; volume x this sound's loudness
        ldb     VLV,y
        mul
        sta     VVO,y
        lda     ,u+
        sta     VK,y
        lda     ,u+
        sta     VDUR,y
        stu     VSEG,y
        rts
@end    ldd     ,x              ; (the off routine)
        std     VWJ,y
        clr     VVO,y
        clr     VPRI,y
        rts
v0tab   fdb     v0off,v0saw,v0sq,v0tri,v0noi,v0off          ; (wave 10: a rest)
v1tab   fdb     v1off,v1saw,v1sq,v1tri,v1noi,v1off

* sndplay: start sound A (SFX_...) at loudness B (0-255, e.g. less for a distant monster). It goes on
* the sound's voice, unless that voice is playing something more important. Keeps all registers.
sndplay pshs    cc,d,x,y,u
        lda     <smaster
        beq     @r
        mul                     ; loudness x SOUND volume
        sta     <stmp
        orcc    #$50            ; (the interrupt mustn't see a voice half set up)
        ldb     MMUT0+6
        andb    #$3F
        pshs    b
        ldb     #BANKSND
        stb     MMUT0+6
        ldb     2,s             ; the sound
        lslb
        ldx     #SFXTAB
        abx
        abx                     ; 4 bytes a sound
        ldy     #V0
        tst     2,x             ; its voice
        beq     @v
        ldy     #V1
@v      lda     3,x             ; priority: not over a more important sound
        tst     VDUR,y
        beq     @go
        cmpa    VPRI,y
        blo     @x
@go     sta     VPRI,y
        ldd     ,x
        std     VSEG,y
        lda     <stmp
        sta     VLV,y
        lda     #1              ; the next tick starts it
        sta     VDUR,y
        tst     <srun           ; the timer running?
        bne     @x
        inc     <srun
        lda     $FF23           ; sound on (from the DAC)
        ora     #$08
        sta     $FF23
        lda     #1
        sta     <scnt
        ldd     #STIMER
        stb     TIMERLO
        sta     TIMERHI
@x      puls    b
        stb     MMUT0+6
@r      puls    cc,d,x,y,u,pc

* sndoff: silence (before a tune, which drives the DAC itself)
sndoff  pshs    cc,a
        orcc    #$50
        clr     TIMERHI
        clr     TIMERLO
        clr     <srun
        clr     <V0+VDUR
        clr     <V1+VDUR
        bsr     sndquiet
        puls    cc,a,pc

* sndquiet: sound switched off, the DAC at its middle for when it's next switched on. While nothing
* plays the sound stays off, as BASIC leaves it: a steady level on the speaker is silent in theory, but
* XRoar turned it into static (Steve, 2026-11-19).
sndquiet
        lda     #$82
        sta     <sout
        sta     DAC
        lda     $FF23
        anda    #$F7
        sta     $FF23
        rts

* sndinit: (at start-up, interrupts off) state, the FIRQ vector, the timer's clock, sound on
sndinit ldx     #SNDDP
@clr    clr     ,x+
        cmpx    #SNDEND
        blo     @clr
        ldd     #v0off
        std     <V0+VWJ
        ldd     #v1off
        std     <V1+VWJ
        lda     #128
        sta     <sbias
        lda     #$82
        sta     <sout
        lda     #1
        sta     <slfsr
        lda     #6*36           ; SOUND 6, as the reference starts
        sta     <smaster
        lda     #$7E            ; JMP firqh at the CoCo 3's FIRQ vector
        sta     $FEF4
        ldx     #firqh
        stx     $FEF5
        lda     #$20            ; timer clock 279 ns (3.58 MHz), MMU task 0
        sta     INIT1
        lda     #$20            ; the timer's FIRQ
        sta     FIRQENR
        lda     $FF01           ; the sound source: the DAC (select lines 0, 0); switched on only while
        anda    #$F7            ; something plays
        sta     $FF01
        lda     $FF03
        anda    #$F7
        sta     $FF03
        bra     sndquiet
* ---- the game's side ----

* sfxa: play sound A at full loudness. Keeps B, X, Y, U.
sfxa    pshs    b
        ldb     #255
        bsr     sfx
        puls    b,pc

* sfx: play sound A (SFX_...) at loudness B (0-255); not while asleep (the reference's SLEEP is
* silent). Keeps all registers.
sfx     tst     sleeping
        lbeq    sndplay
        rts

* crytick: (from simulate) now and then a monster within hearing calls out, quieter the further away
* it is along the passages (the reference's cryLevel). The reference times each monster's cries
* separately; here every 0.9-2 s one monster is picked at random (a sleeper half the time).
crytick ldd     stime
        subd    nextcry
        bmi     @r
        lbsr    rand
        anda    #63
        tfr     a,b
        clra
        addd    #54
        addd    stime
        std     nextcry
        lda     nmons
        beq     @r
        pshs    a
        lbsr    rand
        puls    b
        mul                     ; a monster: A = random x count / 256
        ldb     #MONREC
        mul
        addd    #mons
        tfr     d,x
        lda     MFLAGS,x
        bita    #MF_DORMANT
        beq     @aw
        lbsr    rand
        tsta
        bmi     @r
@aw     lda     MX,x
        ldb     MY,x
        lbsr    pdat
        cmpd    #17
        bhi     @r              ; (unreachable, -1, is high too)
        ldu     #crylv
        ldb     b,u
        lda     MKND,x
        adda    #SFX_CRY
        bra     sfx
@r      rts
nextcry fdb     0

sndres_end
        ifgt    sndres_end-$FEEE
        error   "the sound engine is past $FEED (the interrupt vectors start at $FEEE)"
        endc
