# RVV investigation shortlist and measurement preparation

Prepared 2026-10-29 for a three-person team. This is an investigation brief,
not a claim that any candidate is faster or a completed tooling installation.

## Evidence and scope

Quantized-kernel observations below refer to the frozen llama.cpp revision
`31385c9cebf9e5271a38e14c26e5df6dd93718b1` in `kernel-study/source/`.
RMSNorm and reduction observations were also checked against upstream `master`
source retrieved on 2026-10-29. Those upstream URLs are moving references, not a
new pinned baseline. Pin and archive a fresh revision, inspect active PRs, and
recheck coverage before beginning a new implementation. Keep the existing IQ4
experiment reproducible; do not silently refresh its inputs.

The initial target assumption is RV64 Linux with RVV 1.0. CPU, vector execution
width, VLEN, optional extensions, model and workload are still undecided. VLEN
alone does not describe vector throughput. Compiler vectorization may already
cover source loops without explicit RVV branches.

## Three initial investigations

### A. IQ4_NL × Q8_0: configuration and scalar extraction

- Evidence: `source/ggml/src/ggml-cpu/arch/riscv/quants.c:5479` and the existing
  study. Its candidate removes reduction-result stores/reloads but raises
  pair-loop configuration counts from 6 to 10 at VLEN128 and 3 to 6 on the
  wider path (`results/study-O2-assembly.json`).
- First question: can operations with compatible vector configurations be
  scheduled together while retaining direct extraction and block accumulation
  order?
- First experiment: one scheduling change compared with both the corrected
  baseline and existing extraction candidate. Inspect actual configurations,
  dependencies, register groups, spills and scalar/vector overlap.
- Reject or defer if configuration savings introduce spills or a worse critical
  path, or timing gains fail to survive repeated native sessions.
- Start from the existing independent references, guarded inputs, shared tail
  correction and paired benchmark. Include short, odd and long block counts.

### B. Q8_0 × Q8_0, then Q4_0 × Q8_0: LMUL and independent blocks

- Evidence: the frozen RVV file at lines 435 and 222. Q8_0 processes 32 values
  per block with m2 byte inputs and an m4 product. Q4_0 adds nibble decoding;
  each implementation reduces and scales one block at a time.
- First question: at VLEN256, does using smaller register groups for Q8_0 leave
  room for more efficient scheduling? Its 32 byte elements fit in m1 there.
- First experiment: change only register grouping at supported VLENs. Keep
  VLEN128 on a valid path. Test block unrolling separately, after that comparison.
- Q4_0 is a follow-up to test whether any benefit generalizes when decoding is
  added. Do not assume the same LMUL choice benefits both kernels.
- Reject or defer if generated code gains moves/configuration overhead, or the
  processor's execution resources provide no benefit from smaller groups.
- Preserve each format's integer bounds, block scales and floating accumulation
  order. Build a reference and correctness harness before ranking variants.

### C. F32 RMSNorm: reduction and output memory passes

- Evidence: upstream `ggml_compute_forward_rms_norm_f32` has a generic
  sum-of-squares loop; the unfused output performs a copy then scaling, and the
  fused weighted output uses a generic loop.
- First question: what RVV does the compiler already emit, and which of the
  reduction and output phases appears limiting?
- First experiment: an explicit vector reduction, preserving the current F32
  multiplication and double accumulation contract. Accumulation order must be
  preserved initially or numerical differences explicitly justified and tested.
- Separate experiment: produce scaled output directly instead of copying then
  scaling. Inspect whether the compiler already combines those passes.
- Follow-up: the existing fused RMSNorm × weights path. Do not propose adding
  fusion that upstream already has.
- Reject or defer if compiler-generated RVV is equivalent, reduction costs erase
  savings, or acceptable numerical behavior cannot be maintained.
- Test zero/constant rows, varying magnitudes, lengths around vector boundaries,
  epsilon choices, supported layout/aliasing cases and backend integration.

Suggested division: one person owns each investigation. Each has another team
member review the reference computation and hypothesis before implementation.
The three owners share measurement conventions and review generated assembly
with the assistant. These are research tracks, not three promised speedups.

## Reserve candidates

1. `ggml_vec_max_f32` and `ggml_vec_argmax_f32`: generic helpers without explicit
   RVV branches in the inspected upstream header. Inspect compiler output and
   callers first; preserve NaN, signed-zero and tie behavior. Argmax's existing
   equality check updates the index on equal maxima. Prioritize only if the
   selected inference/sampling path actually uses these helpers.
2. Small multi-row quantized dot-product tiles: reuse activation loads across
   output rows. First establish the selected matmul route, existing repacking or
   tiling, and whether activation traffic is significant. This is broader than
   changing an isolated dot product and should follow profiling.

## Measurement setup, before optimization implementation

1. **Reproducibility and correctness.** Record source revision, binary hashes,
   toolchain versions, flags, ISA extensions and VLEN. Preserve deterministic
   references, tails, bounds checks and raw outputs. Establish the unchanged
   baseline first. Existing IQ4 tools are specific to IQ4 and need deliberate
   adaptation for other operations.
2. **Kernel benchmarks.** Retain warmup, alternating paired runs and observable
   results. Add separate reused-buffer and streaming-buffer cases, multiple
   lengths, and enough batch time to exceed timer overhead. Reuse buffers only
   for the warm-cache case; size streaming sets against actual cache capacity.
   Start single-threaded, then test relevant thread counts. Keep raw samples and
   independent session variation rather than just a best time.
3. **Assembly and model-based analysis.** Count active elements, configurations,
   loads/stores and spills; inspect dependency chains and execution-resource
   demand. Use llvm-mca only after checking its selected CPU model covers the
   relevant RVV operations/configurations. Sweep uncertain latency and bandwidth
   assumptions; report which assumptions reverse the candidate ranking.
4. **Operation benchmarks.** Use llama.cpp's `test-backend-ops` correctness and
   performance modes with the selected CPU backend and relevant cases. Confirm
   CLI options from the pinned binary's help. Verify candidate dispatch; testing
   an operation does not prove it executed our kernel or fusion.
5. **Native profiles when hardware arrives.** Build optimized binaries with
   symbols. Use `perf record`/`perf report` for sampled hotspots and `perf stat`
   for available counters. First check `perf list`, permissions and PMU support;
   cache/stall events and call-chain facilities are platform dependent. Record
   frequency policy, affinity, thermal state and competing load. Sample profiling
   and final timing separately to assess instrumentation overhead.
6. **Inference measurements.** Use `llama-bench` with a fixed model hash, CPU
   execution, fixed runtime settings, warmup and raw repetitions. Measure prompt
   processing and token generation separately. Select models/layouts that reach
   the investigated kernels. Profile them separately: workload phase and shape
   can change the priority list.

Local command lookup found GCC/QEMU, CMake, Ninja and taskset. It did not find
perf, llvm-mca, gem5 or Verilator on PATH. Nothing was installed or benchmarked
as part of preparing this shortlist. Choose a suitable timing model before
investing in a simulator installation. Ara RTL simulation and gem5 remain
optional, separate setup projects, not prerequisites for correct experiments.

QEMU remains a correctness and harness check. Host perf samples of QEMU describe
emulator execution, not native RISC-V pipeline bottlenecks. Profiles on another
native architecture may help understand workloads but cannot rank RVV patches.

## How profiling changes the shortlist

Record a workload's hot operation, exact function/dispatch, data type, tensor
shape, runtime share, evidence about its limiting resource, and confidence.
For example: unexpected conversion time suggests investigating conversions;
reduction-heavy execution suggests dependency/scheduling work; bandwidth-limited
streaming suggests reducing traffic or improving reuse; bypassed dot products
suggest investigating the actual tiled path. Counter evidence needs supporting
experiments, not automatic interpretation as a proven cause.

Amdahl's law makes relevance explicit: if an affected path takes fraction f of
baseline time and improves by factor s, ideal overall speedup is
`1 / ((1 - f) + f / s)`. Use f from the same native workload. Unmeasured f remains
unknown. Update priorities after profiling; dropping a weak candidate is a
successful investigation outcome.

Each investigation should finish with a one-page hypothesis card: pinned source,
actual caller/dispatch, baseline behavior, one proposed change, expected
mechanism, correctness contract, predicted winning/losing conditions, experiment
matrix, raw evidence, and a retain/reject/inconclusive decision.

## Sources

- [Existing worked experiment](../README.md)
- [Upstream quantized RVV kernels](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cpu/arch/riscv/quants.c)
- [Upstream RMSNorm](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cpu/ops.cpp)
- [Upstream vector/reduction helpers](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cpu/vec.h)
- [Backend correctness/performance tests](https://github.com/ggml-org/llama.cpp/blob/master/tests/test-backend-ops.cpp)
- [llama-bench usage](https://github.com/ggml-org/llama.cpp/blob/master/tools/llama-bench/README.md)
- [llvm-mca models and limitations](https://llvm.org/docs/CommandGuide/llvm-mca.html)
- [QEMU timing limitation](https://www.qemu.org/docs/master/devel/tcg-icount.html)
- [perf stat](https://man7.org/linux/man-pages/man1/perf-stat.1.html)
- [perf record](https://man7.org/linux/man-pages/man1/perf-record.1.html)
