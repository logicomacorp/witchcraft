extern crate image;
extern crate minifb;
extern crate time;
extern crate cons_list;

use image::{GenericImage, Pixel};

/*use minifb::{Key, KeyRepeat, Scale, Window, WindowOptions};

use cons_list::ConsList;*/

use std::env;
use std::fs::File;
use std::io::Write;

const WIDTH: usize = 160;
const HEIGHT: usize = 200;

const CHAR_WIDTH: usize = 4; // 4 due to multicolor
const CHAR_HEIGHT: usize = 8;

const WIDTH_CHARS: usize = WIDTH / CHAR_WIDTH;
const HEIGHT_CHARS: usize = HEIGHT / CHAR_HEIGHT;

/*struct FadeFrame {
    screen_mem: Box<[u8]>,
    color_mem: Box<[u8]>,
}

impl FadeFrame {
    pub fn new() -> FadeFrame {
        FadeFrame {
            screen_mem: vec![0; WIDTH_CHARS * HEIGHT_CHARS].into_boxed_slice(),
            color_mem: vec![0; WIDTH_CHARS * HEIGHT_CHARS].into_boxed_slice(),
        }
    }
}

#[derive(Clone)]
enum FadeInstruction {
    WriteByte { addr: u16, value: u8 },
    WriteRange { addr: u16, values: Box<[u8]> },
    EndFrame,
    EndAnim,
}

impl FadeInstruction {
    pub fn size_bytes(&self) -> usize {
        match self {
            &FadeInstruction::WriteByte { .. } => 3,
            &FadeInstruction::WriteRange { ref values, ..} => 3 + values.len(),
            &FadeInstruction::EndFrame | &FadeInstruction::EndAnim => 1,
        }
    }

    pub fn try_combine(&self, rhs: &FadeInstruction) -> Option<FadeInstruction> {
        match self {
            &FadeInstruction::WriteByte { addr: lhs_addr, value: lhs_value } => {
                match rhs {
                    &FadeInstruction::WriteByte { addr: rhs_addr, value: rhs_value } => {
                        if lhs_addr + 1 == rhs_addr {
                            Some(FadeInstruction::WriteRange { addr: lhs_addr, values: vec![lhs_value, rhs_value].into_boxed_slice() })
                        } else {
                            None
                        }
                    }
                    &FadeInstruction::WriteRange { addr: rhs_addr, values: ref rhs_values } => {
                        if lhs_addr + 1 == rhs_addr {
                            let mut new_values = Vec::new();
                            new_values.push(lhs_value);
                            new_values.extend_from_slice(&rhs_values);
                            Some(FadeInstruction::WriteRange { addr: lhs_addr, values: new_values.into_boxed_slice() })
                        } else {
                            None
                        }
                    }
                    _ => None
                }
            }
            &FadeInstruction::WriteRange { addr: lhs_addr, values: ref lhs_values } => {
                match rhs {
                    &FadeInstruction::WriteByte { addr: rhs_addr, value: rhs_value } => {
                        if lhs_addr + (lhs_values.len() as u16) == rhs_addr {
                            let mut new_values = Vec::new();
                            new_values.extend_from_slice(&lhs_values);
                            new_values.push(rhs_value);
                            Some(FadeInstruction::WriteRange { addr: lhs_addr, values: new_values.into_boxed_slice() })
                        } else {
                            None
                        }
                    }
                    &FadeInstruction::WriteRange { addr: rhs_addr, values: ref rhs_values } => {
                        if lhs_addr + (lhs_values.len() as u16) == rhs_addr {
                            let mut new_values = Vec::new();
                            new_values.extend_from_slice(&lhs_values);
                            new_values.extend_from_slice(&rhs_values);
                            Some(FadeInstruction::WriteRange { addr: lhs_addr, values: new_values.into_boxed_slice() })
                        } else {
                            None
                        }
                    }
                    _ => None
                }
            }
            _ => None
        }
    }
}*/

fn main() {
    let background_input_file_name = env::args().skip(1).nth(0).unwrap();
    let background_output_file_name = env::args().skip(1).nth(1).unwrap();

    let font_input_file_name = env::args().skip(1).nth(2).unwrap();
    let font_output_file_name = env::args().skip(1).nth(3).unwrap();

    let sprites_input_file_name_prefix = env::args().skip(1).nth(4).unwrap();
    let sprites_output_file_name = env::args().skip(1).nth(5).unwrap();

    const SPRITE_WIDTH: usize = 12; // 12 due to multicolor
    const SPRITE_HEIGHT: usize = 20;

    let palette = [
        0x000000,
        0xffffff,
        0x883932,
        0x67b6bd,
        0x8b3f96,
        0x55a049,
        0x40318d,
        0xbfce72,
        0x8b5429,
        0x574200,
        0xb86962,
        0x505050,
        0x787878,
        0x94e089,
        0x7869c4,
        0x9f9f9f,
    ];

    let input_color_indices = [
        0, 11, 15, 1
    ];

    // Convert background image
    {
        let input = image::open(background_input_file_name).unwrap();

        let mut output = Vec::new();

        for char_y in 0..HEIGHT_CHARS {
            for char_x in 0..WIDTH_CHARS {
                for y in 0..CHAR_HEIGHT {
                    let mut acc = 0;

                    for x in 0..CHAR_WIDTH {
                        let pixel_x = char_x * CHAR_WIDTH + x;
                        let pixel_y = char_y * CHAR_HEIGHT + y;

                        let pixel = input.get_pixel(pixel_x as _, pixel_y as _).to_rgb();
                        let rgb = ((pixel.data[0] as u32) << 16) | ((pixel.data[1] as u32) << 8) | (pixel.data[2] as u32);
                        let palette_index = palette.iter().position(|x| *x == rgb).unwrap();
                        let color_index = input_color_indices.iter().position(|x| *x == palette_index).unwrap();

                        acc <<= 2;
                        acc |= color_index as u8;
                    }

                    output.push(acc);
                }
            }
        }

        // Fade stuff
        /*const NUM_FRAMES: usize = 256;

        let fade_palettes = [
            [0x00, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06],
            [0x00, 0x06, 0x0b, 0x04, 0x0c, 0x0e, 0x0e, 0x0e],
            [0x00, 0x06, 0x0b, 0x04, 0x0c, 0x03, 0x0d, 0x01],
        ];

        println!("Calculating {} frames", NUM_FRAMES);

        let mut frames = Vec::new();

        for frame_index in 0..NUM_FRAMES {
            let mut frame = FadeFrame::new();

            for char_y in 0..HEIGHT_CHARS {
                for char_x in 0..WIDTH_CHARS {
                    let fx = ((char_x as f64) / ((WIDTH_CHARS - 1) as f64) - 0.5) * 2.0 + 0.5;
                    let fy = (char_y as f64) / ((HEIGHT_CHARS - 1) as f64);
                    let t = (frame_index as f64) * 0.08;
                    let dx = fx - 0.5;
                    let dy = fy - 0.5;
                    let d = (dx * dx + dy * dy).sqrt();
                    let p = (fx * 9.0 + (fy * 5.88).sin()).sin() * (fy * 9.0 + (fx * 6.12).cos()).cos();

                    let mut fade = -(d * 10.0) - (p * 0.5 + 0.5) * 6.0 + t;
                    if fade < 0.0 {
                        fade = 0.0;
                    }
                    if fade > 1.0 {
                        fade = 1.0;
                    }

                    let mut color_index = (fade * 7.0) as i32;
                    if color_index < 0 {
                        color_index = 0;
                    }
                    if color_index > 7 {
                        color_index = 7;
                    }

                    let screen_mem_value = ((fade_palettes[0][color_index as usize] << 4) | fade_palettes[1][color_index as usize]) as u8;
                    let color_mem_value = fade_palettes[2][color_index as usize] as u8;

                    let mem_index = char_y * WIDTH_CHARS + char_x;
                    frame.screen_mem[mem_index] = screen_mem_value;
                    frame.color_mem[mem_index] = color_mem_value;
                }
            }

            frames.push(frame);
        }

        println!("Raw size: {} bytes", NUM_FRAMES * WIDTH_CHARS * HEIGHT_CHARS * 2);

        println!("Diffing and generating instructions");

        let mut raw_instructions = Vec::new();
        let mut max_raw_instructions_per_frame = 0;

        const BACKGROUND_SCREEN_MEM_POS: u16 = 0x6000;
        const COLOR_MEM_POS: u16 = 0xd800;

        let initial_frame = FadeFrame::new();
        let mut prev_frame = &initial_frame;
        for frame in frames.iter() {
            let mut num_instructions = 0;

            // Diff screen mem
            for mem_index in 0..WIDTH_CHARS * HEIGHT_CHARS {
                if frame.screen_mem[mem_index] != prev_frame.screen_mem[mem_index] {
                    raw_instructions.push(FadeInstruction::WriteByte { addr: BACKGROUND_SCREEN_MEM_POS + (mem_index as u16), value: frame.screen_mem[mem_index] });
                    num_instructions += 1;
                }
            }

            // Diff color mem
            for mem_index in 0..WIDTH_CHARS * HEIGHT_CHARS {
                if frame.color_mem[mem_index] != prev_frame.color_mem[mem_index] {
                    raw_instructions.push(FadeInstruction::WriteByte { addr: COLOR_MEM_POS + (mem_index as u16), value: frame.color_mem[mem_index] });
                    num_instructions += 1;
                }
            }

            raw_instructions.push(FadeInstruction::EndFrame);
            num_instructions += 1;

            if num_instructions > max_raw_instructions_per_frame {
                max_raw_instructions_per_frame = num_instructions;
            }

            prev_frame = frame;
        }

        raw_instructions.push(FadeInstruction::EndAnim);

        println!("Total raw instructions: {}", raw_instructions.len());
        println!("Max raw instructions/frame: {}", max_raw_instructions_per_frame);
        println!("Total raw instruction bytes: {} bytes", raw_instructions.iter().fold(0, |acc, x| acc + x.size_bytes()));

        println!("Optimizing instructions");

        fn rev<T: Clone>(list: ConsList<T>) -> ConsList<T> {
            let mut ret = ConsList::new();
            for item in list.into_iter() {
                // Hack to use clone here but gets the job done :)
                ret = ret.append(item.clone());
            }
            ret
        }

        let mut instructions_list = ConsList::new();
        for instruction in raw_instructions.into_iter() {
            instructions_list = instructions_list.append(instruction);
        }
        instructions_list = rev(instructions_list);

        let mut instructions = Vec::new();

        let mut lhs = None;
        let mut tail = instructions_list.tail();

        loop {
            if tail.is_empty() {
                break;
            }

            if lhs.is_none() {
                lhs = tail.head().cloned();
                tail = tail.tail();
                continue;
            }

            let rhs = tail.head().cloned().unwrap();
            if let Some(instr) = lhs.clone().unwrap().try_combine(&rhs) {
                lhs = Some(instr);
                tail = tail.tail();
            } else {
                instructions.push(lhs.clone().unwrap());
                lhs = None;
            }
        }

        if let Some(instr) = lhs {
            instructions.push(instr);
        }

        println!("Total optimized instructions: {}", instructions.len());
        //println!("Max raw instructions/frame: {}", max_raw_instructions_per_frame); // TODO
        println!("Total optimized instruction bytes: {} bytes", instructions.iter().fold(0, |acc, x| acc + x.size_bytes()));

        // Fade preview
        let mut buffer: Box<[u32]> = vec![0; WIDTH * 2 * HEIGHT].into_boxed_slice();

        let mut window = Window::new("Fade stuff", WIDTH * 2, HEIGHT, WindowOptions {
            borderless: false,
            title: true,
            resize: false,
            scale: Scale::X2
        }).unwrap();

        let mut start_time = time::precise_time_s();

        while window.is_open() && !window.is_key_down(Key::Escape) {
            if window.is_key_pressed(Key::Space, KeyRepeat::No) {
                start_time = time::precise_time_s();
            }

            let time = time::precise_time_s() - start_time;

            // Simulate 50fps by quantizing to 20ms intervals
            let mut frame_index = (time / 0.020) as usize;
            if frame_index >= NUM_FRAMES {
                frame_index = NUM_FRAMES - 1;
            }

            let frame = &frames[frame_index];

            for char_y in 0..HEIGHT_CHARS {
                for char_x in 0..WIDTH_CHARS {
                    let mem_index = char_y * WIDTH_CHARS + char_x;
                    let screen_mem_value = frame.screen_mem[mem_index];
                    let color_mem_value = frame.color_mem[mem_index];

                    for y in 0..CHAR_HEIGHT {
                        let char_byte = output[(char_y * WIDTH_CHARS + char_x) * 8 + y];

                        for x in 0..CHAR_WIDTH {
                            let pixel_x = char_x * CHAR_WIDTH + x;
                            let pixel_y = char_y * CHAR_HEIGHT + y;

                            let palette_index = (char_byte >> ((3 - x) * 2)) & 0x03;
                            let color_index = match palette_index {
                                0 => 0,
                                1 => screen_mem_value >> 4,
                                2 => screen_mem_value & 0x0f,
                                _ => color_mem_value
                            };
                            let color = palette[color_index as usize];

                            let buffer_index = (pixel_y * WIDTH + pixel_x) * 2;
                            buffer[buffer_index] = color;
                            buffer[buffer_index + 1] = color;
                        }
                    }
                }
            }

            window.update_with_buffer(&buffer);
        }*/

        let mut file = File::create(background_output_file_name).unwrap();
        file.write(&output).unwrap();
    }

    // Convert font
    {
        let input = image::open(font_input_file_name).unwrap();

        let mut output = Vec::new();

        for char_y in 0..(input.height() as usize) / CHAR_HEIGHT {
            for char_x in 0..(input.width() as usize) / (CHAR_WIDTH * 2) {
                for y in 0..CHAR_HEIGHT {
                    let mut acc = 0;

                    for x in 0..(CHAR_WIDTH * 2) {
                        let pixel_x = char_x * (CHAR_WIDTH * 2) + x;
                        let pixel_y = char_y * CHAR_HEIGHT + y;

                        let pixel = input.get_pixel(pixel_x as _, pixel_y as _).to_rgb();

                        acc <<= 1;
                        acc |= pixel.data[0] & 0x01;
                    }

                    output.push(acc);
                }
            }
        }

        let mut file = File::create(font_output_file_name).unwrap();
        file.write(&output).unwrap();
    }

    // Convert sprite sheets
    {
        let mut output = Vec::new();

        for sheet in 0..8 {
            let input_file_name = format!("{}{}.png", sprites_input_file_name_prefix, sheet + 1);

            let input = image::open(input_file_name).unwrap();

            for frame in 0..8 {
                for sprite_y in 0..SPRITE_HEIGHT {
                    let mut acc = 0;

                    for sprite_x in 0..SPRITE_WIDTH {
                        let pixel_x = frame * SPRITE_WIDTH + sprite_x;
                        let pixel_y = sprite_y;

                        let pixel = input.get_pixel(pixel_x as _, pixel_y as _).to_rgb();
                        let rgb = ((pixel.data[0] as u32) << 16) | ((pixel.data[1] as u32) << 8) | (pixel.data[2] as u32);
                        let palette_index = palette.iter().position(|x| *x == rgb).unwrap();
                        let color_index = input_color_indices.iter().position(|x| *x == palette_index).unwrap();

                        acc <<= 2;
                        acc |= color_index as u32;
                    }

                    output.push((acc >> 16) as u8);
                    output.push((acc >> 8) as u8);
                    output.push(acc as u8);
                }

                // Output last dummy row (sprites are actually 21 pixels high)
                output.push(0x00);
                output.push(0x00);
                output.push(0x00);

                // Final padding byte so each sprite is 64 bytes exactly
                output.push(0x00);
            }
        }

        let mut file = File::create(sprites_output_file_name).unwrap();
        file.write(&output).unwrap();
    }
}
