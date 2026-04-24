#pragma once

// Command code to write a null-terminated string
#define SEMIHOSTING_SYS_WRITE0 0x04

// Triggers the debugger to run a host command
static inline int semihosting_call(int reason, void *arg)
{
    int value;
    __asm volatile (
        "mov r0, %1\n" // Put command code in r0
        "mov r1, %2\n" // Put data address in r1
        "bkpt 0xAB\n"  // Signal the debugger (breakpoint)
        "mov %0, r0\n" // Get the result from r0
        : "=r"(value)
        : "r"(reason), "r"(arg)
        : "r0", "r1", "memory"
    );
    return value;
}

// Print a string to the debugger console
static inline void sh_puts(const char *s)
{
    semihosting_call(SEMIHOSTING_SYS_WRITE0, (void*)s);
}