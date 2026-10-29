# IQ4_NL scalar-extraction experiment

## What
Complete one isolated, pre-hardware optimization investigation and explain it in README.md. All artifacts stay inside kernel-study/. The external llama.cpp checkout and learning exercises remain unchanged.

## Requirements
- Pin source revision and archive the actual inspected functions and required headers.
- Trace the dispatch and caller, choose a narrow hypothesis, and explain alternatives.
- Reproduce the historical odd-block defect, then give baseline and candidate identical tail handling.
- Compare direct scalar extraction against vector-store/scalar-load extraction, without changing arithmetic or accumulation order.
- Test both against generic and independent scalar references with deterministic boundaries, random inputs, extreme values, and protected input boundaries.
- Inspect linked disassembly and record exact local results. Do not claim a native speedup.
- Supply a runnable native microbenchmark with warmup, alternating order and raw samples; describe remaining backend and model validation.

## Design
Assume RV64 Linux with RVV 1.0 and VLEN 128 or 256 for the initial evidence. Also exercise the dispatch's wider-vector path at VLEN 512. Use the locally available llama.cpp revision 31385c9cebf9e5271a38e14c26e5df6dd93718b1. Copy original functions, use checked transformations, and emit separate tail-correction and optimization patches. Shared scalar tail uses the same block computation and block order. Invalid extraction assumptions fail with a diagnostic. No public API or file-format changes.

## Testing strategy
Run actual RISC-V instructions under QEMU with strict compiler warnings, compare corrected baseline/candidate bit-for-bit, compare to references with a documented float tolerance, and require the known original failure. Use guard pages for selected input boundaries. Inspect optimized linked code at -O2 and -O3. Benchmark plumbing may be smoke-tested in emulation; native performance remains unmeasured.

## Out of scope
Changes to llama.cpp itself, upstream submissions, model downloads, proving a hardware bottleneck, full backend/model correctness, and native performance claims.
