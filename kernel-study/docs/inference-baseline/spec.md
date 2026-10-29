# Real-model inference baseline

## What
Verify the two downloaded official Qwen2.5-0.5B-Instruct GGUF files, then collect
unprofiled single-thread benchmarks and separate software CPU-time profiles.

## Requirements
- Require the published hashes and record complete tensor type/shape inventories.
- Use the unchanged full pinned source/build; preserve binary/config/source hashes.
- Pin one available CPU, request one inference thread and CPU-only execution,
  fix batch/microbatch 128, F16 KV, no flash attention/repacking, and warmup on.
- Benchmark pp128, pp512 and tg128 separately, 21 raw repetitions each per model.
- Profile pp512 and tg128 separately with five repetitions each per model;
  retain raw perf.data, reports and parsed weighted samples. Do not mix profiled
  timings into the unprofiled table.
- Validate returned model filename, phases, thread/backend settings, repetition
  counts and finite positive timings. Preserve failure diagnostics and status.
- Record loading/warmup as part of profile scope; benchmark internal timers
  exclude model loading. Synthetic token streams exercise real model weights,
  not natural-language quality or tokenizer/sampler behavior.
- No native RVV, model accuracy, cache/stall or candidate speedup claims.

## Design
Add inference_baseline.py using existing measure.py capture and profile parser.
Use pinned gguf-py read-only with bytecode disabled. Archive hash/inventory
manifests rather than copies of large model weights. Export normalized CSV,
raw benchmark JSON, descriptive summaries and separate profile summaries.

## Testing Strategy
Test benchmark JSON rejection for wrong threads/phases/model/repetition count
and invalid timings. Run actual inference and perf, inspect symbol resolution,
sample counts/loss, and verify final source/model hashes.

## Out of Scope
Quantization quality, natural-language evaluation, IQ4_NL model generation,
multiple architectures/thread counts, and production-default configuration claims.
