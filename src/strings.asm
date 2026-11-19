* Words and messages (in the common bank). Message text is the reference's unless marked (ours).

* Verbs, in the reference's order (SAVE, LOAD, MUSIC, ANIMATE removed; MONITOR and the X test
* commands added at the end). Entry: flag (1 = must be typed in full), word, 0. The order decides
* abbreviations: the first verb that starts with what's typed wins (D = DROP, DE = DESCEND).
verbs   fcb     0
        fcn     "MOVE"          ; 0
        fcb     1
        fcn     "REVEAL"        ; 1
        fcb     0
        fcn     "TURN"          ; 2
        fcb     0
        fcn     "ATTACK"        ; 3
        fcb     0
        fcn     "GET"           ; 4
        fcb     0
        fcn     "DROP"          ; 5
        fcb     0
        fcn     "STOW"          ; 6
        fcb     0
        fcn     "PULL"          ; 7
        fcb     0
        fcn     "USE"           ; 8
        fcb     0
        fcn     "LOOK"          ; 9
        fcb     0
        fcn     "EXAMINE"       ; 10
        fcb     0
        fcn     "DESCEND"       ; 11
        fcb     0
        fcn     "ASCEND"        ; 12
        fcb     0
        fcn     "PAUSE"         ; 13 (V_PAUSE)
        fcb     1
        fcn     "QUIT"          ; 14
        fcb     0
        fcn     "SLEEP"         ; 15
        fcb     0
        fcn     "HELP"          ; 16
        fcb     0
        fcn     "SOUND"         ; 17
        fcb     0
        fcn     "SEED"          ; 18
        fcb     0
        fcn     "MONITOR"       ; 19
        fcb     1
        fcn     "XXX"           ; 20
        fcb     1
        fcn     "XLIGHT"        ; 21 test: cycle the light
        fcb     1
        fcn     "XJUMP"         ; 22 test: face the down ladder
        fcb     1
        fcn     "XDEPTH"        ; 23 test: XDEPTH n goes to level n
        fcb     1
        fcn     "XINFO"         ; 24 test: position, facing, draw time
        fcb     $FF

* Argument words
w_left  fcn     "LEFT"
w_right fcn     "RIGHT"
w_back  fcn     "BACK"
w_around fcn    "AROUND"
w_yes   fcn     "YES"
w_no    fcn     "NO"
w_seed  fcn     "SEED"
w_rgb   fcn     "RGB"
w_composite fcn "COMPOSITE"

* Status and command line
s_depth fcn     "DEPTH "
m_seedsp fcn    "   SEED "      ; (ours: PAUSE shows depth and seed)
s_seedhint fcn  "SEED (BLANK = RANDOM)"

* Messages
m_descend fcn   "YOU DESCEND INTO THE CRYPTS OF VAEL."
m_below fcn     "SOMEWHERE BELOW, THE HOLLOW KING GUARDS THE EMBER CROWN."
m_mazeseed fcn  "MAZE SEED: "
m_resumed fcn   "GAME RESUMED."
m_startover fcn "START OVER IN MAZE "
m_answeryn fcn  "? ANSWER Y OR N."
m_stay  fcn     "YOU STAY WHERE YOU ARE."
m_quityn fcn    "QUIT THIS GAME? ANSWER Y OR N."
m_presson fcn   "YOU PRESS ON."
m_what  fcn     "???  (TYPE HELP)"
m_ouch  fcn     "YOU WALK INTO A STONE WALL. OUCH!"
m_ladder fcn    "A LADDER LEADS DOWN INTO THE DARK."     ; (reference ends "(DESCEND)"; dropped)
m_turnwhich fcn "TURN LEFT, RIGHT OR AROUND?"
m_nodown fcn    "THERE IS NO WAY DOWN HERE."
m_noup  fcn     "THERE IS NO WAY UP HERE."
m_climbdown fcn "YOU CLIMB DOWN TO DEPTH "
m_climbup fcn   "YOU CLIMB UP TO DEPTH "
m_dot   fcn     "."
m_tomb  fcn     "THE AIR HERE IS COLD AS A TOMB."
m_notyet fcn    "NOT READY YET."                ; (ours, until the command exists)
m_monwhich fcn  "MONITOR RGB OR COMPOSITE?"     ; (ours)
m_monrgb fcn    "MONITOR SET TO RGB."           ; (ours)
m_moncmp fcn    "MONITOR SET TO COMPOSITE."     ; (ours)
m_lant  fcn     "LIGHT: LANTERN."               ; (ours, test)
m_torch fcn     "LIGHT: TORCH."                 ; (ours, test)
m_none  fcn     "LIGHT: NONE."                  ; (ours, test)
m_xdepth fcn    "XDEPTH 1 TO 5."                ; (ours, test)
m_at    fcn     "AT "                           ; (ours, test: XINFO)
m_comma fcn     ","
m_facing fcn    " FACING "
m_draw  fcn     ". DRAW "
m_sixty fcn     "/60 SEC."

* The Y/N questions, shown in the middle of the view (the reference's overlay text; its answers are on
* one line there, which doesn't fit 40 columns, so here they're stacked)
o_start fcn     "START OVER IN MAZE "
o_starty fcn    "Y = NEW MAZE"
o_startn fcn    "N = STAY WHERE YOU ARE"
o_quit  fcn     "QUIT THIS GAME?"
o_quity fcn     "Y = RETURN TO THE TITLE"
o_quitn fcn     "N = KEEP PLAYING"
o_paused fcn    "PAUSED"
o_resume fcn    "ENTER ANY COMMAND TO RESUME"
