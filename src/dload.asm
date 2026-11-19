* Loading the data file, VAELDATA.DAT, from the disk the game was loaded from.
*
* This is the one place the game uses a ROM routine: Disk BASIC's DSKCON, to read sectors, in the
* game's first moments while BASIC is still running (start calls dataload before taking over).
* The data can't go straight to its banks ($3D, $3E): BASIC is running out of them. So it's parked
* in the second screen page's blocks ($34, $35), which BASIC doesn't use, and dataplace copies it
* across once the game owns the machine.

* Disk BASIC 1.1
DCOPC   equ     $00EA           ; DSKCON: operation (2 = read a sector)
DCDRV   equ     $00EB           ;         drive
DCTRK   equ     $00EC           ;         track
DSEC    equ     $00ED           ;         sector
DCBPT   equ     $00EE           ;         buffer address
DCSTA   equ     $00F0           ;         status (0 = OK)
DEFDRV  equ     $095A           ; the default drive (the one LOADM used, unless it named one)
DSKCONV equ     $C004           ; holds DSKCON's address
STAGEBLK equ    $34             ; staging: two blocks of screen page 1
DATABLKS equ    2               ; how many 8K blocks of data at most ($3D, $3E)

* dataload: read VAELDATA.DAT into the staging blocks. Sets dlok to 1 if that worked.
dataload
        clr     dlok
        lda     DEFDRV
        sta     DCDRV
        lda     #17             ; the granule table: track 17, sector 2
        ldb     #2
        lbsr    rdsec
        lbne    @fail
        ldx     #secbuf
        ldu     #dfat
        ldb     #68
@fat    lda     ,x+
        sta     ,u+
        decb
        bne     @fat
        ldb     #3              ; the directory: track 17, sectors 3-11
@dsec   stb     dds
        lda     #17
        lbsr    rdsec
        lbne    @fail
        ldx     #secbuf
@ent    ldu     #dname          ; this entry's name and extension?
        ldb     #11
        pshs    x
@cmp    lda     ,x+
        cmpa    ,u+
        bne     @diff
        decb
        bne     @cmp
        puls    x
        bra     @found
@diff   puls    x
        leax    32,x
        cmpx    #secbuf+256
        blo     @ent
        ldb     dds
        incb
        cmpb    #12
        blo     @dsec
        bra     @fail
@found  lda     13,x            ; first granule
        sta     dgran
        clr     dstg
@gran   ldb     dgran           ; this granule's track and first sector
        lsrb
        cmpb    #17
        blo     @t
        incb
@t      stb     dtrk
        lda     #1
        ldb     dgran
        bitb    #1
        beq     @s
        lda     #10
@s      sta     dsct
        ldx     #dfat           ; how many of its 9 sectors: all, or what the table says for the last
        ldb     dgran
        lda     b,x
        sta     dnext
        ldb     #9
        cmpa    #$C0
        blo     @n
        anda    #$3F
        tfr     a,b
@n      stb     dcnt
@sect   lda     dstg            ; room left for it?
        cmpa    #DATABLKS*32
        bhs     @full
        lda     dtrk
        ldb     dsct
        lbsr    rdsec
        bne     @fail
        lbsr    stage
        inc     dstg
        inc     dsct
        dec     dcnt
        bne     @sect
        lda     dnext           ; the next granule, unless that was the last
        cmpa    #$C0
        bhs     @done
        sta     dgran
        bra     @gran
@done
@full   lda     #1
        sta     dlok
@fail   rts

* rdsec: A = track, B = sector. Reads it into secbuf. EQ if it worked.
rdsec   sta     DCTRK
        stb     DSEC
        lda     #2
        sta     DCOPC
        ldx     #secbuf
        stx     DCBPT
        jsr     [DSKCONV]
        tst     DCSTA
        rts

* stage: copy secbuf to staging sector dstg (0-63): block STAGEBLK + dstg/32, at (dstg%32)*256.
* The block is mapped at $8000 for a moment, with interrupts off; BASIC's own block goes back after.
stage   pshs    cc
        orcc    #$50
        lda     MMUT0+4
        pshs    a
        lda     dstg
        lsra
        lsra
        lsra
        lsra
        lsra
        adda    #STAGEBLK
        sta     MMUT0+4
        lda     dstg
        anda    #31
        clrb
        addd    #$8000
        tfr     d,u
        ldx     #secbuf
        ldb     #128
@copy   lda     ,x+
        sta     ,u+
        lda     ,x+
        sta     ,u+
        decb
        bne     @copy
        puls    a
        sta     MMUT0+4
        puls    cc,pc

* dataplace: after the take-over: copy the staged blocks into the data banks ($3D, $3E), through
* CPU $4000 (source) and $6000 (destination). Leaves those two slots for the caller to set.
dataplace
        lda     #STAGEBLK
        ldb     #BANKDAT
@blk    sta     MMUT0+2
        stb     MMUT0+3
        pshs    d
        ldx     #$4000
        ldu     #$6000
@copy   ldd     ,x++
        std     ,u++
        cmpx    #$6000
        blo     @copy
        puls    d
        inca
        incb
        cmpb    #BANKDAT+DATABLKS
        blo     @blk
        rts

dname   fcc     "VAELDATADAT"
dlok    fcb     0
dds     fcb     0
dgran   fcb     0
dnext   fcb     0
dtrk    fcb     0
dsct    fcb     0
dcnt    fcb     0
dstg    fcb     0               ; sectors staged so far
dfat    fill    0,68
