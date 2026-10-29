# Selected inference workload

Use Qwen2.5-0.5B-Instruct as the initial small integration model. Its published
configuration has hidden width 896, intermediate width 4864, 24 layers and
RMSNorm epsilon 1e-6. This motivates width 896 in the model-free suite; its
64-row matrix tests are bounded synthetic cases, not complete model layers.

Sources checked 2026-10-29:
[model card](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct),
[configuration](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/blob/main/config.json),
[official GGUF repository](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF).

The official Q4_0 and Q8_0 files have now been downloaded and verified against
their published SHA-256 hashes at repository revision
`9217f5db79a29953eb74d5343926648285ec7e67`. The
[inference baseline guide](../inference-baseline/README.md) records their hashes,
tensor inventories and exact measurement settings. The vocabulary-only GGUF
files in the checkout are not inference models.

The initial measurements use Q8_0 and Q4_0 variants of the same model. An IQ4_NL
model artifact remains a separate follow-up; it is not in these downloads. Keep
conversion flags, tensor mixtures and quantization provenance for any later
artifact. A filename/quantization label does not prove the target kernel is
selected. Profile actual dispatch and runtime share first.

Initial CPU-only settings: one thread, GPU layers zero, prompt processing at
128 and 512 tokens separately from generation at 128 tokens, batch 128 and
microbatch 128, default warmup enabled, 21 raw repetitions in JSON. Set other
offload/backend options explicitly for the pinned binary; save its help/build
settings. Test a realistic board thread count separately after the one-thread
baseline. This small model is a starting workload; larger models/context and
streaming effects need later measurements.

The full baseline build includes llama-bench, so no inference-tool build step is
needed once weights/provenance are available. Its results would not establish
model accuracy; candidate numerical changes require separate quality checks.
