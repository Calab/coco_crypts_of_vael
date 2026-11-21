* The HELP screen's text (the reference's HELP_PAGE and footer, fitted to 40 columns), one line per
* screen row from row 0, in bank BANKSND at HELPTAB (src/bank3e.asm). In a line: "{" switches to the
* heading colour (mid white), "~" jumps to column 24 for the note (mid white), "}" switches to cyan,
* "|" is drawn as the font's BAR; the rest is green. $FF ends the screen. Never mention REVEAL here (Steve).
*
* Shortened from the reference (agreed with Steve, 2026-11-20): STRIKE WITH THAT HAND -> STRIKE WITH IT;
* PICK UP INTO A HAND -> TAKE INTO A HAND; PUT DOWN WHAT IT HOLDS -> PUT IT DOWN; PUT IT IN YOUR PACK
* -> PUT IN YOUR PACK; TAKE IT FROM YOUR PACK -> TAKE FROM PACK; LIGHT, DRINK, READ -> LIGHT/DRINK/
* READ; SHOW OR CHANGE THE MAZE -> SHOW/CHANGE MAZE; the footer's three lines below. Left out: the
* title COMMANDS, SAVE / LOAD, MUSIC, ANIMATE (removed). Added: MONITOR, INVENTORY.
        fcn     "{MOVING~}  LOOK TO RETURN"
        fcn     " MOVE~STEP FORWARD"
        fcn     " MOVE BACK|LEFT|RIGHT~STEP THAT WAY"
        fcn     " TURN LEFT|RIGHT|AROUND~FACE A NEW WAY"
        fcn     " DESCEND / ASCEND~TAKE A LADDER"
        fcn     " SLEEP [1-20]~REST TO HEAL"
        fcn     "{FIGHTING"
        fcn     " ATTACK L|R~STRIKE WITH IT"
        fcn     "{ITEMS"
        fcn     " GET L|R [ITEM]~TAKE INTO A HAND"
        fcn     " DROP L|R~PUT IT DOWN"
        fcn     " STOW L|R~PUT IN YOUR PACK"
        fcn     " PULL L|R ITEM~TAKE FROM PACK"
        fcn     " USE L|R OR USE ITEM~LIGHT/DRINK/READ"
        fcn     " EXAMINE / INVENTORY~SEE YOUR PACK"
        fcn     "{GAME"
        fcn     " PAUSE / QUIT"
        fcn     " SEED [NUMBER]~SHOW/CHANGE MAZE"
        fcn     " SOUND [0-9]~VOLUME, 0 IS OFF"
        fcn     " MONITOR RGB|COMPOSITE~SET THE COLOURS"
        fcn     "L|R = LEFT OR RIGHT HAND. ENTER REPEATS."
        fcn     "WORDS MAY BE SHORTENED (M = MOVE)."
        fcn     "STEPS TIRE YOU. STAND STILL TO RECOVER."
        fcb     $FF,0
