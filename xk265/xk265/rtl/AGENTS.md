# Repository Guidelines

## Project Structure & Module Organization
This repository contains an open-source HEVC/H.265 hardware encoder. Main RTL lives in `rtl/`, organized by encoder block: `top/`, `prei/`, `posi/`, `ime/`, `fme/`, `fetch/`, `rec/`, `cabac/`, `db/`, and `mem/`. Shared behavioral memory models are under `lib/behave/mem/`. The top-level simulation environment is in `sim/top_testbench/`, with `tb_enc_top.v`, `file_list.f`, and test vectors in `sim/top_testbench/tv/`. Software encoder artifacts and reference vectors are in `sw/` and `sw/testVector/`.

## Build, Test, and Development Commands
Run simulation commands from `sim/top_testbench/`.

- `make` lists available targets.
- `make vlog` compiles the testbench and RTL with ModelSim.
- `make vsim` compiles and runs the ModelSim simulation.
- `make nclog` compiles with `ncverilog`.
- `make ncsim` runs with `ncverilog`.
- `make vcs` runs the VCS flow with FSDB/debug enabled.
- `make viewer` opens the FSDB waveform in Verdi/Debussy.
- `make clean` removes simulator work directories; `make cleanall` also removes logs, FSDBs, and dump contents.

The makefile expects local EDA installations such as ModelSim, ncverilog, VCS, and Verdi paths.

## Coding Style & Naming Conventions
Use the existing Verilog style: two-space indentation, aligned port declarations, one module per file where practical, and `lower_snake_case` filenames matching module names. Preserve existing file headers and modification notes when editing legacy RTL. Keep signal suffixes consistent: `_i` for inputs, `_o` for outputs, `_w` for wires, and `_r` for registers when used. The global active-low reset is named `rstn`. Put shared macros in `rtl/enc_defines.v` and include it with `` `include "enc_defines.v" ``.

## Testing Guidelines
Update `sim/top_testbench/file_list.f` whenever adding RTL required by the top testbench. Use `make vlog` or `make nclog` for fast compile checks, then run `make vsim`, `make ncsim`, or `make vcs` before submitting functional changes. Keep deterministic test inputs in `sim/top_testbench/tv/` or `sw/testVector/`, and document any expected output changes.

## Commit & Pull Request Guidelines
History uses concise messages, often with bracketed tags such as `[FIXBUG]`, `[MAJOR]`, `[ROOT]`, and `[CREATE]`. Follow that style for targeted changes, for example `[FIXBUG] cabac context update`. Pull requests should describe the affected RTL block, list the simulator command run, mention test vector changes, and avoid committing generated files such as `work/`, `INCA_libs/`, logs, dumps, or FSDB waveforms.
