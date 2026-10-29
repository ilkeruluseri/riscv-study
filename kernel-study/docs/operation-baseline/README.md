# Unchanged model-free operation baseline

This suite runs whole CPU operations through upstream test-backend-ops. It is a
baseline preparation step for the three investigations, not an RVV speedup test.
No model weights are needed. The existing IQ4 extraction study is unchanged.

## Prepare and run

From the workspace root, with Python 3.12+, Git, CMake, Ninja and a C/C++ compiler:

```sh
python3 kernel-study/baseline.py prepare --source-repo /path/to/llama.cpp
python3 kernel-study/baseline.py run
```

Preparation exports revision `31385c9cebf9e5271a38e14c26e5df6dd93718b1` with
git archive. That preserves a full known source baseline and excludes local
changes/untracked files. It is deliberately the local study's revision, not a
claim to be current upstream. Recheck current upstream and open PRs before
developing a contribution. `--revision FULL_COMMIT` selects another baseline
explicitly. The default ignored workspace is `kernel-study/workspace/operation-baseline`;
use `--workspace NEW_PATH` before the subcommand for another build. An existing
directory is refused unless `prepare --resume` is supplied. Resume verifies
the source before reconfiguring/rebuilding. The original checkout is read-only
input and is never patched.

The build is optimized with symbols (RelWithDebInfo), static libraries, CPU
native tuning, dynamic backend loading off, BLAS off and CPU repacking off.
It builds test-backend-ops, llama-bench and a case exporter. Optional HTTPS,
server, examples and multimodal tools are disabled. Sources remain unchanged;
configuration is explicit. Disabling repacking narrows the initial experiment,
but does not establish which other matrix path executes. A default production
configuration is a later comparison. Rebuild on the board; the host binary is
not portable. Record optional ISA flags before comparing RVV implementations.

The export has no Git metadata. Git discovery is prevented from walking into
the enclosing learning repository. Upstream embedded commit strings may say
unknown; `source.json` and its per-file hashes identify the actual source.
Every suite run checks source and executable hashes. Preparation saves the
configure/build argv and logs, CMake cache, compile commands, source archive and
case definitions. Archive checks do not make system libraries/toolchains portable.
Keep generated files out of the exported source tree. When inspecting its Python
utilities, set PYTHONDONTWRITEBYTECODE=1 or use the original checkout so caches
do not invalidate the exact snapshot check.

## Fixed operation shapes

- Seven F32 RMSNorm cases: widths 31, 32 and 33 with one row, and widths 896 and
  4096 with one and eight rows. Epsilon is 1e-6.
- Nine matrix cases: weight types Q8_0, Q4_0 and IQ4_NL; 64 output rows;
  reduction width 896 with one/eight input columns, and width 4096 with one.
  Activations presented to the operation are F32; the CPU operation performs
  any internal conversion. These are not prequantized activation microbenchmarks.

The small row counts bound setup time; these shapes are not full model layers.
All quantized widths contain an even number of 32-element blocks, so they do not
exercise the historical IQ4 odd-block defect. Tail testing remains in the
isolated correctness harness. RMSNorm widths exercise boundaries without
assuming one vector length. Fusion, aliasing and unusual layouts need further cases.

The exporter uses actual ggml constructors and serializes their operation enums,
parameters, tensor dimensions and strides into upstream's test-file format.
There are no hardcoded numeric enum values. Each case has a stable ID and a hash
in cases.json. The same file drives test and perf modes. Upstream compares the
tested CPU backend with its reference CPU implementation; for operations with
shared code, this is not an independent mathematical oracle. Preserve and add
independent references when implementing a candidate.

## Run behavior and interpretation

The default runs correctness once before three performance repetitions for each
case. Each repetition is a fresh process; upstream warms the operation and
times repeated execution for at least one second, reusing the same tensors.
The suite uses upstream SQL because this revision's CSV omits timing columns.
An empty, unsupported, failed or mismatched result is rejected even when the
upstream process exits successfully. A failed suite preserves its partial data
and status; only a complete suite emits operations.csv.

```sh
python3 kernel-study/baseline.py run --mode test
python3 kernel-study/baseline.py run --case rms-f32-k896-n1 --repetitions 3
python3 kernel-study/baseline.py run --case mat-iq4_nl-m64-k896-n1
```

Default classification is host-practice. Use `--kind native` only after rebuilding
on a real riscv64 host; the existing architecture guard applies. Do not compare
host timings with board timings or label x86 results as RVV evidence.

Two upstream limitations are explicit:

1. The tested backend uses `max(1, hardware_concurrency()/2)` threads in this
   revision. `-j` selects test workers, not backend threads. This unchanged
   tester is not our single-thread kernel harness; OMP_NUM_THREADS does not
   override its explicit backend thread setting. Record the policy and platform.
2. Tensor values use upstream random initialization without a fixed seed.
   Case shapes are reproducible; exact values are not. This is adequate for a
   setup baseline, not for attributing a small data-dependent speed difference.
   Deterministic candidate experiments still use their own seeded inputs.

Profiling should isolate one case (and one variant once implemented), run long
enough to collect samples, and verify dispatch with symbols/instrumentation.
The [recorded host operation profiles](../profiling-setup/baseline-profile.md)
demonstrate runtime overhead in these small cases. Whole-process profiles
include randomized initialization, allocation and setup; inspect those separately
from the timed operation. A dedicated steady-state harness is needed when that
overhead obscures the computation.

Once rebuilt and validated on the board, a separate baseline-only profile can
use a single case directly (this is not a timing-comparison command):

```sh
python3 kernel-study/measure.py run --kind native --profile record \
  --artifact kernel-study/workspace/operation-baseline/source.json \
  --artifact kernel-study/workspace/operation-baseline/build.json \
  --artifact kernel-study/workspace/operation-baseline/cases/rms-f32-k896-n1.txt \
  -- kernel-study/workspace/operation-baseline/build/bin/test-backend-ops \
  perf -b CPU --output sql \
  --test-file kernel-study/workspace/operation-baseline/cases/rms-f32-k896-n1.txt
```

Run the case's correctness check first. Default sampling is 99 Hz; inspect the
actual sample count and increase the steady-state workload if necessary. This
command still uses the tester's thread policy and whole-process sampling scope.

## Shared result format

Each suite creates `kernel-study/results/operations/TIMESTAMP-.../`:

- suite.json: schema version, run classification, source revision, build hash,
  case definitions, thread/input policy, completion status and normalized rows.
- operations.csv: one row per case/mode/repetition. Fields are case_id, operation,
  mode, repetition, time_us, n_runs, kind, raw_capture and raw_stdout.
- summary.json: median/min/max of performance repetitions for each case, with
  classification retained. This describes spread, not statistical significance.
- CASE_ID/test or perf: measure.py's run/environment JSON, raw streams and
  archived executable/build/source/case evidence.

`time_us` is upstream's mean operation time for its internal loop; `n_runs` is
the number of internally timed operations. Test-mode time_us is zero and must
not enter timing summaries. measure.py's elapsed_ns instead covers process
startup, setup and teardown. The two measurements are different scopes.
Do not discard raw repetitions or infer significance from one suite. Rerun
independent sessions to assess variation. Copy reviewed result bundles to shared
storage deliberately; generated results/workspaces are ignored by Git.

The research-card template in this directory provides a common record for the
team. It separates a supported hypothesis from native performance evidence and
requires the exact baseline, case, command, correctness contract and decision.

## Verified local baseline

On 2026-10-29 the unchanged pinned source built successfully on x86_64 WSL2.
The final full session passed all 16 correctness cases and collected three
timing repetitions per case (48 timings). It produced 64 normalized rows and
16 timing summaries, with complete raw captures and script/build provenance:
[suite manifest](../../results/operations/20261029T170124Z-w6idlpdc/suite.json),
[operation table](../../results/operations/20261029T170124Z-w6idlpdc/operations.csv),
[timing summary](../../results/operations/20261029T170124Z-w6idlpdc/summary.json).

All 12 Python tests passed. Post-run file hashes confirmed the exported source
still matched its pinned archive, and native mode rejected this x86_64 host.
The original external checkout's tracked files were unchanged. These results
are host practice. No model inference, sampled perf profile, hardware-counter
measurement or RVV performance ranking was performed.

That paragraph describes the first operation timing session. Subsequent
[operation profiles](../profiling-setup/baseline-profile.md) and
[real-model inference profiles](../inference-baseline/results.md) are now available.
