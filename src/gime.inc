* GIME and other CoCo 3 hardware registers

INIT0   equ     $FF90           ; CoCo mode, MMU enable, interrupt enables, ROM map
INIT1   equ     $FF91           ; MMU task select, timer input clock
IRQENR  equ     $FF92           ; GIME IRQ enable / status
FIRQENR equ     $FF93           ; GIME FIRQ enable / status
TIMERHI equ     $FF94           ; 12-bit timer, high nibble
TIMERLO equ     $FF95
VMODE   equ     $FF98           ; video mode
VRES    equ     $FF99           ; video resolution
BORDER  equ     $FF9A           ; border colour
VOFFHI  equ     $FF9D           ; vertical offset (physical address / 8), bits 18-11
VOFFLO  equ     $FF9E           ;                                         bits 10-3
HOFF    equ     $FF9F           ; horizontal offset
MMUT0   equ     $FFA0           ; MMU task 0, eight 8K slots ($FFA0-$FFA7)
MMUT1   equ     $FFA8           ; MMU task 1
PALETTE equ     $FFB0           ; 16 palette registers ($FFB0-$FFBF)
SPEEDHI equ     $FFD9           ; write: CPU at 1.79 MHz

* Video mode values for 640x192, 4 colours
VMODE_GFX equ   $80             ; bit-plane graphics, 1 line per row
VRES_640x4 equ  $1D             ; 192 lines, 160 bytes per row, 4 colours

* Screen geometry
SCRW    equ     640
SCRH    equ     192
ROWB    equ     160             ; bytes per row
SCRBYTES equ    ROWB*SCRH       ; 30720

* Physical memory: 8K blocks $30-$3F exist on a 128K machine.
* Screen page 0 lives in blocks $30-$33 (physical $60000-$67FFF).
SCR0BLK equ     $30

* PIA 0: keyboard. Write a column mask to PIA0B (0 bit = column selected),
* read rows from PIA0A (0 bit = key down; bit 7 is the joystick comparator).
PIA0A   equ     $FF00
PIA0B   equ     $FF02
