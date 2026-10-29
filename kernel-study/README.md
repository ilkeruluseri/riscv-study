# A complete pre-hardware kernel investigation

For shared command capture, environment inventories and prepared native perf
collection, see the [measurement setup guide](docs/profiling-setup/README.md).
The [model-free operation baseline](docs/operation-baseline/README.md) adds a
pinned full CPU build and shared case/result format for the team's investigations.
The [real-model inference results](docs/inference-baseline/results.md) add verified
Qwen2.5 Q4_0/Q8_0 measurements and single-thread host profiles by inference phase.

This is a worked example of the process we discussed: select a real llama.cpp kernel, understand it, establish a baseline, propose one change, test it, inspect the machine code, and prepare the hardware experiment. Everything is contained in this directory. Your exercises and the external llama.cpp checkout are unchanged.

**Result:** direct vector-to-scalar extraction is a correct candidate for the tested cases, and it removes the intended memory round trips. However, GCC also emits more vector-configuration instructions and changes the schedule. I have not established a speedup. This is a completed pre-hardware investigation with a specific experiment waiting for hardware.

You can read this now or return after exercises 14-18. You do not need to decide on a board or download a model to reproduce the work.

## 1. What I selected, and why

I selected `ggml_vec_dot_iq4_nl_q8_0`: a dot product between IQ4_NL quantized weights and Q8_0 activations. It contains the operations you are learning: nibble extraction, table lookup, widening multiplication, reduction, and scale application. The existing odd-block reproduction also gives us a concrete starting point.

I pinned the local llama.cpp revision to:

```text
31385c9cebf9e5271a38e14c26e5df6dd93718b1
```

[prepare.py](prepare.py) checked that each input file matched that commit, copied the inputs into [source/](source/), and recorded SHA-256 hashes in [source-manifest.json](source-manifest.json). Subsequent builds use these frozen files and check their hashes. They do not depend on the external checkout remaining at this revision. The original license is preserved in [source/LICENSE](source/LICENSE).

This matters because an optimization claim needs a specific baseline. A future upstream change must not silently change what our experiment compares. This study does not assert anything about the latest upstream tree.

I traced relevance rather than assuming that a quantized dot product must be a hotspot:

1. The [CPU type-traits table](source/ggml/src/ggml-cpu/ggml-cpu.c), around lines 380-384, maps `GGML_TYPE_IQ4_NL` to this function and specifies Q8_0 as its dot-product partner.
2. `ggml_compute_forward_mul_mat_one_chunk`, around lines 1164-1244 in that file, obtains the function pointer and calls it for a row dot product.
3. The [RISC-V dispatcher](source/ggml/src/ggml-cpu/arch/riscv/quants.c), around lines 5592-5609, selects the 128-bit implementation at VLEN=128 and the other implementation at wider VLENs.

There are other matrix-multiplication routes, including a tiled path that can return before this route. Thus this is a structurally relevant candidate for IQ4_NL inference, **not a demonstrated bottleneck or a guaranteed path for every model/build**. Our provisional workload is synthetic row dot products, with prompt processing and token generation reserved for later integration measurements.

## 2. Understanding the computation before changing it

Each weight block holds 32 weights in 16 packed bytes and one FP16 scale. Each activation block holds 32 signed bytes and one FP16 scale. The actual definitions are in [ggml-common.h](source/ggml/src/ggml-common.h), around lines 251-256 and 447-452.

For packed byte `j`, its low nibble represents weight `j`; its high nibble represents weight `j + 16`. The nibble is an index into this nonlinear table:

```text
code:    0     1    2    3    4    5    6    7   8   9  10  11  12  13  14   15
value: -127  -104  -83  -65  -49  -35  -22  -10   1  13  25  38  53  69  89  113
```

One block computes:

```text
integer_dot = sum(decoded_weight[j] * activation[j], j = 0..31)
contribution = weight_scale * activation_scale * integer_dot
```

Block contributions are accumulated in order into a floating-point output. A nibble is not a signed four-bit integer here: code 8 maps to 1. Using a familiar but incorrect decoding rule would invalidate the experiment.

I checked the intermediate widths. An absolute product is at most `127 * 128 = 16256`. The wider-vector implementation adds two products in each signed 16-bit lane; `2 * 16256 = 32512` still fits. The complete 32-element sum is bounded by `520192`, which fits signed 32 bits. These bounds justify the existing widening arithmetic.

The 128-bit implementation gathers 32 decoded bytes in a larger register group. The wider-vector implementation handles two 16-element halves and combines their products before reduction. Both process two quantization blocks per outer iteration.

## 3. Establishing a correct comparison baseline

The original functions have an outer-loop tail defect: they process pairs of blocks and omit an unpaired final block. I reproduced it with deliberately simple data. Packed bytes `0x88` decode to weights of 1; activations and scales are also 1. Every block should contribute exactly 32.

| Blocks | Expected | Original result |
| --- | ---: | ---: |
| 0 | 0 | 0 |
| 1 | 32 | 0 |
| 2 | 64 | 64 |
| 3 | 96 | 64 |
| 4 | 128 | 128 |
| 5 | 160 | 128 |

I retained three separately named versions in [kernels.inc](kernels.inc):

| Version | Purpose |
| --- | --- |
| `original` | Preserve the observed defect and demonstrate that the harness detects it |
| `baseline` | Original pair loop plus a scalar computation for the remaining odd block |
| `candidate` | The same corrected baseline with direct scalar extraction |

[01-common-tail.patch](01-common-tail.patch) adds the identical tail computation to both comparison paths. [02-scalar-extraction.patch](02-scalar-extraction.patch) contains only the proposed optimization, applied after that correction. Neither patch has been applied to your external checkout. I verified that both apply in order without fuzz to a temporary copy and reconstruct the intended candidate; see [patch-check.log](results/patch-check.log).

This separation prevents a misleading comparison between an incorrect fast function and a correct function. The scalar tail is deliberately easy to understand. Optimizing it would be a separate hypothesis.

## 4. Choosing a hypothesis

I considered these possibilities:

| Possibility | Decision |
| --- | --- |
| Move lookup-table loading out of the block loop | Already done in the original functions; no change needed |
| Increase LMUL or unroll more blocks | Plausible, but adds register-pressure and scheduling questions; defer |
| Change how packed halves are combined | Plausible, but changes more of the dataflow; defer |
| Replace reduction-result stores with scalar extraction | Selected: four narrow substitutions with a clear correctness argument |

The selected hypothesis was: **avoiding a vector store followed by a scalar reload may reduce the cost of transferring each block's integer result into scalar scaling code.**

The original shape is:

```c
// The reduction produces a vector whose element zero contains the total.
__riscv_vse32_v_i32m1(&acc1, reduced, 1);
// Scalar code then uses acc1.
```

The candidate shape is:

```c
acc1 = __riscv_vmv_x_s_i32m1_i32(reduced);
```

The reduction, its zero seed, input widths, block ordering, scale arithmetic, and floating-point accumulation order remain the same. Only the transfer of the resulting signed 32-bit value changes. At SEW=32, `vmv.x.s` copies vector element zero into an integer register and sign-extends it on RV64, preserving negative sums. See the [RISC-V scalar-move specification](https://docs.riscv.org/reference/isa/unpriv/v-st-ext#_integer_scalar_move_instructions).

This was worth investigating, but not enough to assume success: the compiler might already remove the stores, or the new form might cause an unfavorable schedule.

## 5. Making the isolated experiment representative

[prepare.py](prepare.py) copies the actual function bodies and performs checked substitutions. It fails if expected source fragments change. This is a small extractor for a pinned source layout, not a general C parser. [study.c](study.c) supplies the harness, and the frozen headers supply the real block types and helper definitions.

Two compatibility details matter:

- GCC 13 lacks the original `vcreate` intrinsic. Like the earlier reproduction, the harness constructs that register group with two `vset` operations. That helper is used by the 128-bit path, where the halves each occupy one complete register. All variants share it. A newer compiler's original intrinsic still needs validation in a production build.
- For `-march=rv64gcv` without Zfh, this revision uses a 65,536-entry FP16-to-FP32 lookup table. The earlier reproduction substituted software conversion. I initially reused that setup, then corrected it because it changes the surrounding instruction stream. This study now extracts the actual lookup function into [conversion.inc](conversion.inc), initializes the table before testing/timing, and uses it in every variant. Builds enabling Zfh are intentionally rejected by this harness; they need a separate experiment.

These choices preserve more of the production context while keeping the experiment small. They still do not replace a full backend build with its real compiler settings.

## 6. What I tested and observed

I used GCC 13.3.0 and QEMU 8.2.2. Both `-O2` and `-O3` builds use:

```text
-g -Wall -Wextra -Wpedantic -Werror -Wno-unused-function
-march=rv64gcv -mabi=lp64d
```

The unused-function exception is for unused helpers in the copied upstream headers. I did not enable fast-math or disable the compiler's normal FMA contraction. Exact build flags and binary hashes are in [build-O2.txt](results/build-O2.txt) and [build-O3.txt](results/build-O3.txt).

Each build ran at emulated VLEN 128, 256, and 512. Every run passed **7,908 cases**:

- The six hand-calculated cases above, requiring the original's three expected failures.
- All 256 possible repeated packed bytes at 19 block counts, including zero, odd counts, and boundaries through 257 blocks.
- Signed activation extremes, position-dependent patterns, and zero, negative, fractional, and small finite scales.
- 3,000 deterministic random cases from seed `0x19b4a73d`.
- 38 cases with read-only inputs placed at either the beginning or end of a protected memory region. The end placement detects overreads; read-only pages detect writes. A zero-length end placement points at an inaccessible page.

Outputs also have neighboring sentinels. Failures print the case, RNG state, values, scales, and packed bytes for diagnosis.

For every case I required baseline and candidate to be **bit-identical**. I also compared them to the extracted generic function and an independently written scalar reference with 64-bit integer and double accumulation. The latter uses a separately stated decoding table and different indexing logic.

Float comparisons against references allow `1e-5 + 2e-6 * sum(abs(block_contribution))`. Scaling tolerance by contribution magnitudes handles cancellation better than scaling only by the final answer. This is an explicit test allowance for the finite inputs used here, not a proof for every possible float input. The stronger baseline/candidate check uses no tolerance.

All six build/VLEN combinations passed: **47,448 case executions**. See, for example, [the O2/VLEN128 log](results/check-O2-vlen128.log) and [the O3/VLEN512 log](results/check-O3-vlen512.log). These are repeated configurations of the same test corpus, not 47,448 distinct inputs. NaNs, infinities, every possible FP16 scale, arbitrary overlapping buffers, and vector widths beyond 512 were not validated.

I also deliberately added 1 to a candidate accumulator in a temporary copy. The harness rejected it at two blocks. That checks that a passing result is not simply caused by accidentally calling the baseline twice. See [mutation-check.log](results/mutation-check.log).

## 7. What the assembly revealed

[inspect.py](inspect.py) examines linked disassembly, finds the actual kernel symbols, saves separate listings, and checks that the proposed substitution occurred. Intrinsic source code alone cannot establish what the executable contains.

Both optimization levels show the same pair-loop counts:

| Path | Version | Vector stores of reduced results | Scalar reloads of those results | Direct scalar moves | Instructions per pair-loop body | Vector configurations in that body |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| VLEN128 | Baseline | 2 | 2 | 0 | 53 | 6 |
| VLEN128 | Candidate | 0 | 0 | 2 | 55 | 10 |
| Wider VLEN | Baseline | 2 | 2 | 0 | 58 | 3 |
| Wider VLEN | Candidate | 0 | 0 | 2 | 59 | 6 |

The original memory round trips survived compilation, and the candidate removes them. That part of the hypothesis is established for these builds.

However, GCC schedules the candidate's two blocks differently and inserts additional `vsetvli`/`vsetivli` instructions. These configure element width, register grouping, and active length. The candidate's loop has slightly more instructions overall. Some reconfiguration is needed to extract a 32-bit element after a 16-bit reduction; the changed schedule adds further transitions.

This is the central lesson of the experiment: **a cleaner-looking intrinsic expression can remove memory traffic while introducing other costs.** We need a real CPU to judge that tradeoff. The counts are static counts for the generated loop body, not measured cycles. At `-O3`, the scalar tail is also heavily unrolled and creates unrelated scalar stack traffic; whole-function stack-load counts must not be mistaken for result reloads or vector spills.

The machine-readable evidence is in [O2 assembly counts](results/study-O2-assembly.json) and [O3 assembly counts](results/study-O3-assembly.json). Start with the [O2 baseline/VLEN128 listing](results/study-O2-baseline_vl128.dis) and [candidate listing](results/study-O2-candidate_vl128.dis). Search for `vwredsum.vs`, `vse32.v`, `lw`, `vmv.x.s`, and the surrounding configuration instructions.

My decision is to retain this as an inexpensive hardware experiment, with mixed static evidence. I would not select it as a production improvement yet. A useful subsequent hypothesis would be reducing configuration churn while retaining direct extraction; that deserves its own patch and comparison.

## 8. Reproducing everything locally

From the parent workspace:

```sh
sh kernel-study/check.sh
```

This checks frozen-source hashes, regenerates variants and patches, compiles both optimization levels, inspects assembly, and runs all six emulated configurations. It verifies patch application and the deliberate mutation check, then smoke-tests the benchmark CSV and summarizer. No network access or model is required. Dependencies are Python 3, `patch`, the installed RISC-V GCC/binutils, QEMU user mode, and the RISC-V libraries at `/usr/riscv64-linux-gnu`.

The generated [emulated benchmark CSV](results/emulated-benchmark-SMOKE-ONLY.csv) exists only to test the measurement machinery. It is not used to rank candidates. QEMU does not model native instruction timing; its own [documentation explains this limitation](https://www.qemu.org/docs/master/devel/tcg-icount.html).

To refresh the frozen inputs deliberately, `python3 kernel-study/prepare.py /path/to/llama.cpp` requires the pinned revision and unchanged input files. Ordinary reruns do not need this step. The generation checks are intended to fail visibly if their assumptions no longer hold.

## 9. The hardware experiment that is ready to run

Copy this directory onto a real RV64 Linux machine with RVV 1.0 and VLEN 128, 256, or 512. Install a compiler providing the required intrinsics, binutils, Python 3, and `taskset`. Then choose an available CPU, for example:

```sh
CPU=0 ITERATIONS=10000 SAMPLES=21 sh benchmark-native.sh
OPT=O3 CPU=0 ITERATIONS=10000 SAMPLES=21 sh benchmark-native.sh
```

The script rebuilds locally, checks the generated extraction pattern, pins execution to the selected CPU, runs correctness first, and then records timing samples. It saves the binary, its hash/build flags, CPU information, raw CSV, and a summary under a new `results/native-.../` directory. A different compiler may generate different code and trip the inspection checks; inspect that change before adapting the checks.

The benchmark uses 1, 2, 8, 32, 128, 129, and 256 blocks, with warmup calls and alternating baseline/candidate order. Every output remains observable. One block is a useful control: it uses only the shared scalar tail and should have no systematic extraction benefit. The summary reports medians and the range of paired baseline/candidate ratios; a ratio above 1 favors the candidate. It does not assert statistical significance.

This is a warm-cache microbenchmark with reused buffers, eight selected scale values, dispatch/call overhead, and an output-observation store. Start with enough iterations to make each batch comfortably exceed timer overhead, repeat independent sessions, and record frequency policy, thermal state, competing load, and any deviations from the commands. A tiny difference comparable to session-to-session variation is inconclusive. Streaming weights, broader scales, and multithreading need additional workloads.

Before claiming an inference improvement, the remaining steps are:

1. Integrate the patches into a separate experimental llama.cpp copy, rebuild baseline and candidate with identical production flags, and inspect the resulting backend code again. Test Zfh or other target-specific extensions separately if the chosen CPU/build uses them.
2. Run the existing backend correctness tests for the affected IQ4_NL matrix operations and appropriate reference comparisons. Measure the containing operation as well as the isolated function. These full-backend tests have not been run here.
3. Choose an actual model containing IQ4_NL tensors, verify by profiling or temporary instrumentation that this function is selected, and measure prompt processing and token generation separately. A quantization label alone does not establish dispatch or runtime share.
4. Use identical model files and runtime settings, CPU execution, warmups, repeated interleaved runs, and raw samples. For this pinned version, a starting command is `llama-bench -m MODEL.gguf -ngl 0 -t 1 -p 512 -n 128 -r 21 -o json`; confirm options against the built binary. The [frozen benchmark README](source/tools/llama-bench/README.md) describes the parameters and per-repetition JSON samples. Check model correctness/perplexity as appropriate.

A kernel improvement helps inference only in proportion to the time spent on that path. If it accounts for 20% of runtime and becomes twice as fast, the ideal overall runtime is `0.8 + 0.2/2 = 0.9`, about an 11% speedup. If the workload bypasses it, the benefit is zero.

## 10. What you can learn from this example

Try explaining these points after finishing the exercises:

- Why do low and high nibbles correspond to two activation halves?
- Why can the wider-vector path safely add two products in 16-bit lanes?
- Why must the odd-block correction be shared by both benchmark versions?
- Why is signed scalar extraction equivalent to storing and reloading this result?
- Why do the extra configuration instructions prevent a speed claim from instruction selection alone?
- What evidence would make you discard this candidate even if the microbenchmark improved?

I completed source tracing, baseline construction, the candidate implementation, differential testing, assembly analysis, and benchmark preparation autonomously. The remaining decisions become meaningful when hardware is available: which CPU and ISA extensions we target, which model/workload matters, and whether the measured benefit justifies the change. Your part in learning is to inspect and challenge the reasoning until you can explain the proposed change yourself. This directory is an AI-assisted private learning experiment, not an upstream contribution or a claim of production readiness.
