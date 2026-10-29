# Measurement setup

Run commands below from the workspace root unless stated otherwise. This setup
uses Python's standard library. It does not require an installation step.

## What works now

- Tool/platform inventory: `measure.py doctor`.
- Command capture: exact argv, working directory, selected environment variables,
  CPU/OS/affinity/frequency/cache metadata where exposed, executable/input copies
  and hashes, independent stdout/stderr, exit status and process elapsed time.
- Explicit smoke/host-practice/native classifications; native mode requires a
  riscv64 host. Missing events or profiler failures remain failures.
- Optional native `perf stat` and `perf record` wrappers, prepared but not tested
  against real perf/PMU hardware on the current x86_64 WSL2 machine.
- Existing IQ4 correctness, assembly and benchmark plumbing under QEMU.

The architecture guard is a useful mistake detector, not proof of native
execution: a riscv64 guest, wrapper script or indirect emulator may evade it.
Native mode is an assertion by the operator. Smoke and host-practice results
must never be used to rank RVV candidates. Successful capture is not validation
of benchmark methodology or statistical significance.

## Inventory and local verification

```sh
python3 kernel-study/measure.py doctor --output kernel-study/results/setup-environment.json
python3 -m unittest discover -s kernel-study/tests -v
sh kernel-study/check.sh
```

The inventory records missing tools without failing; it does not probe PMU
access. It captures selected measurement-related environment variables, not the
whole shell environment. Avoid including credentials in benchmark argv or files
passed to `--artifact`, because those are intentionally saved.

Capture an emulated benchmark smoke test (run the checks/build first):

```sh
python3 kernel-study/measure.py run --kind smoke \
  --artifact kernel-study/results/build-O2.txt \
  --artifact kernel-study/results/study-O2 \
  --artifact kernel-study/results/study-O2-assembly.json \
  --artifact kernel-study/source-manifest.json \
  -- qemu-riscv64 -L /usr/riscv64-linux-gnu \
  -cpu max,vlen=128,elen=64,vext_spec=v1.0 \
  kernel-study/results/study-O2 --bench 3 2
```

The runner prints the new directory under `results/runs/`. Its `rep-001.stdout`
is the benchmark CSV; validate it with
`python3 kernel-study/summarize.py RUN_DIRECTORY/rep-001.stdout --smoke`.
These very short runs only check plumbing.

## Capturing another command

```sh
python3 kernel-study/measure.py run --kind host-practice --repetitions 3 \
  --timeout 60 --artifact path/to/build-flags.txt -- path/to/program arg1 arg2
```

Replace example paths with real files. Arguments after `--` are passed directly
without a shell. Options before `--` configure capture. `--artifact` can be
repeated for source manifests, binaries, build configuration, model hashes,
input descriptions or correctness logs. The command executable itself is copied
automatically; interpreter scripts, invoked binaries behind taskset/emulators,
shared libraries and data files are not discovered automatically. Archive or
reference those deliberately. Capturing a model hash is preferable to copying a
large model. The artifacts are provenance, not a standalone deployment bundle.

Each repetition launches a fresh process; its elapsed time includes startup,
teardown and profiler overhead. Use the benchmark's internal measurements for
kernel comparisons. This runner does not add warmup, select inputs, interleave
baseline/candidate binaries or infer a speedup. The IQ4 benchmark already
interleaves variants internally. The first failed repetition stops the run.
Timeout applies to the direct subprocess, not an arbitrary descendant tree.
Use `--output-dir NEW_DIRECTORY` for a chosen location; existing paths are
rejected rather than reused. Process failures and capture errors retain run.json
and available diagnostics. Host-practice can validate a native x86 benchmark
workflow, but its results cannot establish RVV performance.

## On the real RISC-V board

Install the board distribution's compiler, binutils, Python 3, taskset and a
kernel-compatible perf package. Package names vary by distribution/kernel; do
not assume Ubuntu host package names apply. Check the board's RVV version,
VLEN, ISA extensions and PMU support. The IQ4 study pins rv64gcv and table-based
FP16 conversion; enabling Zfh needs a separate experiment.

First run `doctor`, then `perf --version` and `perf list`. Test permission and
event availability on a sufficiently long native benchmark. The wrappers do
not change kernel permissions, CPU affinity, frequency policies or events
automatically. Select an allowed CPU from the captured affinity list and pin
single-thread experiments with taskset. Record thermal state separately; sampled
frequency metadata is a snapshot, not proof of a stable clock.

The existing IQ4 script now captures provenance through the new runner:

```sh
cd kernel-study
CPU=0 ITERATIONS=10000 SAMPLES=21 sh benchmark-native.sh
```

Choose an available CPU instead of assuming CPU 0 is allowed. The script builds,
checks assembly, runs correctness, and captures its paired benchmark in
`results/native-.../`. Its `samples.csv` and `summary.txt` remain at the top level;
`capture/` contains command/environment JSON, archived inputs, and raw streams.
Adapt iterations to the board so timed batches exceed timer overhead.

For separate profiling runs from the workspace root, using that built binary:

```sh
python3 kernel-study/measure.py run --kind native --profile stat \
  --artifact kernel-study/results/study-O2 \
  -- taskset -c 0 kernel-study/results/study-O2 --bench 10000 21

python3 kernel-study/measure.py run --kind native --profile record \
  --artifact kernel-study/results/study-O2 \
  -- taskset -c 0 kernel-study/results/study-O2 --bench 10000 21
```

`stat` requests task-clock, cycles and instructions by default. Unsupported or
uncounted events produce a failed capture; supply `--events task-clock` to
explicitly request only that software event when hardware events are unavailable.
Report that limitation. `record` requests cpu-clock:u at 99 Hz without call
graphs. A short run may produce too few samples; use a long enough workload and
inspect perf's diagnostics. A nonempty data file alone does not prove adequate
sampling. Call-stack unwinding and hardware-event sampling require board-specific
validation. Never mix these profiled durations into unprofiled benchmark results.

Inspect a recorded profile using its actual directory:

```sh
perf report --stdio -i RUN_DIRECTORY/rep-001.perf.data
perf annotate --stdio -i RUN_DIRECTORY/rep-001.perf.data
```

Keep original executable/library paths available for perf symbolization, or
configure perf's build-ID/symbol cache. Archived binary copies are evidence;
the runner does not configure perf's symbol lookup automatically. Build optimized
code with symbols. Inspect function resolution and sample counts before drawing
conclusions. Profiles/counters cover the whole launched workload, including its
initialization, correctness calls and both variants in the IQ4 --bench mode.
For variant-specific attribution use separate, dedicated workloads later.

## Remaining work and acceptance

Native timing and real perf have not been validated here. On the board, require:
correct baseline, useful symbols, enough samples, a documented event set and
repeatability across independent sessions. Verify actual dispatch at operation
and model levels before ranking opportunities. Set up test-backend-ops and
llama-bench against a newly pinned full checkout and a chosen fixed model.

The current IQ4 harness is warm-cache only. Streaming inputs, additional kernel
harnesses and an LLVM scheduling-model evaluation remain follow-up work. No
llvm-mca, gem5 or Ara installation is required for this initial capture setup.
The team's investigation workflow can be defined once the shared baseline
measurements and board-specific capabilities are established.

## Verification on 2026-10-29

Eight capture tests passed, including subprocess failures, timeout, shell-literal
arguments, artifact hashes, mode guards and simulated perf outputs. The full
existing IQ4 check passed 7,908 cases in each of six O2/O3 and VLEN configurations
(47,448 case executions), patch reconstruction, mutation detection and CSV smoke
validation. A separate QEMU benchmark passed through measure.py and its captured
CSV passed the summarizer's smoke check:
[captured run](../../results/runs/20261029T163202Z-lrwc8sg4/run.json).
The [inventory](../../results/setup-environment.json) identifies this host as
x86_64 WSL2. Native mode was observed to reject it. Native perf and the native
shell script's actual RVV execution remain unverified.

References: [perf stat](https://man7.org/linux/man-pages/man1/perf-stat.1.html),
[perf record](https://man7.org/linux/man-pages/man1/perf-record.1.html),
[QEMU timing limitation](https://www.qemu.org/docs/master/devel/tcg-icount.html).
