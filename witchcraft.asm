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

    .const frame_counter = zp_base
    .const frame_counter_low = frame_counter
    .const frame_counter_high = zp_base + 1

    .const sprite_frame_index = zp_base + 2
    .const sprite_frame_counter = zp_base + 3

    .const scroller_offset = zp_base + 4
    .const scroller_effect_index = zp_base + 5

    .const background_bitmap_pos = $4000
    .const background_screen_mem_pos = $6000

    .const scroller_stretcher_lines = 24 - 2
    .const scroller_font_pos = $6800
    .const scroller_color_table = $8000
    .const scroller_d018_table = scroller_color_table + scroller_stretcher_lines

    .const sprite_pos = $7000
    .const sprite_data_ptr_pos = background_screen_mem_pos + $3f8

    .pc = * "init"
init:
    // Reset graphics mode/scroll
    lda #$1b
    sta $d011

    // Reset vars
    lda #$00
    sta frame_counter_low
    sta frame_counter_high
    sta sprite_frame_index
    sta sprite_frame_counter
    sta scroller_offset
    sta scroller_effect_index

    // Unpack scroller font
    //  Bank out io regs
    lda #$34
    sta $01

    ldx #$00
unpack_font_char_loop:
        txa
        pha

        ldx #$00
unpack_font_line_loop:
            // Read char line byte
unpack_font_read_instr:
            lda scroller_font_pos, x

            // Write char line byte 8x
            ldy #$00
unpack_font_write_loop:
unpack_font_write_instr:
                sta $c000, y
            iny
            cpy #$08
            bne unpack_font_write_loop

            // Move write ptr to next charset
            lda unpack_font_write_instr + 2
            clc
            adc #$08
            sta unpack_font_write_instr + 2
        inx
        cpx #$08
        bne unpack_font_line_loop

        // Increment read ptr for next char
        lda unpack_font_read_instr + 1
        clc
        adc #$08
        sta unpack_font_read_instr + 1
        bcc !+
            inc unpack_font_read_instr + 2

        // Subtract charset offsets from write ptr
!:      lda unpack_font_write_instr + 2
        sec
        sbc #$40
        sta unpack_font_write_instr + 2

        // Increment write ptr for next char
        lda unpack_font_write_instr + 1
        clc
        adc #$08
        sta unpack_font_write_instr + 1
        bcc !+
            inc unpack_font_write_instr + 2

!:      pla
        tax
    inx
    cpx #$80
    bne unpack_font_char_loop

    //  Bank in io regs
    lda #$35
    sta $01

    // Clear out original font data
    //  This way we get a blank charset, useful for hiding some buggy stuff while doing the scroll rastersplits
    ldx #$00
clear_font_outer_loop:
        lda #$00
        tay
clear_font_inner_loop:
clear_font_write_instr:
            // Clear char line byte
            sta scroller_font_pos, y
        iny
        bne clear_font_inner_loop

        // Increment write ptr for next char
        inc clear_font_write_instr + 2
    inx
    cpx #$08
    bne clear_font_outer_loop

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

    //inc $d020

    // Set multicolor bitmap mode
    lda #$3b
    sta $d011
    lda #$18
    sta $d016

    // Set graphics/screen pointers
    lda #$80
    sta $d018

    // Set graphics bank 1
    lda #$c6
    sta $dd00

    // Increment frame counter
    inc frame_counter_low
    bne !+
        inc frame_counter_high

    // Update sprite ptrs
!:  lda sprite_frame_index
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
!:  jsr scroller_update

    // Update music
    //inc $d020
    jsr music + 3
    //dec $d020

    // Set 2x interrupt
    lda #<music2x
    sta $fffe
    lda #>music2x
    sta $ffff
    lda #99
    sta $d012

    //dec $d020

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
    //inc $d020
    jsr music + 6
    //dec $d020

    // Set scroller display interrupt
    lda #<scroller_display
    sta $fffe
    lda #>scroller_display
    sta $ffff
    lda #206
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

    // Clear last bank byte to remove graphical glitches
    lda #$00
    sta $ffff

    // Wait a bit
    ldx #$2d
!:      dex
    bne !-
    nop
    nop

    // Set charset/screen ptr
    lda #$8a
    sta $d018

    // Switch to hires char mode, 38 columns width
    lda #$1b
    sta $d011
    lda scroller_offset
    sta $d016

    // Set VIC bank 0
    lda #$c4
    sta $dd00

    // Stretcher loop
    .for (var i = 0; i < scroller_stretcher_lines; i++) {
        lda scroller_d018_table + i
        sta $d018

        lda scroller_color_table + i
        sta $d021

        lda #$00
        sta scroller_d018_table + i
        sta scroller_color_table + i

        .if (i < scroller_stretcher_lines - 1) {
            ldx #$03
!:              dex
            bne !-
            nop
            nop
            bit $00
        
            .if (((i + 1) & $07) == $07) {
                lda #$1a
            } else {
                lda #$1b
            }
            sta $d011 // This write should occur on cycle 55-57 each scanline, except the last one

            nop
            nop
            nop
            nop
        }
    }

    // Wait a bit
    ldx #$02
!:      dex
    bne !-
    nop
    nop
    nop
    nop
    bit $00

    // Reset VIC bank 1
    lda #$c6
    sta $dd00

    // Reset graphics/screen pointers
    lda #$80
    sta $d018

    // Reset multicolor bitmap mode
    lda #$3b
    sta $d011
    lda #$18
    sta $d016

    // Reset background color
    lda #$00
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

    .pc = * "scroller effect jump table"
scroller_effect_jump_table:
    .word static_y_scroller - 1
    .word dynamic_y_scroller - 1
    .word repeating_scroller - 1

    .pc = * "scroller update"
scroller_update:
    // Update effect index
    lda frame_counter_low
    bne scroller_effect_index_update_done
    lda frame_counter_high
    and #$01
    bne scroller_effect_index_update_done
        inc scroller_effect_index
        lda scroller_effect_index
        cmp #$03
        bne scroller_effect_index_update_done
            lda #$00
            sta scroller_effect_index
scroller_effect_index_update_done:

    // Dispatch effect
    lda scroller_effect_index
    asl
    tax
    lda scroller_effect_jump_table + 1, x
    pha
    lda scroller_effect_jump_table, x
    pha
    rts

    // Static y scroller
static_y_scroller:
        ldy #(scroller_stretcher_lines / 2 - 8 / 2)
        ldx #$00
!:          lda #$01
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$08
        bne !-
    jmp scroller_effect_done

    // Dynamic y scroller
dynamic_y_scroller:
        lda frame_counter_low
        asl
        asl
        clc
        adc frame_counter_low
        tax
        lda scroller_y_offset_tab, x
        pha
        lda frame_counter_low
        asl
        asl
        tax
        pla
        clc
        adc scroller_y_offset_tab, x
        lsr
        tay
        ldx #$00
!:          lda #$01
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$08
        bne !-
    jmp scroller_effect_done

    // Repeating scroller
repeating_scroller:
        lda frame_counter_low
        asl
        tax
        lda scroller_y_offset_tab_2, x
        tay
        ldx #$00
!:          tya
            pha
            lsr
            clc
            adc frame_counter_low
            lsr
            lsr
            lsr
            and #$07
            tay
            lda repeating_scroller_color_tab, y
            sta scroller_color_table, x
            pla
            tay
            sta scroller_d018_table, x
            iny
            iny
        inx
        cpx #scroller_stretcher_lines
        bne !-
    jmp scroller_effect_done

repeating_scroller_color_tab:
    .byte $00, $04, $03, $0d, $01, $07, $0a, $02

    // Scroller transition effect
scroller_effect_done:
    lda frame_counter_low
    cmp #scroller_stretcher_lines
    bcs scroller_transition_out_test
    lda frame_counter_high
    and #$01
    bne scroller_transition_out_test
        // Transition in
        lda #scroller_stretcher_lines
        sec
        sbc frame_counter_low
        jmp scroller_transition

scroller_transition_out_test:
    lda frame_counter_low
    cmp #(256 - scroller_stretcher_lines)
    bcc scroller_transition_done
    lda frame_counter_high
    and #$01
    beq scroller_transition_done
        // Transition out
        lda frame_counter_low
        sec
        sbc #(256 - scroller_stretcher_lines)

scroller_transition:
    lsr
    pha

    // Top half
    tax
    inx
    lda #$00
    tay
!:      sta scroller_color_table, y
        iny
    dex
    bne !-

    // Bottom half
    pla

    tax
    inx
    lda #$00
    ldy #(scroller_stretcher_lines - 1)
!:      sta scroller_color_table, y
        dey
    dex
    bne !-

scroller_transition_done:
    dec scroller_offset
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
    rts

    .align $100
scroller_y_offset_tab:
    .for (var i = 0; i < 256; i++) {
        .byte round((sin(toRadians(i / 256 * 360)) * 0.5 + 0.5) * 15)
    }
scroller_y_offset_tab_2:
    .for (var i = 0; i < 256; i++) {
        .byte round((sin(toRadians(i / 256 * 360)) * 0.5 + 0.5) * 128)
    }

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
