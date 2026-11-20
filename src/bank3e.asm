* Bank BANKSND's attack pictures and HELP text (the data file's second 8K from $1100, read with the
* bank at $C000): assembled on its own, raw, into build/fx.dat (tools/joindata.py places it).
        include "fxpics.asm"    ; org $D100 (FXTAB), from tools/mkfx.py
HELPTAB equ     $DD40           ; (the game has the same constant, in help.asm)
        ifgt    fxend-HELPTAB
        error   "the attack pictures run into the HELP text: move HELPTAB (here and in help.asm)"
        endc
        fill    0,HELPTAB-*     ; (raw output doesn't fill an org's gap: pad up to it)
        include "helptext.asm"
bank3eend
        ifgt    bank3eend-$E000
        error   "bank $3E is full"
        endc
