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

    .const zp_base = $02

    .const sprite_frame_index = zp_base
    .const sprite_frame_counter = zp_base + 1

    .const background_bitmap_pos = $4000
    .const background_screen_mem_pos = $6000

    .const sprite_pos = $7000
    .const sprite_data_ptr_pos = background_screen_mem_pos + $3f8

    .pc = * "init"
init:
    // Reset graphics mode/scroll
    lda #$1b
    sta $d011

    // Reset vars
    lda #$00
    sta sprite_frame_index
    sta sprite_frame_counter

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

    inc $d020

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

    // Set sprite positions
    //  Note these initial positions were taken straight from the spec image, so they'll need some transformation for actual reg values
    .const sprite_positions_x = List().add(  1,   8,  11,  76, 135, 143, 133, 138).lock()
    .const sprite_positions_y = List().add( 63,  43, 101,  76,  20,  47,  71, 110).lock()
    .var sprite_pos_x_msbs = 0
    .for (var i = 0; i < 8; i++) {
        .var x = sprite_positions_x.get(i) * 2 + $18
        .var y = sprite_positions_y.get(i) + $32
        .eval sprite_pos_x_msbs = (sprite_pos_x_msbs >> 1) | ((x >> 1) & $80)
        lda #(x & $ff)
        sta $d000 + i * 2
        lda #y
        sta $d001 + i * 2
    }
    lda #sprite_pos_x_msbs
    sta $d010

    // Set initial sprite colors
    lda #$06
    sta $d025
    lda #$01
    sta $d026
    lda #$0e
    .for (var i = 0; i < 8; i++) {
        sta $d027 + i
    }

    // Enable sprites
    lda #$ff
    sta $d015

    // Set sprite multicolor
    lda #$ff
    sta $d01c

    // Update sprite ptrs
    lda sprite_frame_index
    and #$07
    clc
    adc #$c0

    .for (var i = 0; i < 8; i++) {
        sta sprite_data_ptr_pos + i
        .if (i < 7) {
            clc
            adc #$08
        }
    }

    inc sprite_frame_counter
    lda sprite_frame_counter
    cmp #$03
    bne !+
        inc sprite_frame_index

        lda #$00
        sta sprite_frame_counter

    // Update music
!:  inc $d020
    jsr music + 3
    dec $d020

    // Set 2x interrupt
    lda #<music2x
    sta $fffe
    lda #>music2x
    sta $ffff
    lda #99
    sta $d012

    dec $d020

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

    .pc = sprite_pos "sprites"
sprites:
    .import binary "build/sprites_blob.bin"
