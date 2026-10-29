# RISC-V kernel investigation workspace

This repository contains RVV learning exercises and reproducible llama.cpp
kernel, operation and real-model investigations for a three-person team.
We have validated correctness under QEMU and collected real x86 CPU profiles.
Native RVV performance is still unmeasured.

Start with the [research shortlist](kernel-study/docs/research-shortlist.md),
[real-model findings](kernel-study/docs/inference-baseline/results.md), and
[small committed evidence snapshot](kernel-study/evidence/host-2026-10-29/README.md).
The [original IQ4 experiment](kernel-study/README.md) is a separate worked example.

## Reproduce from a fresh clone: Ubuntu 24.04 / x86_64

Run these commands in a normal terminal with network access. From outside this
checkout:

```sh
git clone https://github.com/ilkeruluseri/riscv-study.git
cd riscv-study
sudo apt-get update
sudo apt-get install build-essential cmake ninja-build git curl python3-venv \
  linux-tools-common linux-tools-generic
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r kernel-study/requirements-profile.txt
```

Python 3.12+ is required. The NumPy pin matches the metadata-reader environment
used here. The benchmark executable itself is C++; NumPy is only for inspecting
GGUF metadata. Default native CPU tuning means binaries and absolute throughput
are host-specific. A fresh build normally takes several minutes and the full
inference run can take around ten minutes on one core. Allow several GB for
sources, debug binaries and copied capture artifacts, plus 1.1 GB of model files.

Fetch the exact full llama.cpp source revision, then build our unmodified CPU
baseline. The small frozen source subset already in this repo is only for the
isolated IQ4 study; it cannot build the full operation/inference baseline.

```sh
mkdir -p kernel-study/workspace/llama-upstream
git -C kernel-study/workspace/llama-upstream init
git -C kernel-study/workspace/llama-upstream remote add origin https://github.com/ggml-org/llama.cpp.git
git -C kernel-study/workspace/llama-upstream fetch --depth 1 origin 31385c9cebf9e5271a38e14c26e5df6dd93718b1
git -C kernel-study/workspace/llama-upstream checkout --detach FETCH_HEAD
python kernel-study/baseline.py prepare --source-repo kernel-study/workspace/llama-upstream
python -m unittest discover -s kernel-study/tests -v
python kernel-study/baseline.py run --mode test
```

These are first-time setup commands. For an existing source checkout, pass its
path to prepare. For an existing exported baseline, `prepare --resume` verifies
its source hashes and retries/reconfigures the build. Use a new workspace for a
different source revision. See the [operation guide](kernel-study/docs/operation-baseline/README.md).

## Check perf and collect results

```sh
export PERF=perf
"$PERF" --version
"$PERF" stat -e task-clock:u -- sleep 1
```

On WSL, Ubuntu's /usr/bin/perf wrapper may refuse the Microsoft kernel name.
Find the real installed binary and assign its actual path to PERF:

```sh
find /usr/lib -path '*linux-tools*' -type f -name perf
export PERF=/usr/lib/linux-tools-6.8.0-147/perf
"$PERF" --version
"$PERF" stat -e task-clock:u -- sleep 1
```

The example path above is the one tested here; choose the path installed on your
machine. Do not assume hardware counters are available: this WSL host supports
software CPU-time events, while cycles/instructions are unavailable. See
[perf setup and troubleshooting](kernel-study/docs/profiling-setup/host-perf.md).
If permissions or kernel support prevent collection, retain that diagnostic;
unprofiled operation timings can still run without perf.

From the repository root, with the virtual environment activated and PERF set:

```sh
python kernel-study/measure.py doctor --output kernel-study/results/my-environment.json
python kernel-study/baseline.py run
python kernel-study/profile_operations.py
sh kernel-study/download-models.sh
python kernel-study/inference_baseline.py
```

The download script uses immutable model URLs, resumable temporary files and
published SHA-256 checks. Already verified files are reused. The inference
driver verifies hashes again. It runs one thread pinned to one allowed CPU,
separate pp128/pp512/tg128 benchmarks with 21 repetitions each per model, and
four separate software-event profiles. Use --cpu to choose an allowed CPU.
Models, build outputs and new run bundles stay under Git-ignored workspace/results.

Read the [inference protocol](kernel-study/docs/inference-baseline/README.md)
before comparing results. These are real weights with synthetic token streams;
they are not a language-quality test. Check profile sample count, losses, symbol
resolution and actual dispatch. Model loading/warmup is included in profiles,
but excluded from internal benchmark timings. Different machines need not match
the committed throughput numbers.

## Optional: reproduce the isolated RVV correctness study

```sh
sudo apt-get install gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu qemu-user
sh kernel-study/check.sh
```

This uses the frozen inputs in kernel-study/source and needs no model or full
llama.cpp checkout. It tests O2/O3 at emulated VLEN 128/256/512. QEMU elapsed
time is not native performance evidence. See the study README for compiler
compatibility and numerical/tail constraints.

## How the team should retain evidence

- Follow the [hypothesis card](kernel-study/docs/operation-baseline/hypothesis-template.md):
  one change, source/dispatch evidence, correctness contract and a reject condition.
- Retain raw repetitions, exact commands, source/model/binary hashes and profiles.
  Separate smoke, host-practice and native runs; never combine profiled and
  unprofiled durations in one speed comparison.
- Commit source, tests, case definitions, protocol changes and a small reviewed
  evidence snapshot. Keep large raw bundles and model weights outside Git.
- Each driver prints its results directory. To share a raw run, archive that
  complete directory with `tar -czf my-run.tar.gz -C kernel-study/results RUN_PATH`
  (replace RUN_PATH with, for example, inference/TIMESTAMP-ID), then share the
  archive through the team's chosen file storage. No external publication is
  performed by these tools. Do not upload model weights inside run archives.
- On a real RISC-V board, rebuild locally, record compiler/ISA/VLEN and available
  PMU events, validate the selected RVV paths, then use --kind native. The current
  x86 profiles establish host workload behavior, not RISC-V bottlenecks.
