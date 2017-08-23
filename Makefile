PROJECT=witchcraft

SRC=$(PROJECT).asm

BUILD_DIR=build

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

$(PRG): $(SRC)
	kickass -showmem -odir $(BUILD_DIR) $(SRC)

test: dirs $(PRG)
	$(EMU) $(EMUFLAGS) $(PRG)

testsc: dirs $(PRG)
	$(EMUSC) $(EMUFLAGS) $(PRG)

clean:
	$(RM) $(RM_FLAGS) $(BUILD_DIR)
