    .pc = $0801 "autostart"
    :BasicUpstart(entry)

    .pc = $080d "entry"
entry:
    sei

    // Bank out BASIC and kernal ROMs
    lda #$35
    sta $01

    jsr mask_nmi

    // Turn off CIA interrupts
    lda #$7f
    sta $dc0d
    sta $dd0d

    // Enable raster interrupts
    lda #$01
    sta $d01a

    jsr init

    // Ack CIA interrupts
    lda $dc0d
    lda $dd0d

    // Ack VIC interrupts
    asl $d019

    cli

    jmp *

    .pc = * "mask nmi"
mask_nmi:
    // Stop timer A
    lda #$00
    sta $dd0e

    // Set timer A to 0 after starting
    sta $dd04
    sta $dd05

    // Set timer A as NMI source
    lda #$81
    sta $dd0d

    // Set NMI vector
    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb

    // Start timer A (NMI triggers immediately)
    lda #$01
    sta $dd0e

    rts

nmi:
    rti

    .const background_bitmap_pos = $4000
    .const background_screen_mem_pos = $6000
    .const background_sprite_pos = $7000

    .pc = * "init"
init:
    // Reset graphics mode/scroll
    lda #$1b
    sta $d011

    // Set initial color mem contents
    lda #$01
    ldx #$00
!:      sta $d800, x
        sta $d900, x
        sta $da00, x
        sta $db00, x
    inx
    bne !-

    // Set initial screen mem contents
    lda #$6e
    ldx #$00
!:      sta background_screen_mem_pos, x
        sta background_screen_mem_pos + $100, x
        sta background_screen_mem_pos + $200, x
        sta background_screen_mem_pos + $300, x
    inx
    bne !-

    // Set up frame interrupt
    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$ff
    sta $d012

    // Init music
    lda #$00
    tax
    tay
    jsr music

    rts

    .pc = * "frame"
frame:
    pha
    txa
    pha
    tya
    pha

    // Set multicolor bitmap mode
    lda #$3b
    sta $d011
    lda #$18
    sta $d016

    // Set graphics/screen pointers
    lda #$80
    sta $d018

    // Set graphics bank 1
    lda $dd00
    and #$fc
    ora #$02
    sta $dd00

    // Set background colors
    lda #$00
    //sta $d020
    sta $d021

    // Update music
    inc $d020
    jsr music + 3
    dec $d020

    // Set 2x interrupt
    lda #<music2x
    sta $fffe
    lda #>music2x
    sta $ffff
    lda #99
    sta $d012

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .pc = * "music 2x"
music2x:
    pha
    txa
    pha
    tya
    pha

    // Update music 2x
    inc $d020
    jsr music + 6
    dec $d020

    // Reset frame interrupt
    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$ff
    sta $d012

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .pc = $1000 "music"
music:
    .import c64 "music.prg"

    .pc = background_bitmap_pos "background bitmap"
background_bitmap:
    .import binary "build/background_bitmap.bin"
