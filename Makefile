BUILD_DIR=build

PROJECT=witchcraft
PROJECT_SRC=$(PROJECT).asm
PROJECT_TARGET=$(BUILD_DIR)/$(PROJECT).prg

PACKED_DEMO=$(BUILD_DIR)/packed-demo.bin
PACK_REPORT=$(BUILD_DIR)/report.html

DEMO=demo
DEMO_SRC=$(DEMO).asm
DEMO_TARGET=$(BUILD_DIR)/$(DEMO).bin

MUSIC=music.prg

GRAPHICS_DIR=graphics

GFXRIG_DIR=gfxrig
GFXRIG_SRC=$(wildcard $(GFXRIG_DIR)/**/*.rs)
GFXRIG=$(GFXRIG_DIR)/target/release/gfxrig

BACKGROUND=$(GRAPHICS_DIR)/background.png
BACKGROUND_BITMAP=$(BUILD_DIR)/background_bitmap.bin

FONT=$(GRAPHICS_DIR)/font.png
FONT_CHARSET=$(BUILD_DIR)/font.bin

SPRITES_PREFIX=$(GRAPHICS_DIR)/stars
SPRITES=$(wildcard $(SPRITES_PREFIX)*)
SPRITES_BLOB=$(BUILD_DIR)/sprites_blob.bin

COMMON_INC=common.inc
BASIC_INC=basic.inc

ASM=kickass
ASM_FLAGS=-showmem -odir $(BUILD_DIR)

EMU=x64
EMUSC=x64sc
EMU_FLAGS=

RM=rm
RM_FLAGS=-rf

PACKER_DIR=admiral-p4kbar
PACKER_SRC=$(wildcard $(PACKER_DIR)/**/*.rs)
PACKER=$(PACKER_DIR)/target/release/admiral-p4kbar
PACKER_SPEED=instant

.PHONY: all dirs packer pack test testsc clean

all: dirs $(PROJECT_TARGET)

dirs: $(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GFXRIG): $(GFXRIG_SRC)
	cd $(GFXRIG_DIR) && cargo build --release

packer: dirs $(PACKER)

$(PACKER): $(PACKER_SRC)
	cd $(PACKER_DIR) && cargo build --release

$(BACKGROUND_BITMAP) $(FONT_CHARSET) $(SPRITES_BLOB): $(GFXRIG) $(BACKGROUND) $(FONT) $(SPRITES)
	$(GFXRIG) $(BACKGROUND) $(BACKGROUND_BITMAP) $(FONT) $(FONT_CHARSET) $(SPRITES_PREFIX) $(SPRITES_BLOB)

$(DEMO_TARGET): $(DEMO_SRC) $(COMMON_INC) $(MUSIC) $(BACKGROUND_BITMAP) $(SPRITES_BLOB)
	$(ASM) $(ASM_FLAGS) -binfile $(DEMO_SRC)

pack: dirs $(PACKED_DEMO)

$(PACKED_DEMO) $(PACK_REPORT): $(PACKER) $(DEMO_TARGET)
	$(PACKER) $(DEMO_TARGET) $(PACKED_DEMO) $(PACK_REPORT) $(PACKER_SPEED)

$(PROJECT_TARGET): $(PROJECT_SRC) $(COMMON_INC) $(BASIC_INC) $(PACKED_DEMO)
	$(ASM) $(ASM_FLAGS) $(PROJECT_SRC)

test: dirs $(PROJECT_TARGET)
	$(EMU) $(EMU_FLAGS) $(PROJECT_TARGET)

testsc: dirs $(PROJECT_TARGET)
	$(EMUSC) $(EMUFLAGS) $(PROJECT_TARGET)

clean:
	$(RM) $(RM_FLAGS) $(BUILD_DIR)
	cd $(GFXRIG_DIR) && cargo clean
	cd $(PACKER_DIR) && cargo clean
