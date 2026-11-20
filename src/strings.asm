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
w_restart fcn   "RESTART"
w_quit  fcn     "QUIT"

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

* Maps
m_yourmap fcn   "YOUR MAP - DEPTH "
m_fullmap fcn   "FULL MAZE - DEPTH "    ; (reference: "FULL MAZE (TEST VIEW) - DEPTH n"; shortened to fit the counts)
m_sp3   fcn     "   "
m_foes  fcn     " FOES  "
m_itemsn fcn    " ITEMS"
m_maplegend fcn "V = DOWN  ^ = UP           LOOK TO CLOSE"   ; (ours: the reference colours V/^ instead)
m_mapclose fcn  "                           LOOK TO CLOSE"

* Item names (the reference's ITEMS), by kind number
inames  fdb     n_dagger,n_axe,n_sword,n_hammer,n_rune,n_buckler,n_tower,n_torch,n_lantern
        fdb     n_mending,n_herb,n_vigor,n_map,n_relic,n_crown
n_dagger fcn    "DAGGER"
n_axe   fcn     "HAND AXE"
n_sword fcn     "SHORT SWORD"
n_hammer fcn    "WAR HAMMER"
n_rune  fcn     "RUNE BLADE"
n_buckler fcn   "BUCKLER"
n_tower fcn     "TOWER SHIELD"
n_torch fcn     "PITCH TORCH"
n_lantern fcn   "OIL LANTERN"
n_mending fcn   "MENDING BREW"          ; (reference: MENDING DRAUGHT; renamed to fit the status row)
n_herb  fcn     "HEALING HERB"
n_vigor fcn     "VIGOR TONIC"
n_map   fcn     "DUNGEON MAP"
n_relic fcn     "GOLDEN RELIC"
n_crown fcn     "EMBER CROWN"
m_yousee fcn    "YOU SEE "
m_here  fcn     " HERE."
m_listsep fcn   ", "
m_a     fcn     "A "
m_an    fcn     "AN "

* Kind words (the reference's item kinds, as a name to match against: GET L MENDING)
ikwords fdb     k_dagger,k_axe,k_sword,k_hammer,k_rune,k_buckler,k_tower,k_torch,k_lantern
        fdb     k_mending,k_herb,k_vigor,k_map,k_relic,k_crown
k_dagger fcn    "DAGGER"
k_axe   fcn     "AXE"
k_sword fcn     "SWORD"
k_hammer fcn    "HAMMER"
k_rune  fcn     "RUNE"
k_buckler fcn   "BUCKLER"
k_tower fcn     "TOWER"
k_torch fcn     "TORCH"
k_lantern fcn   "LANTERN"
k_mending fcn   "MENDING"
k_herb  fcn     "HERB"
k_vigor fcn     "VIGOR"
k_map   fcn     "MAP"
k_relic fcn     "RELIC"
k_crown fcn     "CROWN"

* Item, light, health and experience messages (the reference's)
m_try   fcn     "TRY: PULL L TORCH, USE L, GET R DAGGER"         ; (agreed: shortened to fit)
m_your  fcn     "YOUR "
m_gutters fcn   " GUTTERS OUT. DARKNESS."
m_skilled fcn   "YOU GROW MORE SKILLED!  (RANK "
m_rparen fcn    ")"
m_dash  fcn     "YOU DASH YOURSELF AGAINST THE STONE."
m_perished fcn  "YOUR HEART FALLS SILENT. YOU HAVE PERISHED."
m_restart fcn   "TYPE RESTART TO RETURN TO THE TITLE."  ; (agreed: "AND PRESS ENTER" dropped)
m_over  fcn     "THE GAME IS OVER. TYPE RESTART TO RETURN TO THE TITLE."
m_leftright fcn " LEFT OR RIGHT?"
m_handfull fcn  " HAND IS FULL."
m_handempty fcn " HAND IS EMPTY."
m_nothing fcn   "NOTHING LIKE THAT HERE."
m_youtake fcn   "YOU TAKE THE "
m_youdrop fcn   "YOU DROP THE "
m_youstow fcn   "YOU STOW THE "
m_packfull fcn  "YOUR PACK IS FULL."
m_youpull fcn   "YOU PULL OUT THE "
m_nosuch fcn    "NO SUCH THING IN YOUR PACK."
m_packempty fcn "YOUR PACK IS EMPTY."
m_usewhat fcn   "USE LEFT, RIGHT, OR AN ITEM NAME."
m_nousable fcn  "YOU HAVE NO SUCH THING TO USE."
m_fight fcn     "USE ATTACK TO FIGHT WITH IT."
m_nothinghap fcn "NOTHING HAPPENS."
m_the   fcn     "THE "
m_flares fcn    " FLARES TO LIFE."
m_warmth fcn    "WARMTH FLOODS YOUR BODY."
m_stronger fcn  "YOU FEEL STRONGER. YOUR HEART STEADIES."
m_ancient fcn   "ANCIENT POWER FLOWS INTO YOU."
m_unfold fcn    "YOU UNFOLD YOUR MAP."  ; (agreed: the map says LOOK TO CLOSE)
m_dark  fcn     "IT IS DARK. YOU CAN BARELY SEE."

* The pack view (the reference's renderPack; its "s" for seconds is "S" here)
m_yourpack fcn  "YOUR PACK  ("
m_of8   fcn     "/8)"
m_floor fcn     "ON THE FLOOR"
m_pempty fcn    "- EMPTY -"
m_fnothing fcn  "- NOTHING -"
m_dotsp fcn     ". "
m_light fcn     "LIGHT: "
m_lnone fcn     "NONE"
m_lparen fcn    " ("
m_secs  fcn     "S)"
m_facing2 fcn   "FACING "
m_depth3 fcn    "   DEPTH "
m_slain fcn     "   FOES SLAIN "
m_rank  fcn     "RANK "
m_xp    fcn     " (XP "
m_dmg   fcn     ")   DMG +"
m_dodge fcn     "   DODGE "
m_pct   fcn     "%"
m_seedlbl fcn   "SEED "
m_lookret fcn   "TYPE LOOK TO RETURN"

* Status rows (the reference's L: / R: and health)
m_lcolon fcn    "L: "
m_rcolon fcn    "R: "
m_empty fcn     "EMPTY"
m_hp    fcn     "HP "
m_slash fcn     "/"

* Monster names (the reference's MON), by kind
mnames  fdb     n_mould,n_crawler,n_skeleton,n_hound,n_wraith,n_golem,n_king
n_mould fcn     "SLIME MOULD"
n_crawler fcn   "GLOOMCRAWLER"
n_skeleton fcn  "SKELETON"
n_hound fcn     "BONE HOUND"
n_wraith fcn    "ASH WRAITH"
n_golem fcn     "IRON GOLEM"
n_king  fcn     "HOLLOW KING"
m_face  fcn     "FACE TO FACE WITH THE "        ; (agreed: "YOU ARE" dropped)
m_bang  fcn     "!"
m_sleeps fcn    " SLEEPS RIGHT HERE."
m_inway fcn     " IS IN THE WAY. KILL IT FIRST."
m_guards fcn    " GUARDS IT. KILL IT FIRST."

* The simulation and combat (the reference's messages)
m_burst fcn     "YOUR HEART BURSTS FROM EXERTION."
m_hammers fcn   "YOUR HEART HAMMERS. YOU MUST REST!"
m_breathing fcn "YOU ARE BREATHING HARD."
m_faint fcn     "YOUR VISION DIMS... YOU FAINT!"
m_senses fcn    "YOU COME TO YOUR SENSES."
m_uncon fcn     "YOU ARE UNCONSCIOUS..."
m_stirs fcn     " STIRS AND NOTICES YOU!"
m_youhear fcn   "YOU HEAR "
m_nearby fcn    " NEARBY..."
m_lunges fcn    " LUNGES"
m_misses fcn    " AND MISSES."
m_dodge2 fcn    "YOU DEFTLY DODGE THE "
m_dodgeb fcn    "YOU DODGE A BLOW"      ; (agreed: side/behind, unnamed as SOMETHING STRIKES)
m_missesw fcn   " MISSES"               ; (agreed: side/behind, "THE X MISSES FROM THE LEFT.")
m_something fcn "SOMETHING"
m_strikes fcn   " STRIKES"
m_blocked fcn   " (BLOCKED SOME)"
mwhere  fdb     w_right2,w_behind,w_left2
w_right2 fcn    " FROM THE RIGHT"       ; (agreed: was FROM YOUR RIGHT/LEFT)
w_behind fcn    " FROM BEHIND"
w_left2 fcn     " FROM THE LEFT"
m_notready fcn  "YOUR ARM IS NOT READY."
m_emptyair fcn  "YOU SWING AT EMPTY AIR."
m_awakens fcn   " AWAKENS!"
m_youmiss fcn   "YOU MISS THE "
m_youhit fcn    "YOU HIT THE "
m_sp1   fcn     " "
m_itdrops fcn   "IT DROPS "
m_glows fcn     "SOMETHING GLOWS WHERE THE KING FELL..."
m_xxxnone fcn   "XXX: NO MONSTER NEXT TO YOU."
m_won   fcn     "THE CROWN BURNS WARM IN YOUR HAND. YOU HAVE WON!"
m_winded fcn    "WINDED"
m_exhausted fcn "EXHAUSTED"
m_xp2   fcn     "  XP "
msounds fdb     s_mould,s_crawler,s_skeleton,s_hound,s_wraith,s_golem,s_king
s_mould fcn     "A WET SQUELCH"
s_crawler fcn   "SKITTERING"
s_skeleton fcn  "RATTLING BONES"
s_hound fcn     "RASPING BREATH"
s_wraith fcn    "A HOLLOW MOAN"
s_golem fcn     "GRINDING IRON"
s_king  fcn     "A COLD LAUGH"
mdeaths fdb     d_mould,d_crawler,d_skeleton,d_hound,d_wraith,d_golem,d_king
d_mould fcn     "HISSES INTO A PUDDLE!" ; (agreed: the deaths shortened to fit 40)
d_crawler fcn   "CURLS UP AND DIES!"
d_skeleton fcn  "CRUMBLES INTO BONES!"
d_hound fcn     "CRUMBLES TO DUST!"
d_wraith fcn    "FADES WITH A MOAN!"     ; (Steve)
d_golem fcn     "TUMBLES WITH A CRASH!"
d_king  fcn     "SINKS INTO EMPTY ROBES!"

* SLEEP (the reference's)
m_sleephow fcn  "SLEEP HOW LONG? TYPE SLEEP 1 TO 20."    ; (agreed: shortened)
m_tooclose fcn  "YOU CANNOT SLEEP WITH ENEMIES SO CLOSE!"
m_wakeafter fcn "YOU WAKE AFTER "
m_move  fcn     " MOVE."
m_moves fcn     " MOVES."
m_jolted fcn    "YOU ARE JOLTED AWAKE AFTER "
m_move2 fcn     " MOVE!"
m_moves2 fcn    " MOVES!"
m_beside fcn    " IS RIGHT BESIDE YOU!"
m_somebeside fcn "SOMETHING IS RIGHT BESIDE YOU!"
m_health fcn    "HEALTH "
m_arrow fcn     " -> "
m_burnedout fcn " WENT OUT AS YOU SLEPT."        ; (agreed: shortened)
m_tooweak fcn   "YOU ARE STILL TOO WEAK TO STAND..."
m_neverwake fcn "YOU NEVER WAKE."
w_strikes fcn   "STRIKES"

* SOUND (the reference's)
m_sndoff fcn    "SOUND OFF."
m_sndvol fcn    "SOUND VOLUME "
m_sndon fcn     "SOUND ON, VOLUME "
m_sndrange fcn  " (0-9)."
