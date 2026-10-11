# STM32 Bare-Metal: Post-Freeze Plan

Written 2026-10-11 from an audit of commit `0ec1d2d` against the three resume
bullets and the project review PDF. Nothing in the repo other than this file
was changed by the audit.

## Baseline (verified on this machine)

| Item | Result |
|---|---|
| Host | macOS 26.6.2, arm64 |
| Compiler | Arm GNU Toolchain 15.2.Rel1 (`arm-none-eabi-gcc` 15.2.1), first in `PATH` |
| Debugger | `arm-none-eabi-gdb` 16.3.90, **built without Python** |
| Emulator | QEMU 10.2.2, machine `olimex-stm32-h405` |
| `make` | Builds clean: text 550, data 4, bss 8. One assembler warning (no newline at end of `startup_stm32f4.s`) |
| QEMU run | Prints boot, data/bss success, and one SysTick message per 1000 ticks |
| GDB at reset | `0x08000000: 0x20020000 0x08000129`, `sp=0x20020000`, `pc=Reset_Handler` |
| GDB at `main` | `initialized=123`, `uninitialized=0`, `systick_counter=0` |
| GDB in ISR | `lr=0xFFFFFFF9`, backtrace shows `SysTick_Handler` preempting the `wfi` loop, counter reaches 1000 |
| Poison test | RAM `0x20000000..0x2000000F` set to `0xDEADBEEF` before reset code ran; at `main` it read `7b, 0, 0, deadbeef`. Startup really does copy `.data` and clear `.bss` |

All three resume bullets are supported by the code as it stands.

## Known gaps to close

Startup and linker
- `_sidata` is `0x08000226`, not word-aligned, because `.text` ends unaligned. The copy loop reads words from an odd-halfword address.
- No `ALIGN(4)` at the ends of `.data` or `.bss`. Both loops copy whole words, so a `char` global would make them run past `_edata` / `_ebss`.
- No stack reservation, no heap/stack symbols, no `ASSERT`s. Stack and `.bss` can collide silently.
- Vector table has only the 16 system entries. No external IRQ slots, no `.size` on the table or on `Reset_Handler`.
- Linker emits stray `.glue_7`, `.igot.plt`, `.rel.dyn` output sections because there is no catch-all or `/DISCARD/`.
- The `uninitialized == 0` check in `main.c` passes in QEMU even with no `.bss` loop, because QEMU RAM starts zeroed. Only the poison test proves anything.

SysTick and main
- `sh_puts` (a `bkpt 0xAB` semihosting trap) is called from inside `SysTick_Handler`. On real hardware without a debugger that is a HardFault.
- Reload value `16000 - 1` is described as arbitrary. No stated tick rate.
- Register addresses are raw macros inside `main.c`. No header, no interrupts file.

Build and repo
- Commit message mentions GDB scripts, but no GDB script is in the repo.
- No `run` / `debug` targets. Objects are built in-tree. No header dependency tracking, so editing `semihosting.h` does not rebuild `main.o`.
- `.DS_Store` and `startup/.DS_Store` are tracked. `.gitignore` does not list them.
- Three PNGs sit in the repo root. README is named `Readme.md`.
- README hardcodes addresses from one build. They match today and will drift on the first code change.
- README lists three authors. Confirm how authorship should read before the repo is linked from a resume.

## Milestones

### M1: Build, run in QEMU, GDB session showing the SysTick counter (1 to 2 h)

Already works by hand. The work is making it one command and capturing evidence.

- Add `make run` and `make debug` (QEMU with `-S -gdb tcp::3333`).
- Commit `scripts/systick.gdb`: connect, show vector table and `sp`/`pc`, break at `main`, break in `SysTick_Handler`, print `systick_counter` at 1 and at 1000.
- Fix the end-of-file newline warning in the startup file.
- Save the session transcript to `docs/gdb-systick.txt`.

Done when: `make && make debug` in one terminal and `arm-none-eabi-gdb -x scripts/systick.gdb firmware.elf` in another prints `systick_counter = 1000` with no manual typing.

### M2: Startup and linker hardening (3 to 4 h)

- Linker script: `ALIGN(4)` before `_sidata` and at both ends of `.data` and `.bss`; separate `.rodata`; `_Min_Stack_Size` and a reserved stack region; `/DISCARD/` or explicit placement for the stray sections.
- Linker assertions: vector table at `ORIGIN(FLASH)`; `_sidata`, `_sdata`, `_edata`, `_sbss`, `_ebss` all word-aligned; `_ebss + _Min_Stack_Size <= _estack`; `.data` load image ends inside FLASH.
- Startup: `.size` directives, full-length vector table with weak IRQ aliases for the STM32F405, `Reset_Handler` falls into a labelled trap if `main` returns.
- Move the semihosting print out of `SysTick_Handler` (set a flag, print from the main loop). Define the tick rate from a named clock constant.
- Map-file inspection: `make size` and `make map` targets that print section addresses and symbols from `firmware.map` / `nm`. Record the before and after layout in `docs/memory-map.md`.
- Negative test: temporarily shrink RAM or add a huge array and confirm the link fails with the assertion message.

Done when: every assertion is shown to fire once, and the poison test still passes with an odd-sized `.data` (add a `char` global).

### M3: Repo cleanup, reproducible build script, README (3 to 4 h)

- `git rm --cached` both `.DS_Store` files; add `.DS_Store` and `build/` to `.gitignore`.
- Out-of-tree build into `build/`, with `-MMD -MP` dependency files and `-Wextra`.
- Layout: `src/main.c`, `src/interrupts.c`, `src/drivers/`, `include/`, `scripts/`, `docs/`. Keep `ld/` and `startup/` as directories instead of moving those files to the root.
- `scripts/qemu-gdb.sh`: checks tool versions, builds, starts QEMU halted, waits for the port, runs a GDB command file, tears QEMU down, returns non-zero on failure. Must use GDB command files and shell only, since this GDB has no Python.
- README rewrite: prerequisites with exact versions and install commands, the compile to link to binary to QEMU to GDB sequence, a FLASH/RAM memory-map diagram, a reset to `main` to SysTick boot-flow diagram, screenshots moved to `docs/`. Replace hardcoded addresses with "as printed by `make map`", or regenerate them.
- Rename `Readme.md` to `README.md`. Settle the author line.

Done when: a fresh clone plus the README commands reproduces the M1 transcript.

### M4: Extensions (10 to 14 h)

UART driver over registers (2 to 3 h)
- `src/drivers/uart.c` and `include/uart.h`: USART1 at `0x40011000`, RCC enable, BRR, CR1 `UE|TE`, poll `SR.TXE`, write `DR`.
- Run with `-serial stdio` so output comes from the emulated UART and not semihosting.
- Check first: how much of RCC and USART1 QEMU models for this board. Not verified during the audit.

HardFault handler with GDB inspection (2 to 3 h)
- Assembly shim picks MSP or PSP from `EXC_RETURN` and passes the stacked frame to a C handler.
- C handler saves `r0-r3, r12, lr, pc, xpsr` plus `CFSR`, `HFSR`, `BFAR`, `MMFAR` into a global struct, prints over UART, then halts.
- Deliberate fault (bad pointer write or `udf`) behind a build flag. `scripts/hardfault.gdb` prints the struct and resolves the stacked `pc` with `info line`.

PendSV context switch between two tasks (6 to 8 h)
- Two tasks, each with its own stack and a hand-built initial exception frame.
- SysTick sets `ICSR.PENDSVSET`; `PendSV_Handler` in assembly saves `r4-r11` on PSP, swaps the TCB pointer, restores and returns with `0xFFFFFFFD`.
- PendSV at lowest priority via `SHPR3`. First task started through SVC or a manual switch to PSP.
- Evidence: two interleaved UART streams, plus a GDB transcript showing PSP alternating between the two stacks.

Done when: each extension has a QEMU transcript in `docs/`. Only then consider changing the resume bullets.

### M5: Automated verification script (3 to 4 h)

`scripts/verify.sh`, exposed as `make verify`, built on the M3 script. Exit code 0 only if every check passes.

- Vector table: word 0 equals `_estack`, word 1 equals `Reset_Handler | 1`.
- `.data`: poison RAM at reset, run to `main`, compare RAM `_sdata.._edata` against FLASH at `_sidata`.
- `.bss`: same poison, then every word in `_sbss.._ebss` is zero and the word after `_ebss` is still poisoned.
- SysTick: `systick_counter` is 0 at `main`, greater than 0 after a bounded run, and `lr` inside the handler is an `EXC_RETURN` value.
- Timeout on every QEMU launch (`gtimeout`), so a hang fails instead of blocking.
- Optional checks for M4: expected UART banner, HardFault struct populated, both task counters advancing.
- Addresses come from `nm`, never hardcoded.

Done when: breaking the `.bss` loop on purpose makes `make verify` fail, and restoring it makes it pass.

## Time estimate

| Milestone | Estimate |
|---|---|
| M1 | 1 to 2 h |
| M2 | 3 to 4 h |
| M3 | 3 to 4 h |
| M4 | 10 to 14 h |
| M5 | 3 to 4 h |
| Total | 20 to 28 h |

The PendSV switch carries most of the uncertainty. M1 to M3 plus M5 is about 10 to 14 h and already covers the PDF's first four priorities.
