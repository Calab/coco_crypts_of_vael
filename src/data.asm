* Crypts of Vael - the data file, VAELDATA.DAT (a raw image of bank $3D; later $3E too).
* Assembled on its own (Makefile); the game reads it from the disk at start-up (dload.asm) and gets
* the addresses below from build/data.sym. Everything here is only ever read with BANKDAT mapped at
* $C000-$DFFF.

        org     $C000
        include "icons.asm"
        include "monsters.asm"
        include "tune.asm"
dataend
        ifgt    dataend-$E000
        error   "the data is over 8K: start using the second block ($3E)"
        endc
