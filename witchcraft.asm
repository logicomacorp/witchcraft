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

    .const scroller_offset = zp_base + 2

    .const background_bitmap_pos = $4000
    .const background_screen_mem_pos = $6000

    .const scroller_font_pos = $6800

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
    sta scroller_offset

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

    // Set scroller color mem contents
    lda #$00
    ldx #$00
!:      sta $d800 + 20 * 40, x
    inx
    cpx #40
    bne !-

    // Clear scroller screen mem (set to spaces, $20)
    lda #$20
    ldx #$00
!:      sta background_screen_mem_pos + 20 * 40, x
    inx
    cpx #40
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

    // Set background colors
    lda #$00
    sta $d020
    sta $d021

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

    // Update scroller
!:  dec scroller_offset
    lda scroller_offset
    and #$07
    sta scroller_offset

    cmp #$07
    beq !+
        jmp scroller_update_done
        // Shift screen mem
!:      .for (var i = 0; i < 39; i++) {
            lda background_screen_mem_pos + 20 * 40 + i + 1
            sta background_screen_mem_pos + 20 * 40 + i
        }

        // Load next char
scroller_text_load_instr:
        lda scroller_text
        sta background_screen_mem_pos + 20 * 40 + 39

        // Update (and possibly reset) text pointer
        inc scroller_text_load_instr + 1
        bne !+
            inc scroller_text_load_instr + 2
!:      lda scroller_text_load_instr + 1
        cmp #<scroller_text_end
        bne scroller_update_done
        lda scroller_text_load_instr + 2
        cmp #>scroller_text_end
        bne scroller_update_done
            lda #<scroller_text
            sta scroller_text_load_instr + 1
            lda #>scroller_text
            sta scroller_text_load_instr + 2

scroller_update_done:

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

    // Set scroller display interrupt
    lda #<scroller_display
    sta $fffe
    lda #>scroller_display
    sta $ffff
    lda #205
    sta $d012

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .align $100
    .pc = * "scroller display"
scroller_display:
    pha
    txa
    pha
    tya
    pha

    // Set up next interrupt stage
    lda #<semi_stable_scroller_display
    sta $fffe
    inc $d012

    // ACK so next stage can fire
    asl $d019

    // Save sp into x (we'll restore in the next stage)
    tsx

    // Clear interrupt flag so next stage can fire
    cli

    // nop pads (next stage should fire in here somewhere)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    jmp * // Safety net (if we see more than 1-cycle jitter for the next int, we got here)

    // Semi-stable int with 1 cycle jitter
    .pc = * "semi-stable scroller display"
semi_stable_scroller_display:
    // Restore sp
    txs

    // Wait until white line
    ldx #$22
!:      dex
    bne !-
    nop

    // White border
    lda #$01
    sta $d020

    // Dark blue screen
    lda #$06
    sta $d021

    // Wait until next line
    ldx #$0a
!:      dex
    bne !-

    // Light blue border
    lda #$0e
    sta $d020

    // Wait a bit
    ldx #$09
!:      dex
    bne !-
    nop
    bit $00

    // Set charset/screen ptr
    lda #$8a
    sta $d018

    // Dark blue border
    lda #$06
    sta $d020

    // Switch to hires char mode, 38 columns width
    lda #$1b
    sta $d011
    lda scroller_offset
    sta $d016

    // Reset background color
    lda #$00
    sta $d020
    sta $d021

    // Stretcher loop
    //  Here we start at 1, since our screen mem loading badline overlapped the top scroller border
    .const stretcher_lines = 24;
    .for (var i = 1; i < stretcher_lines; i++) {
        lda #i
        sta $d021

        ldx #$07
!:          dex
        bne !-

        .if (i < stretcher_lines - 1) {
            nop
        
            .if ((i & $07) == $07) {
                lda #$1a
            } else {
                lda #$1b
            }
            sta $d011 // This write should occur on cycle 55-57 each scanline, except the last one

            ldx #$02
!:              dex
            bne !-
            nop
        }
    }

    // Wait a tiny bit
    bit $00

    // Reset multicolor bitmap mode
    lda #$3b
    sta $d011
    lda #$18
    sta $d016

    // White border
    lda #$01
    sta $d020

    // Reset graphics/screen pointers
    lda #$80
    sta $d018

    // Wait a bit
    nop
    nop

    // Light blue border
    lda #$0e
    sta $d020

    // Wait a bit
    ldx #$0b
!:      dex
    bne !-
    nop

    // Dark blue border
    lda #$06
    sta $d020

    // Wait a bit
    ldx #$0b
!:      dex
    bne !-

    // Reset background color
    lda #$00
    sta $d020
    sta $d021

    //inc $d020

    // Reset frame interrupt
    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$ff
    sta $d012

    //dec $d020

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

    .pc = * "scroller text"
scroller_text:
    .text "hi this is jake and alex and we frens our fur is sof pls protec"
    // 40 chars of spaces at the end to make sure the screen goes blank before looping
    .text "                                        "
scroller_text_end:

    .pc = background_bitmap_pos "background bitmap"
background_bitmap:
    .import binary "build/background_bitmap.bin"

    .pc = scroller_font_pos "scroller font"
scroller_font:
    .import binary "build/font.bin"

    .pc = sprite_pos "sprites"
sprites:
    .import binary "build/sprites_blob.bin"
