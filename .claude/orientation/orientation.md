# Orientation: RISC-V learning workspace
_Updated: 2026-10-29 · Commit: workspace commit unavailable; kernel study pins upstream 31385c9cebf9e5271a38e14c26e5df6dd93718b1 · Overall confidence: medium_

## What this is
A C and RVV learning workspace preparing learners to investigate llama.cpp quantized CPU kernels. Verified from rvv-exercises.md:1 and the exercise sources. It is not a full llama.cpp checkout.

## How it's built
Standalone C programs, generated RISC-V assembly, shell check scripts, two teaching guides, and an isolated llama.cpp kernel reproduction. Exercise 13 uses riscv_vector.h (exercise13.c:5). The external checkout defaults to /home/ilker-pc/llama.cpp (llama-bug-repro/run.sh:4).

## Entry points
Exercise main functions; exercise13.c main runs table-decoding cases. check-exercise13.sh:1 builds, runs and inspects assembly. llama-bug-repro/run.sh:1 orchestrates kernel extraction and emulation.

## Core flows
1. check-exercise13.sh:16 compiles exercise13.c; lines 18–24 execute at VLEN 128 and 256; subsequent checks inspect generated instructions. Verified by reading script.
2. llama-bug-repro/run.sh:5 invokes extract.py; extract.py reads actual generic/RVV function bodies from the external checkout and writes kernels.inc; run.sh compiles repro.c and runs both VLEN settings. Verified by reading source; not executed this session.
3. kernel-study/prepare.py:77 verifies frozen source hashes and generates original, tail-corrected baseline, and scalar-extraction candidate variants. kernel-study/check.sh:7 builds O2/O3, inspects assembly and checks VLEN 128/256/512 before a benchmark smoke run. Verified by reading; not rerun on 2026-10-29.

## Data & state
Local source, binaries and generated assembly. Reproduction depends on external llama.cpp sources and headers. No service or database needed for these inspected flows.
The newer kernel study uses frozen inputs and a source manifest, so ordinary reproduction does not require the external checkout (kernel-study/prepare.py:77).

## Build, run, test
`sh check-exercise13.sh` and `sh llama-bug-repro/run.sh`, from workspace root. Commands verified in scripts, execution unverified this session. The latter intentionally returns failure on a reproduced mismatch. Both use riscv64-linux-gnu-gcc and qemu-riscv64; target libraries are /usr/riscv64-linux-gnu.
`sh kernel-study/check.sh` is the isolated investigation's full check command. Its existing assembly JSON records configuration counts increasing from 6 to 10 per pair loop at VLEN128 and 3 to 6 for the wider path, while removing result stores/reloads. These are inspected artifacts, not newly measured cycles. kernel-study/study.c:219 implements warmup, alternating variant order and raw timing CSV using repeated buffers. QEMU and the cross GCC are on PATH; llvm-mca, gem5 and Verilator were not found by command lookup on 2026-10-29.

## Change surfaces
Learning work proceeds through standalone exercises. Kernel investigations can follow the extraction harness, retaining a pinned baseline and differential checks. Actual backend changes belong to the external llama.cpp checkout, subject to its own instructions.

## Gaps, risks & debt
No native hardware available according to user. QEMU execution cannot establish native performance. Extracted tests do not validate full backend integration or model inference. Toolchain compatibility helpers need attention when comparing extracted kernels to production builds.
Candidate family verified in the frozen RVV source: Q4_0×Q8_0 at kernel-study/source/ggml/src/ggml-cpu/arch/riscv/quants.c:222; Q8_0×Q8_0 at :435; IQ4_NL×Q8_0 at :5489. All reduce each block to a scalar and apply block scales. Q4_0 decodes nibbles arithmetically; IQ4_NL uses register gathers. Proposed investigations into configuration scheduling, LMUL, unrolling and activation reuse remain hypotheses. The current benchmark reuses at most 257 blocks and does not establish streaming-weight behavior.

## Conventions & gotchas
Guides require deterministic tests, boundary cases, assembly inspection, and line-by-line understanding (rvv-exercises.md:7). Exercise check scripts write binaries and assembly. Avoid running them during a read-only orientation.

## Doc vs reality
Inspected exercise13 code and script match the guide's lookup-table and dual-VLEN testing approach. The reproduction README reports an odd-block failure observed on 2026-10-21 at commit 31385c9ce; this historical result was not revalidated here.

## Map confidence
Verified: exercise13 source/assembly-check structure and reproduction extraction/run orchestration. Inferred: overall learning progression from the guides. Unexplored: earlier exercise implementations, external llama.cpp checkout, actual runtime outcomes.

## Open questions
1. Which future CPU, VLEN and ISA extensions will define the performance target?
2. Which model, quantization format and prompt/decode workload should define success?
