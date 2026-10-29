# Reviewed host evidence: 2026-10-29

This small, committed snapshot lets teammates inspect the recorded findings
without the original multi-GB local capture directories. It is data from the
unchanged baseline, not a performance claim for a proposed optimization.

## Provenance and scope

- Host: Intel Core Ultra 9 275HX, x86_64 Ubuntu 24.04 / WSL2 kernel 6.6.87.2.
- llama.cpp: 31385c9cebf9e5271a38e14c26e5df6dd93718b1, full source exported
  without modification. RelWithDebInfo, native CPU tuning, BLAS/repacking off.
- Models: official Qwen2.5-0.5B-Instruct Q4_0/Q8_0 GGUF files, repository revision
  9217f5db79a29953eb74d5343926648285ec7e67. Inventory files retain published and
  verified hashes and all tensor names/shapes/types; model files are not included.
- perf: 6.8.12, cpu-clock:u sampling at 99 Hz, no call graphs. No hardware
  cycles/instructions, cache or stall measurements were available.
- Inference: one thread, CPU 0 affinity, batch/microbatch 128, F16 KV, flash
  attention off, polling zero, CPU-only, warmup enabled. pp128/pp512/tg128 each
  have 21 unprofiled repetitions per model. Four separate profiles contain five
  internal repetitions each, 9,337 samples total, and report zero lost samples.
- Model-free operation tester: upstream-selected 12 backend threads, randomized
  tensor values, 16 correctness cases plus 48 timing repetitions. Twelve separate
  operation profiles contain 14,255 samples. Do not mix those multithreaded
  timings with the one-thread inference data.

All results are host-practice. Native RVV dispatch and performance are unmeasured.
Profiles include initialization and warmup; inference internal timings do not
include loading. Synthetic token streams use real model weights but do not
measure language quality. Different hosts and independently repeated sessions
need not reproduce absolute throughput.

## Included files

- inference-timings.csv: all 126 unprofiled internal timing rows.
- inference-summary.json: source/build identity, descriptive rates and four
  profile summaries. The executable path is normalized to its basename.
- model-q4_0.json / model-q8_0.json: model identities and tensor inventories,
  with paths normalized to basenames; no weight data.
- q4_0/q8_0 pp512/tg128 profile text: compact perf reports regenerated from the
  original perf.data with semicolon-separated fields, field padding trimmed, and a 0.5% display threshold.
  Reports preserve zero-loss headers; filtered rows need not sum to 100%.
- operation-timings.csv and operation-summary.json: all operation timing/test
  rows and descriptive summaries from the completed baseline session.
- operation-profiles.json: sample and period totals from 12 operation profiles.
- openmp-hot-addresses.dis: inspected libgomp polling/state-update instructions.
- SHA256SUMS: integrity hashes for the snapshot files, including this README.

CSV line endings are normalized to LF and disassembly trailing spaces trimmed;
timing values and instructions are unchanged. Repository
attributes preserve LF in this snapshot so its hashes survive fresh checkouts.

Original local bundle IDs:

```text
operations/20261029T170124Z-w6idlpdc
profiles/20261029T172121Z-pjl3ysvp
inference/20261029T175905Z-337re8bq
```

raw_capture/raw_stdout/report fields in copied tables/manifests refer to paths
inside those original bundles, not this directory. Raw perf.data, binaries,
full environment snapshots and model weights are intentionally excluded from
Git. Ask the run owner for the complete archived bundle when doing a deeper
audit, or generate a new bundle using the root quick start.

The complete collection commands remain in the drivers and protocols. Compact
reports were produced by `perf report --stdio --no-children --sort dso,symbol
--percent-limit 0.5 --field-separator ';' -i ORIGINAL.perf.data`.

## Inspect and reproduce

```sh
cd kernel-study/evidence/host-2026-10-29
sha256sum --check SHA256SUMS
```

Return to the repository root and follow the [fresh-clone quick start](../../../README.md).
Read the [inference findings](../../docs/inference-baseline/results.md) and
[operation profile interpretation](../../docs/profiling-setup/baseline-profile.md)
before drawing conclusions or choosing a candidate.
