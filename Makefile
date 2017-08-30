PROJECT=witchcraft

SRC=$(PROJECT).asm

MUSIC=music.prg

GRAPHICS_DIR=graphics

BUILD_DIR=build

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

PRG=$(BUILD_DIR)/$(PROJECT).prg

EMU=x64
EMUSC=x64sc
EMUFLAGS=

RM=rm
RM_FLAGS=-rf

.PHONY: all dirs test testsc clean

all: dirs $(PRG)

dirs: $(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GFXRIG): $(GFXRIG_SRC)
	cd $(GFXRIG_DIR) && cargo build --release

$(BACKGROUND_BITMAP) $(FONT_CHARSET) $(SPRITES_BLOB): $(GFXRIG) $(BACKGROUND) $(FONT) $(SPRITES)
	$(GFXRIG) $(BACKGROUND) $(BACKGROUND_BITMAP) $(FONT) $(FONT_CHARSET) $(SPRITES_PREFIX) $(SPRITES_BLOB)

$(PRG): $(SRC) $(MUSIC) $(BACKGROUND_BITMAP) $(SPRITES_BLOB)
	kickass -showmem -odir $(BUILD_DIR) $(SRC)

test: dirs $(PRG)
	$(EMU) $(EMUFLAGS) $(PRG)

testsc: dirs $(PRG)
	$(EMUSC) $(EMUFLAGS) $(PRG)

clean:
	$(RM) $(RM_FLAGS) $(BUILD_DIR)
	cd $(GFXRIG_DIR) && cargo clean
