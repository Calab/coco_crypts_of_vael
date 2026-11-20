* Bank BANKSND's attack pictures and HELP text (the data file's second 8K from $1100, read with the
* bank at $C000): assembled on its own, raw, into build/fx.dat (tools/joindata.py places it).
        include "fxpics.asm"    ; org $D100 (FXTAB), from tools/mkfx.py
HELPTAB equ     $DD40           ; (the game has the same constant, in help.asm)
        ifgt    fxend-HELPTAB
        error   "the attack pictures run into the HELP text: move HELPTAB (here and in help.asm)"
        endc
TESTMSG equ     $DC00           ; seed 0's message (the game has the same constant, in cmd.asm)
        ifgt    fxend-TESTMSG
        error   "the attack pictures run into TESTMSG: move it (here and in cmd.asm)"
        endc
        fill    0,TESTMSG-*     ; (raw output doesn't fill an org's gap: pad up to it)
* The reference's "TEST MAZE: ONE OF EVERY MONSTER SLEEPS ALONG THE PATH AHEAD. STRIKE ONE TO WAKE IT.",
* shortened (agreed with Steve, 2026-11-20) so it wraps at 40 columns as two lines
        fcn     "TEST MAZE: ONE OF EACH MONSTER SLEEPS ALONG THE PATH. STRIKE ONE TO WAKE IT."
        fill    0,HELPTAB-*
        include "helptext.asm"
bank3eend
        ifgt    bank3eend-$E000
        error   "bank $3E is full"
        endc
