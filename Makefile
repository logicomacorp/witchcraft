PROJECT=witchcraft

SRC=$(PROJECT).asm

GRAPHICS_DIR=graphics

BUILD_DIR=build

GFXRIG_DIR=gfxrig
GFXRIG_SRC=$(wildcard $(GFXRIG_DIR)/**/*.rs)
GFXRIG=$(GFXRIG_DIR)/target/release/gfxrig

BACKGROUND=$(GRAPHICS_DIR)/background.png

BACKGROUND_BITMAP=$(BUILD_DIR)/background_bitmap.bin

PRG=$(BUILD_DIR)/$(PROJECT).prg

EMU=x64
EMUSC=x64sc
EMUFLAGS=

RM=rm
RM_FLAGS=-rf

.PHONY: dirs

all: dirs $(PRG)

dirs: $(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GFXRIG): $(GFXRIG_SRC)
	cd $(GFXRIG_DIR) && cargo build --release

$(BACKGROUND_BITMAP): $(BACKGROUND) $(GFXRIG)
	$(GFXRIG) $(BACKGROUND) $(BACKGROUND_BITMAP)

$(PRG): $(SRC) $(BACKGROUND_BITMAP)
	kickass -showmem -odir $(BUILD_DIR) $(SRC)

test: dirs $(PRG)
	$(EMU) $(EMUFLAGS) $(PRG)

testsc: dirs $(PRG)
	$(EMUSC) $(EMUFLAGS) $(PRG)

clean:
	$(RM) $(RM_FLAGS) $(BUILD_DIR)
	cd $(GFXRIG_DIR) && cargo clean
