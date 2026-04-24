/*
  Linker Script for STM32F405 Bare-Metal Program

  Defines memory regions and placement of program sections.
  The linker uses this script to organize code and data into
  FLASH and RAM during compilation.
*/

/* Program entry point after reset */
ENTRY(Reset_Handler)

/*
  Memory layout of STM32F405
*/
MEMORY
{
  /* FLASH memory: stores program code and constants */
  FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 1M

  /* SRAM: used for runtime variables, stack, and heap */
  RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}

/*
  Initial stack pointer

  The stack grows downward from the end of RAM.
  This value becomes the first entry in the vector table.
*/
_estack = ORIGIN(RAM) + LENGTH(RAM);


/*
  Section placement rules
*/
SECTIONS
{
  /*
    Interrupt Vector Table

    Must be placed at the start of FLASH because the
    Cortex-M processor reads the initial SP and Reset
    vector from address 0x08000000 on reset.
 */
  .isr_vector :
  {
    KEEP(*(.isr_vector))
  } > FLASH


  /*
    Program Code and Read-Only Data

    Includes:
    - executable instructions (.text)
    - constant data (.rodata)
 */
  .text :
  {
    *(.text*)
    *(.rodata*)
  } > FLASH


  /*
    Load address of initialized data

    .data variables are stored in FLASH but copied to RAM
    during Reset_Handler execution.
 */
  _sidata = LOADADDR(.data);


  /*
    Initialized Global Variables

    These variables have initial values defined in code.
    At startup they are copied from FLASH to RAM.
  */
  .data :
  {
    _sdata = .;        /* Start of .data in RAM */

    *(.data*)

    _edata = .;        /* End of .data */
  } > RAM AT > FLASH


  /*
    Uninitialized Global Variables

    These variables do not have initial values.
    Reset_Handler clears this region to zero.
  */
  .bss :
  {
    _sbss = .;         /* Start of .bss */

    *(.bss*)
    *(COMMON)

    _ebss = .;         /* End of .bss */
  } > RAM
}