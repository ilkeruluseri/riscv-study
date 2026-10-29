# Model-free operation baseline

## What
Build an unchanged full llama.cpp snapshot from an explicit local Git revision
and exercise bounded RMSNorm and quantized matmul cases, without model weights.
Use the existing measurement capture format and add a normalized operation table.

## Requirements
- Export an immutable revision into an ignored workspace; never edit the external
  checkout or silently refresh the IQ4 frozen inputs.
- Preserve archive/file hashes, configure/build commands, compiler metadata,
  CMake cache, compile commands and benchmark binary hash.
- Build optimized CPU-only code with symbols, tests and llama-bench; disable
  optional network dependencies and dynamic backend loading.
- Feed bounded, named synthetic cases through upstream test-backend-ops using
  its test-file interface. Run correctness before timing. Reject empty, skipped,
  unsupported or failed result sets rather than reporting a false success.
- Produce stable case definitions and a normalized CSV/JSON schema referencing
  the captured raw evidence. Classify local results as host practice, not RVV.
- Document tester-chosen threads and upstream random inputs; do not claim this
  suite is a single-thread deterministic microbenchmark or proves kernel dispatch.
- A baseline-only case filter supports future profiles. Real perf remains
  unavailable here; no emulator or native x86 results rank RVV candidates.

## Design
Add baseline.py to export/configure/build/run the upstream tester. Generate
test-file cases via a small C++ helper using the pinned ggml API, avoiding hardcoded
operation enums. Archive tool and suite inputs through measure.py. Prefer SQL
output for operation timing fields absent from upstream CSV. Record host CPU
affinity and distinguish operation time from process time. Use a static build
to simplify executable provenance and profile symbolization.

## Testing Strategy
Run the actual full baseline build and bounded correctness/performance cases.
Test result validation against empty/unsupported/failed/mismatched cases and
snapshot tampering. Check complete normalized results and the existing capture
tests. Keep upstream sources unchanged and verify snapshot hashes after builds.

## Out of Scope
Kernel changes, board-specific flags/counters, streaming microbenchmarks, model
downloads, inference claims, and statistical significance from host timings.
