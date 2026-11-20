* The win and lose tunes, through the 6-bit DAC ($FF20, top 6 bits). Part of the data file (bank
* BANKDAT, run with it mapped at $C000); the game calls tuneplay from fixed code.
*
* Four voices are mixed in software with interrupts off (playback blocks, which is fine on the
* end-of-game screen). Each voice steps a 16-bit phase through a 256-byte wave table (stored turned half
* round, read with a signed offset from its middle) and scales it by an 8-bit volume: sample = wave x
* volume / 256. The waves are unsigned around 128, so each voice adds volume/2 of DC; the mix adds
* bias = 128 - (sum of volumes)/2 to cancel it, so volumes can change without thumps. The volumes add
* up to 254 at most, so nothing overflows.
*
* Samples must come out evenly spaced: a pause, even of one sample, every few milliseconds puts a
* buzz on every note (the first version stopped for 1-2 samples every 64 to read its events, and Steve
* heard static in the win tune). So after each sample the loop runs exactly one TASK, a small piece of
* the control work, and every task takes exactly the same time (padded with NOPs; tools/tunetime.py
* checks it from an XRoar trace). The tasks of one tick (TICKLEN samples):
*   tick           start: if a wait is running, count it down and go to the volumes; else the events
*   ev, then its handler   one event in two samples (the handler reads its arguments)
*   enva, envb     for each voice: its ramp or decay; its slide
*   bias, key      the DC bias from the volumes; the keyboard (a key stops the tune, once all were up)
*   idle           until the tick's samples are done
*
* Events (build/tunes.asm, from tools/mktunes.py, which also plays them through a copy of this
* arithmetic into a WAV): handler number x 2, voice x 16, arguments:
*   0 PITCH  hi lo   phase step per sample (the note); stops a slide
*   1 SLIDE  hi lo   added to the phase step every tick
*   2 SET    n       volume n now; holds (stops a ramp or decay)
*   3 RAMP   hi lo   volume changes by hi:lo (signed, 1/256ths) every tick (mktunes ends it with a SET)
*   4 DECAY  k       volume x k/256 every tick
*   5 WAVE   hi lo   the wave table (its address + 128)
*   6 WAIT   n       the next events come n ticks later
*   7 END

TICKLEN equ     64
NV      equ     4               ; voices

* a voice's state (16 bytes, voice v at tdp + 16v)
PH      equ     0               ; 2: phase
INC     equ     2               ; 2: phase step per sample
WV      equ     4               ; 2: wave table + 128
VO      equ     6               ; 1: volume used by the mix
VOL     equ     7               ; 2: volume, 8.8
MD      equ     9               ; 1: 0 ramp (DV 0 = hold), nonzero decay
DV      equ     10              ; 2: ramp step (8.8, signed)
K       equ     12              ; 1: decay factor
SL      equ     14              ; 2: slide step

        align   256
tdp                             ; the player's direct page
v0      rmb     16
v1      rmb     16
v2      rmb     16
v3      rmb     16
sum     rmb     1
bias    rmb     1
cnt     rmb     1               ; samples left in this tick
wait    rmb     1               ; ticks left to wait
task    rmb     2               ; the task after the next sample
envn    rmb     1               ; voices left for enva/envb
old     rmb     1
keyup   rmb     1
s01     rmb     1
s03     rmb     1
s23     rmb     1
        align   256

        opt     c
        setdp   tdp>>8

* tuneplay: A = 1 the lose tune, 2 the win tune. Keeps all registers.
* While it plays: Y = the next event, U = the voice being worked on.
tuneplay
        pshs    cc,dp,d,x,y,u
        orcc    #$50
        ldx     #tunetab-2
        lsla
        ldy     a,x
        lda     #tdp>>8
        tfr     a,dp
        ldu     #tdp            ; all voices silent, reading the sine
        ldb     #NV*16
@clr    clr     ,u+
        decb
        bne     @clr
        ldu     #tdp
        ldb     #NV
@wv     ldx     #wsine+128
        stx     WV,u
        leau    16,u
        decb
        bne     @wv
        clr     <wait
        clr     <keyup
        lda     #128
        sta     <bias
        ldx     #ttick
        stx     <task
        lda     $FF01           ; sound on, from the DAC: select lines (CA2, CB2 of PIA 0) both 0,
        sta     <s01            ; then PIA 1's CB2 high
        anda    #$F7
        sta     $FF01
        lda     $FF03
        sta     <s03
        anda    #$F7
        sta     $FF03
        lda     $FF23
        sta     <s23
        ora     #$08
        sta     $FF23
        lda     #$02            ; glide the DAC from 0 (silence) up to its middle: no click
        ldb     #4
        lbsr    glide
* ---- one sample, then one task: every pass takes exactly TSAMP cycles ----
smp     ldd     <v0+PH
        addd    <v0+INC
        std     <v0+PH
        ldx     <v0+WV
        lda     a,x
        ldb     <v0+VO
        mul
        sta     <sum
        ldd     <v1+PH
        addd    <v1+INC
        std     <v1+PH
        ldx     <v1+WV
        lda     a,x
        ldb     <v1+VO
        mul
        adda    <sum
        sta     <sum
        ldd     <v2+PH
        addd    <v2+INC
        std     <v2+PH
        ldx     <v2+WV
        lda     a,x
        ldb     <v2+VO
        mul
        adda    <sum
        sta     <sum
        ldd     <v3+PH
        addd    <v3+INC
        std     <v3+PH
        ldx     <v3+WV
        lda     a,x
        ldb     <v3+VO
        mul
        adda    <sum
        adda    <bias
        anda    #$FC
        ora     #$02            ; (bit 1 is the serial output: keep it idle)
        sta     $FF20
        dec     <cnt
        ldx     <task
        jmp     ,x
smpend                          ; (tunetime.py: the loop's cycles are counted from smp to here)

* ---- the tasks: each one TASKLEN cycles from its label to its jmp smp inclusive (tunetime.py) ----

* tick: the start of a tick
ttick   lda     #TICKLEN-1
        sta     <cnt
        ldu     #tdp
        lda     #NV
        sta     <envn
        lda     <wait
        beq     @ev
        dec     <wait           ; still waiting: straight to the volumes
        ldx     #tenva
        bra     @go
@ev     ldx     #tev            ; events due
        nop
        nop
        nop
        brn     @ev
@go     stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        jmp     smp

* ev: the next event's handler and voice
tev     ldb     ,y+
        lda     ,y+
        ldu     #tdp
        leau    a,u
        ldx     #evtab
        ldx     b,x
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     tev
        jmp     smp
evtab   fdb     hpitch,hslide,hset,hramp,hdecay,hwave,hwait,hend

hpitch  ldd     ,y++
        std     INC,u
        ldd     #0
        std     SL,u
        ldx     #tev
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        jmp     smp

hslide  ldd     ,y++
        std     SL,u
        ldx     #tev
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     hslide
        jmp     smp

hset    ldb     VO,u            ; bias += old/2 - new/2
        lsrb
        stb     <old
        lda     ,y+
        sta     VO,u
        clrb
        std     VOL,u
        lsra
        nega
        adda    <old
        adda    <bias
        sta     <bias
        ldd     #0              ; hold
        std     DV,u
        sta     MD,u
        ldx     #tev
        stx     <task
        brn     hset
        jmp     smp

hramp   ldd     ,y++
        std     DV,u
        clr     MD,u
        ldx     #tev
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        jmp     smp

hdecay  lda     ,y+
        sta     K,u
        sta     MD,u            ; (k is never 0)
        ldx     #tev
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     hdecay
        jmp     smp

hwave   ldd     ,y++
        std     WV,u
        ldx     #tev
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     hwave
        jmp     smp

hwait   lda     ,y+             ; n ticks: this one and n - 1 more
        deca
        sta     <wait
        ldu     #tdp
        ldx     #tenva
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        jmp     smp

hend    ldx     #texit
        stx     <task
        jmp     smp

* enva: a voice's ramp (VOL += DV) or decay (VOL = VOL x K / 256)
tenva   lda     MD,u
        bne     @dk
        ldd     VOL,u
        addd    DV,u
        nop
        brn     @dk
        bra     @j
@dk     lda     VOL,u
        ldb     K,u
        mul
@j      std     VOL,u
        sta     VO,u
        ldx     #tenvb
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     @j
        jmp     smp

* envb: a voice's slide; then the next voice, or the bias
tenvb   ldd     SL,u
        addd    INC,u
        std     INC,u
        leau    16,u
        ldx     #tenva
        dec     <envn
        bne     @a
        ldx     #tbias
        bra     @c
@a      brn     @a
        brn     @a
@c      stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        jmp     smp

* bias: 128 - (sum of volumes)/2
tbias   lda     <v0+VO
        adda    <v1+VO
        adda    <v2+VO
        adda    <v3+VO
        lsra
        nega
        adda    #128
        sta     <bias
        ldx     #tkey
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     tbias
        jmp     smp

* key: a key pressed (after all keys were up) stops the tune
tkey    ldx     #tidle
        clr     $FF02
        lda     $FF00
        ora     #$80
        coma
        beq     @up
        tst     <keyup
        beq     @k
        ldx     #texit
        bra     @k
@up     lda     #1
        sta     <keyup
        brn     @up
@k      ldb     #$FF
        stb     $FF02
        stx     <task
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     @k
        brn     @k
        jmp     smp

* idle: until the tick is over (tick's cnt counts down to 0 at its last sample)
tidle   lda     <cnt
        bne     @a
        ldx     #ttick
        stx     <task
        bra     @c
@a      brn     @a
        brn     @a
        brn     @a
        nop
@c      nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        brn     @c
        jmp     smp

texit   lda     #$82            ; glide back down to 0
        ldb     #-4
        lbsr    glide
        lda     <s01            ; sound back as it was
        sta     $FF01
        lda     <s03
        sta     $FF03
        lda     <s23
        sta     $FF23
        puls    cc,dp,d,x,y,u,pc

* glide: the DAC from A in 32 steps of B (4 = one DAC step), about 23 ms
glide   ldx     #32
@s      sta     $FF20
        pshs    b
        clrb
@d      decb
        bne     @d
        puls    b
        pshs    b
        adda    ,s+
        leax    -1,x
        bne     @s
        rts

        setdp   0
        include "tunes.asm"
