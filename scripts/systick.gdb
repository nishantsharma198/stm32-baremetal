# GDB check script: boot state, memory initialization, and SysTick counter.
#
# Usage:
#   Terminal 1:  make debug
#   Terminal 2:  make gdb
#
# Addresses are taken from ELF symbols, so the script survives code changes.

set pagination off
set confirm off
target remote :3333

echo \n=== 1. At reset: vector table, SP and PC ===\n
# Word 0 must equal _estack, word 1 must equal Reset_Handler with bit 0 set
x/2xw &g_pfnVectors
print/x &_estack
print/x (unsigned int)&Reset_Handler | 1
info registers sp pc

echo \n=== 2. At main: .data copied, .bss cleared ===\n
break main
continue
# The FLASH copy of .data and its RAM copy must match
x/xw &_sidata
x/xw &_sdata
print initialized
print uninitialized
print systick_counter

echo \n=== 3. First SysTick interrupt ===\n
break SysTick_Handler
continue
# LR holds EXC_RETURN (0xFFFFFFF9), not a normal return address
info registers sp lr xpsr
backtrace
next
print systick_counter

echo \n=== 4. After 1000 SysTick interrupts ===\n
delete
break SysTick_Handler if systick_counter == 999
continue
next
print systick_counter
# SysTick CSR, RVR, CVR
x/3xw 0xE000E010

echo \n=== Done ===\n
kill
quit
