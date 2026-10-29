# First real-model inference benchmark and profile

Completed 2026-10-29 on Intel Core Ultra 9 275HX under x86_64 WSL2, with the
unchanged pinned llama.cpp build. This is host-practice evidence, not RVV
performance or an optimization comparison. Both official downloaded model
files matched their expected SHA-256 before and after measurement.

## Workload and measurement

Qwen2.5-0.5B-Instruct, Q4_0 and Q8_0 files at the pinned model revision, using
CPU 0 affinity, one inference thread, batch/microbatch 128, F16 KV, flash
attention off, CPU repacking off, polling zero and CPU-only evaluation. These
are deliberately fixed research settings rather than production defaults.
The build has symbols, native CPU tuning, BLAS off and static GGML libraries.
See the [protocol](README.md) for commands and exact source/model identities.

Each of pp128, pp512 and tg128 ran separately for each model with 21 unprofiled
repetitions: 126 raw timings. Profiles were collected separately for pp512 and
tg128, each containing five internal workload repetitions. No profiled timings
enter the table below. Four profiles contain 9,337 parsed cpu-clock:u samples
at 99 Hz, with zero lost samples reported. There are no call graphs or hardware
counter results; cycles/instructions are unsupported on this WSL host.

llama-bench uses synthetic token streams with real model weights. Prompt tests
process batches; decode tests evaluate one token at a time, growing from context
depth zero to 128 tokens. This is actual model evaluation, but not a text-answer,
tokenizer, sampler, perplexity or model-quality test. Successful evaluation does
not prove numerical equivalence for a future candidate.

## Unprofiled throughput

Median tokens/s, with the range across 21 repetitions in parentheses:

| Model file | Prompt 128 | Prompt 512 | Decode 128 |
|---|---:|---:|---:|
| Q4_0 | 129.08 (128.34–130.14) | 121.98 (112.34–122.70) | 33.49 (29.55–34.49) |
| Q8_0 | 139.20 (125.07–140.53) | 130.32 (127.93–131.51) | 25.92 (22.32–26.46) |

These describe one host/session. Clock/thermal behavior and background load
were not experimentally controlled; environment snapshots and raw repetitions
are retained. The numbers do not establish statistical significance, quality
equivalence between quantizations, or expected throughput on a RISC-V board.
The benchmark reports 630,167,424 parameters for these GGUF files; its rounded
model-type label is not the source of model identity. File hashes are.

## Profile findings

Percentages are self-samples weighted by CPU-clock periods across the complete
profile process. Loading and warmup are included, so these are not exact fractions
of the internal timed region or wall-clock latency. Symbols resolve in the
application, and no libgomp samples were observed in these four recordings.

| Model / phase | Leading observed functions | Share of sampled userspace CPU time |
|---|---|---:|
| Q4_0 / prompt 512 | quantized tinyBLAS_Q0_AVX Q4_0×Q8_0 gemm4xN<2> | 81.09% |
| Q8_0 / prompt 512 | quantized tinyBLAS_Q0_AVX Q8_0×Q8_0 gemm4xN<2> | 78.96% |
| Q4_0 / decode 128 | ggml_vec_dot_q4_0_q8_0 | 61.31% |
| Q4_0 / decode 128 | ggml_vec_dot_q8_0_q8_0 | 31.51% |
| Q8_0 / decode 128 | ggml_vec_dot_q8_0_q8_0 | 93.09% |

All sampled tinyBLAS symbols together account for about 93.1% and 92.8% of the
two prompt profiles. That group also includes floating/half matrix kernels;
it is not all quantized dot-product work. Prompt processing reaches a different
tiled path from the named row-dot functions that dominate decoding. Improving
one row-dot function therefore cannot be assumed to accelerate both phases.

The Q4_0 file contains one Q8_0 tensor, **output.weight**, alongside 169 Q4_0 and
121 F32 tensors. The Q8_0 file has 170 Q8_0 and 121 F32 tensors. In the pinned
Qwen2 graph, `build_lora_mm(model.output, ...)` computes the output projection
(`source/src/models/qwen2.cpp:145`). This inventory/graph evidence explains why
the Q8_0 path is structurally relevant to the Q4_0 model too, and is consistent
with the large sampled Q8_0 dot-product share. Without call graphs, we do not
attribute every Q8_0 sample uniquely to that caller.

Symbols containing rms_norm account for less than 0.6% in each profile, primarily
the fused RMSNorm×weights path. Those are only a few samples; they do not provide
precise RMSNorm timing. For this workload, RMSNorm is a weaker first end-to-end
optimization target than the matrix paths. It remains useful as a coverage and
learning investigation. Different models, contexts, builds and hardware may
change the priority.

## Implications for the research shortlist

1. Q4_0 and Q8_0 dot products have demonstrated workload relevance on this host's
   decode path. Q8_0 matters in both downloaded models, not only the Q8_0 file.
2. Prompt matrix multiplication deserves a separate dispatch investigation;
   the observed tinyBLAS implementation is x86-specific. Verify what the RVV
   build actually selects before proposing a port or optimization.
3. Retain the IQ4_NL isolated study, but do not claim inference relevance from
   these downloads: neither contains IQ4_NL tensors.
4. Keep microbenchmarks, whole-operation tests and inference measurements. The
   earlier small 12-thread operation profiles mostly sampled OpenMP runtime
   work; these pinned one-thread model profiles expose computation instead.
5. Do not infer cache misses, bandwidth limits or instruction latencies from
   CPU-clock hotspots alone. Those require supporting measurements/modeling.

## Raw evidence and verification

The [committed evidence snapshot](../../evidence/host-2026-10-29/README.md)
contains timing rows, inventories, summaries and compact reports for teammates.
The links below point to the original Git-ignored local bundles and are available
only on the run owner's machine or in an explicitly shared raw archive.

- [Complete inference manifest](../../results/inference/20261029T175905Z-337re8bq/inference.json)
- [126 unprofiled timing rows](../../results/inference/20261029T175905Z-337re8bq/timings.csv)
- [Q4_0 tensor inventory](../../results/inference/20261029T175905Z-337re8bq/model-q4_0.json)
- [Q8_0 tensor inventory](../../results/inference/20261029T175905Z-337re8bq/model-q8_0.json)
- [Q4_0 prompt profile](../../results/inference/20261029T175905Z-337re8bq/q4_0/pp512/profile/report.txt)
- [Q4_0 decode profile](../../results/inference/20261029T175905Z-337re8bq/q4_0/tg128/profile/report.txt)
- [Q8_0 prompt profile](../../results/inference/20261029T175905Z-337re8bq/q8_0/pp512/profile/report.txt)
- [Q8_0 decode profile](../../results/inference/20261029T175905Z-337re8bq/q8_0/tg128/profile/report.txt)

All six benchmark configurations and four profiles passed result/settings
validation. Final checks confirmed model, binary and source hashes unchanged.
All 20 Python tooling tests passed, including a regression check for the local
inspect.py/std-library import collision encountered during metadata setup.
The earlier failed metadata-only attempt is retained as failed and is not part
of these results. No optimization patch was applied to the measured baseline.
