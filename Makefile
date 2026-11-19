# Crypts of Vael - CoCo 3 build
#
#   make            build build/vael.dsk: VAEL.BIN (the game) and VAELDATA.DAT (its data file)
#                   (on a CoCo: LOADM"VAEL":EXEC)
#   make run        run it in XRoar on an RGB monitor (window), with the disk in drive 0
#   make run-cmp    run it in XRoar on a composite monitor (window)
#   make shot       build a variant that answers the monitor question itself (SHOT_MON, default R)
#                   plus any SHOT_DEFS, run it headless until it reaches SHOT_AT (the SHOT_N'th time),
#                   and save $(SHOTDIR)/$(SHOT_NAME).png
#   make fontshot   the font test screen          -> $(SHOTDIR)/font.png
#   make askshot    the monitor question          -> $(SHOTDIR)/monitor-ask.png
#   make walk       walk WALK frames by the left-hand rule, print draw timings, save the last frame
#   make mazecheck  compare mazes with the web version for SEEDS (needs gjs)
#   make shapes     regenerate src/icons.asm and src/monsters.asm from the reference (needs gjs)
#   make keys       type KEYS (e.g. KEYS="12345/M/T L/"; / = ENTER, ~ = wait a second) instead of
#                   the keyboard, save the final screen -> $(SHOTDIR)/keys.png
#   make profile    where a frame's time goes (see below)
#   make clean

LWASM   = lwasm
XROAR   = xroar
PYTHON  = python3

BUILD   = build
SRC     = src
SHOTDIR = /home/steve/tmp

DISK        = $(BUILD)/vael.dsk
XROAR_FLAGS = -machine coco3 -ram 128 -load-fd0 $(DISK)
SHOT_AT   ?= framedone   # symbol where the headless run takes its snapshot
SHOT_N    ?= 1           # ...on the N'th time it gets there
SHOT_NAME ?= vael
SHOT_MON  ?= R           # monitor answer baked into the screenshot build: R or C
SHOT_DEFS ?=             # extra lwasm -D options
SHOT_SECS ?= 100         # give up after this many seconds of emulated time
WALK      ?= 40
SEEDS     ?= 0 1 12345 4294967295 VAEL

GENERATED = $(BUILD)/font.asm $(BUILD)/tables.asm $(BUILD)/data.sym
SOURCES = $(wildcard $(SRC)/*.asm $(SRC)/*.inc) $(GENERATED)
ASM = $(LWASM) --format=decb -I $(SRC) -I $(BUILD) --symbols

all: $(DISK)

$(BUILD):
	mkdir -p $@

$(BUILD)/font.asm: $(SRC)/font.txt tools/font2asm.py | $(BUILD)
	$(PYTHON) tools/font2asm.py $< $@

$(BUILD)/tables.asm: tools/mktables.py | $(BUILD)
	$(PYTHON) $< $@

# The data file (a raw image of bank $3D) and the addresses the game needs from it
$(BUILD)/vaeldata.dat $(BUILD)/data.sym: $(SRC)/data.asm $(SRC)/icons.asm $(SRC)/monsters.asm | $(BUILD)
	$(LWASM) --format=raw -I $(SRC) --symbol-dump=$(BUILD)/data.sym -o $(BUILD)/vaeldata.dat $(SRC)/data.asm

# Assemble, then move the banked parts to load addresses LOADM can use (tools/relocate.py)
# DEFS: extra lwasm options for trying things, e.g. make -B run DEFS=-DLADCOL=175 (-B forces a rebuild;
# write numbers in decimal, since the shell eats a leading $)
$(BUILD)/vael.bin: $(SOURCES) tools/relocate.py | $(BUILD)
	$(ASM) $(DEFS) --list=$(BUILD)/vael.lst --symbol-dump=$(BUILD)/vael.sym -o $(BUILD)/vael.raw $(SRC)/main.asm
	$(PYTHON) tools/relocate.py $(BUILD)/vael.raw $@

$(DISK): $(BUILD)/vael.bin $(BUILD)/vaeldata.dat tools/mkdsk.py
	$(PYTHON) tools/mkdsk.py $@ VAEL.BIN=$(BUILD)/vael.bin VAELDATA.DAT=$(BUILD)/vaeldata.dat:1

run: $(DISK)
	$(XROAR) $(XROAR_FLAGS) -tv-input rgb -run $(BUILD)/vael.bin

run-cmp: $(DISK)
	$(XROAR) $(XROAR_FLAGS) -tv-input cmp -run $(BUILD)/vael.bin

shot: $(SOURCES) $(DISK) | $(BUILD)
	$(ASM) -D AUTOMON=$$(printf '%d' "'$(strip $(SHOT_MON))") $(SHOT_DEFS) --list=$(BUILD)/shot.lst \
	    --symbol-dump=$(BUILD)/shot.sym -o $(BUILD)/shot.raw $(SRC)/main.asm
	$(PYTHON) tools/relocate.py $(BUILD)/shot.raw $(BUILD)/shot.bin
	@addr=$$(awk '$$1=="$(strip $(SHOT_AT))" {sub(/\$$/,"",$$3); print $$3}' $(BUILD)/shot.sym); \
	test -n "$$addr" || { echo "symbol $(SHOT_AT) not found"; exit 1; }; \
	rm -f $(BUILD)/shot.sna; \
	timeout 300 $(XROAR) $(XROAR_FLAGS) -ui null -ao null -no-ratelimit -run $(BUILD)/shot.bin \
	    -trap pc=0x$$addr -trap-range $(strip $(SHOT_N)) -trap-snap $(BUILD)/shot.sna \
	    -trap-timeout 0 -timeout $(strip $(SHOT_SECS)) >/dev/null 2>&1; \
	test -f $(BUILD)/shot.sna || { echo "program never reached $(SHOT_AT) (0x$$addr)"; exit 1; }
	@mkdir -p $(SHOTDIR)
	$(PYTHON) tools/snap2png.py $(BUILD)/shot.sna $(BUILD)/shot.sym $(SHOTDIR)/$(SHOT_NAME).png
	@echo "wrote $(SHOTDIR)/$(SHOT_NAME).png"

fontshot:
	$(MAKE) shot SHOT_DEFS=-DFONTTEST SHOT_AT=done SHOT_NAME=font

askshot:
	$(MAKE) shot SHOT_AT=askshown SHOT_NAME=monitor-ask

walk:
	$(MAKE) shot SHOT_DEFS="-DAUTOWALK=$(WALK) -DSTARTLIGHT=7" SHOT_AT=walkdone SHOT_NAME=walk
	$(PYTHON) tools/timing.py $(BUILD)/shot.sna $(BUILD)/shot.sym

mazecheck: $(DISK)
	$(PYTHON) tools/mazecheck.py $(SEEDS)

# Regenerate src/icons.asm and src/monsters.asm from the reference's shapes (needs gjs; the result is
# kept in src/ so a normal build doesn't need gjs)
shapes: | $(BUILD)
	gjs -m tools/refshapes.js ICON > $(BUILD)/icons.json
	$(PYTHON) tools/mkicons.py $(BUILD)/icons.json $(SRC)/icons.asm
	gjs -m tools/refshapes.js SHAPE > $(BUILD)/shapes.json
	$(PYTHON) tools/mkicons.py $(BUILD)/shapes.json $(SRC)/monsters.asm --monsters

keys: | $(BUILD)
	printf '        fcc     "%s"\n' "$(KEYS)" > $(BUILD)/autokeys.inc
	$(MAKE) shot SHOT_DEFS=-DAUTOKEYS SHOT_AT=walkdone SHOT_NAME=keys

# Profile one frame: build with SHOT_DEFS, trace the PROF_N'th render with XRoar (big temporary file),
# then add up the cycles per routine. e.g. make profile SHOT_DEFS="-DAUTOWALK=80 -DSTARTLIGHT=7 -DSEEDVAL=0" PROF_N=26
PROF_N ?= 2
profile: $(SOURCES) $(DISK) | $(BUILD)
	$(ASM) $(SHOT_DEFS) -D AUTOMON=82 --symbol-dump=$(BUILD)/prof.sym -o $(BUILD)/prof.raw $(SRC)/main.asm
	$(PYTHON) tools/relocate.py $(BUILD)/prof.raw $(BUILD)/prof.bin
	@addr=$$(awk '$$1=="render" {sub(/\$$/,"",$$3); print $$3}' $(BUILD)/prof.sym); \
	timeout 300 $(XROAR) $(XROAR_FLAGS) -ui null -ao null -no-ratelimit -run $(BUILD)/prof.bin \
	    -trap pc=0x$$addr -trap-range $(PROF_N) -trap-trace-n 2000000 -trace-timing -timeout 100 \
	    > $(BUILD)/trace.txt 2>&1 || true
	$(PYTHON) tools/profile.py $(BUILD)/trace.txt $(BUILD)/prof.sym
	rm -f $(BUILD)/trace.txt

clean:
	rm -rf $(BUILD)

.PHONY: all run run-cmp shot fontshot askshot walk mazecheck keys shapes profile clean
