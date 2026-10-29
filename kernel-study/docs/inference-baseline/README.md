# Real-model inference baseline

This driver uses real model weights with llama-bench's synthetic token streams.
It measures prompt processing and decoding, excluding tokenizer/sampler work
from benchmark timings. It does not generate readable answers or evaluate model
accuracy. It is separate from the model-free operation suite.

The [completed host results](results.md) include six benchmark configurations,
126 raw timings and four real software-event profiles.

## Verified models

Repository: Qwen/Qwen2.5-0.5B-Instruct-GGUF, revision
`9217f5db79a29953eb74d5343926648285ec7e67`.

| File | Published and verified SHA-256 |
|---|---|
| qwen2.5-0.5b-instruct-q4_0.gguf | 7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed |
| qwen2.5-0.5b-instruct-q8_0.gguf | ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e |

The Q4_0 file has 169 Q4_0 tensors, one Q8_0 tensor and 121 F32 tensors. The Q8_0
file has 170 Q8_0 tensors and 121 F32 tensors. Both have 291 tensors and qwen2
architecture. The model name alone therefore does not describe every tensor's
execution path. The driver saves complete names/shapes/types, source URLs and
hash provenance. It hashes model files before and after collection rather than
copying weights into every result bundle.

Sources: [official Q4_0 file](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/blob/main/qwen2.5-0.5b-instruct-q4_0.gguf),
[official Q8_0 file](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/blob/main/qwen2.5-0.5b-instruct-q8_0.gguf).

## Reproduce

Prepare the unchanged full baseline with baseline.py first. Dependencies are
Python 3.12+, NumPy for the pinned gguf-py reader, taskset and a working perf
binary. No model download is performed by this driver.

```sh
PERF=/usr/lib/linux-tools-6.8.0-147/perf python3 kernel-study/inference_baseline.py
```

The defaults expect files under
`kernel-study/workspace/models/qwen2.5-0.5b-instruct/` and the existing operation
baseline workspace. Override with --models and --workspace. --cpu selects an
allowed CPU; the default is the first CPU in process affinity. --kind defaults
to host-practice. Native mode requires riscv64 and a build for the board.

## Fixed settings

- Unmodified source revision 31385c9cebf9e5271a38e14c26e5df6dd93718b1, optimized
  static CPU build with symbols, native CPU tuning, BLAS and CPU repacking off.
- One inference thread, taskset affinity to one CPU, thread-pool polling zero.
- CPU inference: GPU layers zero, KV and operation offloading disabled.
- Batch and microbatch 128, F16 key/value cache, flash attention off, repacking
  off, mmap loading and lazy loading off. No context prefill depth.
- Warmup enabled using upstream behavior: full prompt warmup for prompt tests;
  one decoded token for generation tests. KV state clears between repetitions.
- Separate unprofiled pp128, pp512 and tg128 runs, 21 repetitions each for each
  model: 126 raw internal timing samples.
- Separate cpu-clock:u profiles at 99 Hz for pp512 and tg128, five repetitions
  inside each of four processes. No call graphs or hardware counters.

The choices make an explicit research baseline; they are not production-default
settings. Prompt processing and token generation are different workloads. The
generation test starts at depth zero and grows to 128 tokens; it is not decode
at a fixed long context. Upstream samples synthetic token IDs, not generated
language. Its RNG behavior belongs to the pinned implementation.

## Outputs and interpretation

Each run prints its directory under `kernel-study/results/inference/`:

- inference.json: source/build identity, CPU selection, descriptive benchmark
  rates and profile summaries with links to raw captures.
- inference-build.json: llama-bench binary hash and configuration hash.
- model-q4_0.json / model-q8_0.json: file identity and complete tensor inventories.
- timings.csv: one row per unprofiled internal repetition, labeled by model,
  phase and kind. Profiled durations never enter this table.
- MODEL/PHASE/benchmark: command/environment provenance and raw llama-bench JSON.
- MODEL/PHASE/profile: raw perf.data, JSON output, reports and sample listings.

Rates use tokens divided by each internal duration, and summaries retain the
median and range. These are baseline descriptors, not candidate speedups or
statistical significance. Whole-process elapsed_ns includes startup/loading;
internal samples_ns does not. Profiles include loading, warmup, graph execution,
and all inherited threads. Do not interpret initialization hotspots as timed
inference costs. Symbol self-samples show where CPU time landed, not causal
call chains or precise instruction latency. Verify losses and sample counts.

The driver validates expected file hashes, one-thread CPU settings, phase and
repetition counts, positive finite times, and unchanged sources/models/binary
at completion. A completed inference benchmark proves successful evaluation,
not mathematical correctness or model quality. IQ4_NL is not present in these
two files; that model quantization needs a separate prepared artifact.
