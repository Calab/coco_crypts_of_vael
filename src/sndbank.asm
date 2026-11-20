* Bank BANKSND ($3E), the second 8K of the data file: the sound engine's image at $C000 (copied to
* $FC00 at start-up; put there by tools/joindata.py, not assembled here), then the sound effects from
* $C400 (made by tools/mksfx.py). Assembled on its own, raw.
        include "sfx.asm"
sndbankend
        ifgt    sndbankend-$E000
        error   "the sound bank is over 8K"
        endc
