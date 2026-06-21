##############################################################
#  Makefile — Atari 8-bit CC65 Cross-Development
#
#  Requires config.mk in the same directory.
#  Copy config.mk.example → config.mk and edit paths.
#
#  Targets:
#    make              →  debug build, Atari 400/800
#    make release      →  release build (-Osir), Atari 400/800
#    make xl           →  debug build, Atari XL/XE
#    make xl-release   →  release build, Atari XL/XE
#    make run          →  debug build + launch in emulator
#    make run-release  →  release build + launch in emulator
#    make run-xl       →  XL/XE debug build + launch
#    make run-xl-release → XL/XE release build + launch
#    make clean        →  remove all build artifacts
#    make help         →  show this list
##############################################################

# ── Per-Machine Configuration ─────────────────────────────────
#  config.mk sets: CC65_HOME, EMULATOR, MKDIR, RMDIR
#  It is NOT committed to Git — each machine has its own copy.
include config.mk

# ── CC65 Toolchain ────────────────────────────────────────────
CC65_BIN    := $(CC65_HOME)/bin
CC65_LIB    := $(CC65_HOME)/lib

CC65        := $(CC65_BIN)/cc65
CA65        := $(CC65_BIN)/ca65
LD65        := $(CC65_BIN)/ld65

# ── Project Name ──────────────────────────────────────────────
PROJECT     := AtariSetup

# ── Directory Layout ──────────────────────────────────────────
SRC_DIR     := src
INC_DIR     := inc
OBJ_DIR     := obj
BUILD_DIR   := builds

# ── Target & Config ───────────────────────────────────────────
#  These are overridden by the named shortcut targets below.
#  Never change these defaults — use the shortcut targets instead.
TARGET      ?= atari
CONFIG      ?= debug

# ── Compiler Flags ────────────────────────────────────────────
CFLAGS_debug    := -g -O    -I$(INC_DIR)
CFLAGS_release  :=    -Osir -I$(INC_DIR)

ASFLAGS_debug   := -g
ASFLAGS_release :=

CC65FLAGS   := -t $(TARGET) $(CFLAGS_$(CONFIG))
CA65FLAGS   := -t $(TARGET) $(ASFLAGS_$(CONFIG))
LD65FLAGS   := -t $(TARGET)

# ── Computed Paths ────────────────────────────────────────────
OBJ_SUBDIR  := $(OBJ_DIR)/$(TARGET)_$(CONFIG)
BLD_SUBDIR  := $(BUILD_DIR)/$(TARGET)_$(CONFIG)

OUTPUT      := $(BLD_SUBDIR)/$(PROJECT).xex
MAPFILE     := $(BLD_SUBDIR)/$(PROJECT).map
LBLFILE     := $(BLD_SUBDIR)/$(PROJECT).lbl

# ── Source Discovery ──────────────────────────────────────────
C_SRCS      := $(wildcard $(SRC_DIR)/*.c)
ASM_SRCS    := $(wildcard $(SRC_DIR)/*.s)

C_OBJS      := $(patsubst $(SRC_DIR)/%.c,  $(OBJ_SUBDIR)/%.o,     $(C_SRCS))
ASM_OBJS    := $(patsubst $(SRC_DIR)/%.s,  $(OBJ_SUBDIR)/%-asm.o, $(ASM_SRCS))
ALL_OBJS    := $(C_OBJS) $(ASM_OBJS)

# ── Header Dependency Tracking ────────────────────────────────
DEP_FILES   := $(patsubst $(SRC_DIR)/%.c, $(OBJ_SUBDIR)/%.d, $(C_SRCS))
-include $(DEP_FILES)

# ── Phony Targets ─────────────────────────────────────────────
.PHONY: all debug release xl xl-release build clean help \
        run run-release run-xl run-xl-release

all: debug

# ── Named Build Shortcuts ─────────────────────────────────────
debug:
	@$(MAKE) --no-print-directory build TARGET=atari   CONFIG=debug

release:
	@$(MAKE) --no-print-directory build TARGET=atari   CONFIG=release

xl:
	@$(MAKE) --no-print-directory build TARGET=atarixl CONFIG=debug

xl-release:
	@$(MAKE) --no-print-directory build TARGET=atarixl CONFIG=release

# ── Run Targets ───────────────────────────────────────────────
run: debug
	@echo "  Launching emulator ..."
	@$(EMULATOR) $(BUILD_DIR)/atari_debug/$(PROJECT).xex

run-release: release
	@echo "  Launching emulator ..."
	@$(EMULATOR) $(BUILD_DIR)/atari_release/$(PROJECT).xex

run-xl: xl
	@echo "  Launching emulator ..."
	@$(EMULATOR) $(BUILD_DIR)/atarixl_debug/$(PROJECT).xex

run-xl-release: xl-release
	@echo "  Launching emulator ..."
	@$(EMULATOR) $(BUILD_DIR)/atarixl_release/$(PROJECT).xex

# ── Build Entry Point ─────────────────────────────────────────
build: $(OUTPUT)
	@echo ""
	@echo "  ┌──────────────────────────────────────────────"
	@echo "  │  Build complete"
	@echo "  │  Target  : $(TARGET)"
	@echo "  │  Config  : $(CONFIG)"
	@echo "  │  Binary  : $(OUTPUT)"
	@echo "  │  Map     : $(MAPFILE)"
	@echo "  │  Symbols : $(LBLFILE)"
	@echo "  └──────────────────────────────────────────────"

# ── Directory Rules ───────────────────────────────────────────
#  Two-step creation: parent directory first, then the subdir.
#  This is required on Windows where mkdir cannot create
#  nested paths in one shot.
$(OBJ_SUBDIR):
	@$(MKDIR) $(OBJ_DIR)
	@$(MKDIR) $@

$(BLD_SUBDIR):
	@$(MKDIR) $(BUILD_DIR)
	@$(MKDIR) $@

# ── Link ──────────────────────────────────────────────────────
$(OUTPUT): $(ALL_OBJS) | $(BLD_SUBDIR)
	@echo "  [LD]  $(notdir $@)  (target=$(TARGET))"
	@$(LD65) $(LD65FLAGS) \
	         -o $@ \
	         -m $(MAPFILE) \
	         --dbgfile $(LBLFILE) \
	         $(ALL_OBJS) \
	         $(CC65_LIB)/$(TARGET).lib

# ── Compile: .c → intermediate .s → .o ───────────────────────
$(OBJ_SUBDIR)/%.o: $(SRC_DIR)/%.c | $(OBJ_SUBDIR)
	@echo "  [CC]  $<  (target=$(TARGET))"
	@$(CC65) $(CC65FLAGS) \
	         --create-dep $(OBJ_SUBDIR)/$*.d \
	         -o $(OBJ_SUBDIR)/$*.s \
	         $<
	@echo "  [AS]  $(OBJ_SUBDIR)/$*.s"
	@$(CA65) $(CA65FLAGS) \
	         -o $@ \
	         $(OBJ_SUBDIR)/$*.s

# ── Assemble: hand-written .s → .o ───────────────────────────
$(OBJ_SUBDIR)/%-asm.o: $(SRC_DIR)/%.s | $(OBJ_SUBDIR)
	@echo "  [AS]  $<  (hand-written, target=$(TARGET))"
	@$(CA65) $(CA65FLAGS) \
	         -o $@ \
	         $<

# ── Clean ─────────────────────────────────────────────────────
clean:
	@echo "  Removing $(OBJ_DIR)/ and $(BUILD_DIR)/ ..."
	@$(RMDIR) $(OBJ_DIR)
	@$(RMDIR) $(BUILD_DIR)
	@echo "  Done."

# ── Help ──────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  make                →  debug build, Atari 400/800 (48K)"
	@echo "  make release        →  release build (-Osir), Atari 400/800"
	@echo "  make xl             →  debug build, Atari XL/XE"
	@echo "  make xl-release     →  release build, Atari XL/XE"
	@echo "  make run            →  debug build + launch in emulator"
	@echo "  make run-release    →  release build + launch in emulator"
	@echo "  make run-xl         →  XL/XE debug build + launch"
	@echo "  make run-xl-release →  XL/XE release build + launch"
	@echo "  make clean          →  remove all obj/ and builds/"
	@echo ""
	@echo "  Drop .c or .s files into src/ — no Makefile edits needed."
	@echo "  Drop .h files into inc/."
	@echo "  Platform config: edit config.mk for this machine."
	@echo ""