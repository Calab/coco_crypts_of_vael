# Crypts of Vael - CoCo 3 build
#
#   make            assemble build/vael.bin
#   make run        run it in XRoar on an RGB monitor (window)
#   make run-cmp    run it in XRoar on a composite monitor (window)
#   make shot       build a variant that answers the monitor question itself (SHOT_MON, default R)
#                   plus any SHOT_DEFS, run it headless until it reaches SHOT_AT (the SHOT_N'th time),
#                   and save $(SHOTDIR)/$(SHOT_NAME).png
#   make fontshot   the font test screen          -> $(SHOTDIR)/font.png
#   make askshot    the monitor question          -> $(SHOTDIR)/monitor-ask.png
#   make walk       walk WALK frames by the left-hand rule, print draw timings, save the last frame
#   make mazecheck  compare mazes with the web version for SEEDS (needs gjs)
#   make keys       act out KEYS (U D L R T 1-5, e.g. KEYS=UUL2) instead of reading the keyboard,
#                   save the final screen -> $(SHOTDIR)/keys.png
#   make clean

LWASM   = lwasm
XROAR   = xroar
PYTHON  = python3

BUILD   = build
SRC     = src
SHOTDIR = /home/steve/tmp

XROAR_FLAGS = -machine coco3 -ram 128
SHOT_AT   ?= framedone   # symbol where the headless run takes its snapshot
SHOT_N    ?= 1           # ...on the N'th time it gets there
SHOT_NAME ?= vael
SHOT_MON  ?= R           # monitor answer baked into the screenshot build: R or C
SHOT_DEFS ?=             # extra lwasm -D options
WALK      ?= 40
SEEDS     ?= 0 1 12345 4294967295 VAEL

GENERATED = $(BUILD)/font.asm $(BUILD)/tables.asm
SOURCES = $(wildcard $(SRC)/*.asm $(SRC)/*.inc) $(GENERATED)
ASM = $(LWASM) --format=decb -I $(SRC) -I $(BUILD) --symbols

all: $(BUILD)/vael.bin

$(BUILD):
	mkdir -p $@

$(BUILD)/font.asm: $(SRC)/font.txt tools/font2asm.py | $(BUILD)
	$(PYTHON) tools/font2asm.py $< $@

$(BUILD)/tables.asm: tools/mktables.py | $(BUILD)
	$(PYTHON) $< $@

# Assemble, then move the banked parts to load addresses LOADM can use (tools/relocate.py)
# DEFS: extra lwasm options for trying things, e.g. make -B run DEFS=-DLADCOL=175 (-B forces a rebuild;
# write numbers in decimal, since the shell eats a leading $)
$(BUILD)/vael.bin: $(SOURCES) tools/relocate.py | $(BUILD)
	$(ASM) $(DEFS) --list=$(BUILD)/vael.lst --symbol-dump=$(BUILD)/vael.sym -o $(BUILD)/vael.raw $(SRC)/main.asm
	$(PYTHON) tools/relocate.py $(BUILD)/vael.raw $@

run: $(BUILD)/vael.bin
	$(XROAR) $(XROAR_FLAGS) -tv-input rgb -run $<

run-cmp: $(BUILD)/vael.bin
	$(XROAR) $(XROAR_FLAGS) -tv-input cmp -run $<

shot: $(SOURCES) | $(BUILD)
	$(ASM) -D AUTOMON=$$(printf '%d' "'$(strip $(SHOT_MON))") $(SHOT_DEFS) --list=$(BUILD)/shot.lst \
	    --symbol-dump=$(BUILD)/shot.sym -o $(BUILD)/shot.raw $(SRC)/main.asm
	$(PYTHON) tools/relocate.py $(BUILD)/shot.raw $(BUILD)/shot.bin
	@addr=$$(awk '$$1=="$(strip $(SHOT_AT))" {sub(/\$$/,"",$$3); print $$3}' $(BUILD)/shot.sym); \
	test -n "$$addr" || { echo "symbol $(SHOT_AT) not found"; exit 1; }; \
	rm -f $(BUILD)/shot.sna; \
	timeout 120 $(XROAR) $(XROAR_FLAGS) -ui null -ao null -no-ratelimit -run $(BUILD)/shot.bin \
	    -trap pc=0x$$addr -trap-range $(strip $(SHOT_N)) -trap-snap $(BUILD)/shot.sna \
	    -trap-timeout 0 -timeout 100 >/dev/null 2>&1; \
	test -f $(BUILD)/shot.sna || { echo "program never reached $(SHOT_AT) (0x$$addr)"; exit 1; }
	@mkdir -p $(SHOTDIR)
	$(PYTHON) tools/snap2png.py $(BUILD)/shot.sna $(BUILD)/shot.sym $(SHOTDIR)/$(SHOT_NAME).png
	@echo "wrote $(SHOTDIR)/$(SHOT_NAME).png"

fontshot:
	$(MAKE) shot SHOT_DEFS=-DFONTTEST SHOT_AT=done SHOT_NAME=font

askshot:
	$(MAKE) shot SHOT_AT=askshown SHOT_NAME=monitor-ask

walk:
	$(MAKE) shot SHOT_DEFS=-DAUTOWALK=$(WALK) SHOT_AT=walkdone SHOT_NAME=walk
	$(PYTHON) tools/timing.py $(BUILD)/shot.sna $(BUILD)/shot.sym

mazecheck:
	$(PYTHON) tools/mazecheck.py $(SEEDS)

keys: | $(BUILD)
	printf '        fcc     "%s"\n' "$(KEYS)" > $(BUILD)/autokeys.inc
	$(MAKE) shot SHOT_DEFS=-DAUTOKEYS SHOT_AT=walkdone SHOT_NAME=keys

clean:
	rm -rf $(BUILD)

.PHONY: all run run-cmp shot fontshot askshot walk mazecheck keys clean
