
#include <stdint.h>
#include "semihosting.h"

// STM32F4 bare-metal boot: verifies memory setup and runs SysTick.

// .data section test (initialized memory)
int initialized = 123;
// .bss section test (uninitialized memory, should be zeroed)
int uninitialized;

// Volatile so the compiler knows the ISR can change this in the background
volatile uint32_t systick_counter = 0;



// SysTick hardware registers (manual addresses since we aren't using HAL)
#define SYSTICK_CSR_REG (*((volatile uint32_t *)0xE000E010)) // Control & Status
#define SYSTICK_RVR_REG (*((volatile uint32_t *)0xE000E014)) // Reload Value
#define SYSTICK_CVR_REG (*((volatile uint32_t *)0xE000E018)) // Current Value

// CSR control bits
#define SYSTICK_ENABLE (1 << 0)    // Enable counter
#define SYSTICK_TICKINT (1 << 1)   // Enable interrupt
#define SYSTICK_CLKSOURCE (1 << 2) // Use core clock

// SysTick Interrupt Handler (name must match the startup vector table)
void SysTick_Handler(void)
{
    systick_counter++;

    // Print a message every 1000 ticks
    if ((systick_counter % 1000) == 0)
    {
        sh_puts("SysTick Interrupt Fired!\r\n");
    }
}

int main(void)
{
    sh_puts("Boot OK! Entering main...\r\n");

    // Check if the assembly startup correctly copied .data and zeroed .bss
    if (initialized == 123 && uninitialized == 0)
    {
        sh_puts("Success: Data and BSS sections verified!\r\n");
    }
    else
    {
        sh_puts("Error: Memory initialization failed!\r\n");
    }

    // Configure and start SysTick
    SYSTICK_RVR_REG = 16000 - 1; // Set reload value (arbitrary for QEMU)
    SYSTICK_CVR_REG = 0;         // Reset current value
    
    // Turn on the timer, its interrupt, and the clock source
    SYSTICK_CSR_REG = (SYSTICK_ENABLE | SYSTICK_TICKINT | SYSTICK_CLKSOURCE);

    sh_puts("SysTick Timer configured and running...\r\n");

    // Infinite loop: CPU sleeps until an interrupt wakes it up
    while (1)
    {
        __asm volatile("wfi"); // Wait For Interrupt
    }

    return 0;
}