# Repository Guidelines

## Project Structure & Module Organization
This repository implements an HEVC/H.265 hardware encoder in Verilog. Main RTL is under `rtl/`, organized by encoder stage: `top/`, `prei/`, `posi/`, `ime/`, `fme/`, `fetch/`, `rec/`, `cabac/`, `db/`, and `mem/`. The reconstruction block in `rtl/rec/` contains `rec_intra/` for intra prediction, `rec_mc/` for motion compensation, `rec_tq/` for transform and quantization, and `rec_wrapper/` for buffering and integration. Shared behavioral memory models live in `lib/behave/mem/`. Top-level simulation files and vectors are in `sim/top_testbench/`; software reference artifacts are in `sw/` and `sw/testVector/`.

## Build, Test, and Development Commands
Run simulator commands from `sim/top_testbench/`:

- `make`: list supported targets.
- `make vlog`: compile the testbench and RTL with ModelSim.
- `make vsim`: compile and run the ModelSim flow.
- `make nclog` / `make ncsim`: compile or run with ncverilog.
- `make vcs`: run VCS with FSDB/debug support.
- `make viewer`: open generated FSDB waveforms in Verdi/Debussy.
- `make clean`: remove simulator work directories; `make cleanall` also removes generated logs, dumps, and waveforms.

These targets require locally installed commercial EDA tools at paths expected by the Makefile.

## Coding Style & Naming Conventions
Follow the existing Verilog style: two-space indentation, aligned port declarations, and one module per file where practical. Use `lower_snake_case` filenames matching module names. Preserve legacy file headers and modification notes. Keep signal suffixes consistent: `_i` for inputs, `_o` for outputs, `_w` for wires, and `_r` for registers. Use `rstn` for the global active-low reset. Place shared macros in `rtl/enc_defines.v` and include them with `` `include "enc_defines.v" ``.

## Testing Guidelines
Update `sim/top_testbench/file_list.f` when adding RTL to the top-level build. Start with `make vlog` or `make nclog` for compilation, then run a full simulation using `make vsim`, `make ncsim`, or `make vcs`. Keep deterministic vectors in `sim/top_testbench/tv/` or `sw/testVector/`, and document intentional output changes.

## Commit & Pull Request Guidelines
Use concise subjects consistent with history, including tags such as `[FIXBUG]`, `[MAJOR]`, `[ROOT]`, or `[CREATE]`; for example, `[FIXBUG] rec chroma address calculation`. Pull requests should identify the affected RTL block, list simulator commands run, note test-vector changes, and link relevant issues. Do not commit generated `work/`, `INCA_libs/`, logs, dumps, or FSDB files.
