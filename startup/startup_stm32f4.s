.syntax unified
.cpu cortex-m4
.thumb

/*
  External symbols from linker script.

  These define memory boundaries used for runtime
  initialization of .data and .bss sections.
*/
.extern _estack
.extern _sidata
.extern _sdata
.extern _edata
.extern _sbss
.extern _ebss


/* Interrupt Vector Table

 */

.section .isr_vector,"a",%progbits
.global g_pfnVectors

/*
   Vector table placed at the start of FLASH.

   Layout:
   0x00 → Initial Stack Pointer
   0x04 → Reset Handler
   Remaining entries → exception handlers
*/
g_pfnVectors:
    .word _estack              /* Initial stack pointer */
    .word Reset_Handler        /* Reset handler entry point */
    .word NMI_Handler
    .word HardFault_Handler
    .word MemManage_Handler
    .word BusFault_Handler
    .word UsageFault_Handler
    .word 0
    .word 0
    .word 0
    .word 0
    .word SVC_Handler
    .word DebugMon_Handler
    .word 0
    .word PendSV_Handler
    .word SysTick_Handler


/*
   Reset Handler
 */

.section .text.Reset_Handler,"ax",%progbits
.global Reset_Handler
.type Reset_Handler, %function

/*
   Reset_Handler executes immediately after CPU reset.

   Responsibilities:
   1. Copy initialized data (.data) from FLASH to RAM
   2. Clear uninitialized data (.bss)
   3. Call main()
*/
Reset_Handler:

    /*
      Copy .data section from FLASH to RAM
    */
    ldr r0, =_sidata       /* Source address in FLASH */
    ldr r1, =_sdata        /* Destination start in RAM */
    ldr r2, =_edata        /* End of .data in RAM */

copy_data:
    cmp r1, r2
    bcc copy_do            /* Continue copying if not finished */
    b zero_bss             /* Move to BSS initialization */

copy_do:
    ldr r3, [r0], #4       /* Read word from FLASH */
    str r3, [r1], #4       /* Store word into RAM */
    b copy_data


/*
  Clear .bss section (set all bytes to zero)
*/
zero_bss:
    ldr r1, =_sbss         /* load start addr */
    ldr r2, =_ebss         /* load end addr */
    movs r3, #0            /* set zero */

zero_loop:
    cmp r1, r2             /* reached the end? */
    bcc zero_do            /* no, keep clearing */
    b call_main            /* yes, run main */

zero_do:
    str r3, [r1], #4       /* write 0, move forward */
    b zero_loop            /* repeat loop */


/*
  After memory initialization, start main()
*/
call_main:
    bl main

/* Infinite loop if main() returns */
hang:
    b hang


/* Default Interrupt Handlers
 */

.section .text.Default_Handler,"ax",%progbits
.global Default_Handler
.type Default_Handler, %function

/* Default handler for unused interrupts */
Default_Handler:
    b .


/*
  Weak aliases

  If a handler is not implemented by the user,
  it automatically maps to Default_Handler.
*/
.weak NMI_Handler
.thumb_set NMI_Handler, Default_Handler

.weak HardFault_Handler
.thumb_set HardFault_Handler, Default_Handler

.weak MemManage_Handler
.thumb_set MemManage_Handler, Default_Handler

.weak BusFault_Handler
.thumb_set BusFault_Handler, Default_Handler

.weak UsageFault_Handler
.thumb_set UsageFault_Handler, Default_Handler

.weak SVC_Handler
.thumb_set SVC_Handler, Default_Handler

.weak DebugMon_Handler
.thumb_set DebugMon_Handler, Default_Handler

.weak PendSV_Handler
.thumb_set PendSV_Handler, Default_Handler

.weak SysTick_Handler
.thumb_set SysTick_Handler, Default_Handler
