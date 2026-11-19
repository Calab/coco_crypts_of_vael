* Random numbers: the web version's mulberry32, bit-exact, in 32-bit integer maths.
* All 32-bit values are big-endian (most significant byte first), as the 6809 likes.
*
*   rng32   advance rngst; rngout = next 32-bit output (the JS code's RNG() * 2^32)
*   rndn    D = n (1..65535) -> D = floor(RNG() * n), i.e. the JS rnd(0, n-1) / pick() index
*   imul32  m_res = low 32 bits of m_x * m_y (Math.imul)

* rng32: one step of mulberry32
*   a = a + 0x6D2B79F5
*   t = imul(a ^ a>>>15, a | 1)
*   t = (t + imul(t ^ t>>>7, t | 61)) ^ t
*   out = t ^ t>>>14
rng32   ldd     rngst+2
        addd    #$79F5
        std     rngst+2
        ldd     rngst
        adcb    #$2B
        adca    #$6D
        std     rngst
        ldx     #rngst          ; m_x = a ^ a>>>15
        ldu     #m_x
        lda     #15
        lbsr     xsr
        ldd     rngst           ; m_y = a | 1
        std     m_y
        ldd     rngst+2
        orb     #1
        std     m_y+2
        lbsr     imul32
        ldd     m_res           ; t = m_res
        std     rngt
        ldd     m_res+2
        std     rngt+2
        ldx     #rngt           ; m_x = t ^ t>>>7
        ldu     #m_x
        lda     #7
        lbsr     xsr
        ldd     rngt            ; m_y = t | 61
        std     m_y
        ldd     rngt+2
        orb     #61
        std     m_y+2
        lbsr     imul32
        ldd     rngt+2          ; m_res = t + m_res
        addd    m_res+2
        std     m_res+2
        ldd     rngt
        adcb    m_res+1
        adca    m_res
        std     m_res
        ldd     m_res           ; t = m_res ^ t
        eora    rngt
        eorb    rngt+1
        std     rngt
        ldd     m_res+2
        eora    rngt+2
        eorb    rngt+3
        std     rngt+2
        ldx     #rngt           ; out = t ^ t>>>14
        ldu     #rngout
        lda     #14
        lbra     xsr

* xsr: X = source, U = destination, A = shift (1-31). [U] = [X] ^ ([X] >>> A)
xsr     pshs    a
        ldd     ,x
        std     xs_t
        ldd     2,x
        std     xs_t+2
@shift  lsr     xs_t
        ror     xs_t+1
        ror     xs_t+2
        ror     xs_t+3
        dec     ,s
        bne     @shift
        leas    1,s
        ldd     ,x
        eora    xs_t
        eorb    xs_t+1
        std     ,u
        ldd     2,x
        eora    xs_t+2
        eorb    xs_t+3
        std     2,u
        rts

* imul32: m_res = low 32 bits of m_x * m_y
imul32  ldd     #0
        std     m_res
        std     m_res+2
        ldd     #m_res
        std     m_top
        ldu     #imtab
        lbra     mulacc

* rndn: D = n. Returns D = floor(next * n / 2^32). Uses one RNG step.
rndn    std     m_n
        lbsr     rng32
        ldd     #0
        std     m_r6
        std     m_r6+2
        std     m_r6+4
        ldd     #m_r6
        std     m_top
        ldu     #rntab
        lbsr     mulacc
        ldd     m_r6            ; bits 32-47 of the 48-bit product
        rts

* mulacc: add up 8x8 partial products. U = table of (x byte addr, y byte addr, word addr)
* entries ending with 0. Each product is added to the 16-bit word at "word addr"; carries ripple
* toward m_top (the result's most significant byte) and stop there.
mulacc
@next   ldx     ,u++
        beq     @done
        lda     ,x
        ldx     ,u++
        ldb     ,x
        mul
        ldx     ,u++
        addd    ,x
        std     ,x
        bcc     @next
@carry  cmpx    m_top
        bls     @next
        leax    -1,x
        inc     ,x
        beq     @carry
        bra     @next
@done   rts

* Partial products for imul32. Byte k (0 = least significant) of a value V is at V+3-k.
* Product of x byte i and y byte j lands at position i+j: the word at m_res+2-(i+j).
* Position 3 only keeps its low byte: its word starts at the pad byte m_res-1.
imtab   fdb     m_x+3,m_y+3,m_res+2     ; i+j = 0
        fdb     m_x+3,m_y+2,m_res+1     ; 1
        fdb     m_x+2,m_y+3,m_res+1
        fdb     m_x+3,m_y+1,m_res+0     ; 2
        fdb     m_x+2,m_y+2,m_res+0
        fdb     m_x+1,m_y+3,m_res+0
        fdb     m_x+3,m_y+0,m_res-1     ; 3
        fdb     m_x+2,m_y+1,m_res-1
        fdb     m_x+1,m_y+2,m_res-1
        fdb     m_x+0,m_y+3,m_res-1
        fdb     0

* Partial products for rndn: rngout (4 bytes) x m_n (2 bytes) -> 48-bit m_r6.
* Byte k of m_r6 is at m_r6+5-k; position p's word is at m_r6+4-p.
rntab   fdb     rngout+3,m_n+1,m_r6+4   ; 0
        fdb     rngout+3,m_n+0,m_r6+3   ; 1
        fdb     rngout+2,m_n+1,m_r6+3
        fdb     rngout+2,m_n+0,m_r6+2   ; 2
        fdb     rngout+1,m_n+1,m_r6+2
        fdb     rngout+1,m_n+0,m_r6+1   ; 3
        fdb     rngout+0,m_n+1,m_r6+1
        fdb     rngout+0,m_n+0,m_r6+0   ; 4
        fdb     0

* RNG variables
rngst   fqb     0               ; mulberry32 state (a)
rngt    fqb     0               ; t
rngout  fqb     0               ; last output
xs_t    fqb     0
m_x     fqb     0
m_y     fqb     0
        fcb     0               ; pad: imul32's position-3 adds spill into here
m_res   fqb     0
m_n     fdb     0
m_r6    fcb     0,0,0,0,0,0
m_top   fdb     0
