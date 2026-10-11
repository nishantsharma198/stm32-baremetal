# Toolchain commands for ARM Cortex-M cross compilation

CC      = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy
SIZE    = arm-none-eabi-size
GDB     = arm-none-eabi-gdb

# Emulator: QEMU board model and GDB server port
QEMU     = qemu-system-arm
MACHINE  = olimex-stm32-h405
GDB_PORT = 3333

# Name of final firmware output
TARGET  = firmware

# Source files
C_SRCS  = src/main.c
S_SRCS  = startup/startup_stm32f4.s

# Linker script defining memory layout
LD_SCRIPT = ld/linker.ld

# Convert source files into object files
OBJS = $(C_SRCS:.c=.o) $(S_SRCS:.s=.o)

# Compilation flags

# Target architecture: Cortex-M4 in Thumb mode
# -ffreestanding and -nostdlib used because there is no OS
CFLAGS  = -mcpu=cortex-m4 -mthumb -O0 -g \
           -Wall -ffreestanding -nostdlib

# Assembly uses same architecture flags
ASFLAGS = $(CFLAGS)

# Linker flags including custom linker script
# Also generate a linker map file for memory analysis
LDFLAGS = -T $(LD_SCRIPT) -nostdlib -Wl,-Map=$(TARGET).map

# QEMU flags: no display, semihosting enabled for sh_puts output
QEMU_FLAGS = -M $(MACHINE) -kernel $(TARGET).bin -nographic -semihosting


# Default build target
all: $(TARGET).bin


# Compile C source files into object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@


# Compile assembly source files
%.o: %.s
	$(CC) $(ASFLAGS) -c $< -o $@

# Link object files to produce ELF executable
$(TARGET).elf: $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	$(SIZE) $@


# Convert ELF file into raw binary for QEMU execution
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@


# Run firmware in QEMU (Ctrl-A then X to quit)
run: $(TARGET).bin
	$(QEMU) $(QEMU_FLAGS)


# Start QEMU halted at reset, waiting for GDB on tcp::$(GDB_PORT)
debug: $(TARGET).bin
	$(QEMU) $(QEMU_FLAGS) -S -gdb tcp::$(GDB_PORT)


# Attach GDB to a running 'make debug' and run the SysTick check script
gdb: $(TARGET).elf
	$(GDB) -q -batch -x scripts/systick.gdb $<


# Clean build files

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).map

.PHONY: all run debug gdb clean

