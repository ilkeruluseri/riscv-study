# Trace and reproduce the odd-block bug

Observed on 2026-10-21 against local llama.cpp commit 31385c9ce.
This is a focused investigation, not a fix or a full llama.cpp build.
The llama.cpp checkout is left unchanged.

Run from the riscv workspace:

```sh
sh llama-bug-repro/run.sh
```

Exit status 1 means the dot products disagree. Both vector lengths run before
the script exits. The current checkout produces six mismatches per vector
length: odd block counts 1, 3, and 5 in each format. Even counts and zero pass.

## What runs

`extract.py` copies the four actual RVV functions, their two public dispatch
functions, and their two scalar references into `kernels.inc`. It does not
rewrite their bodies. The reproduction includes the original block definitions,
lookup tables, and floating-point conversion helpers from llama.cpp headers.
The CPU FP16 conversion macro uses the original software conversion helper
instead of requiring the full backend's initialization and lookup tables.

GCC 13 lacks `__riscv_vcreate_v_u8m1_u8m2`. A compatibility helper in `repro.c`
constructs the register group with two `vset` intrinsics. At VLEN=128 this places
the 16 low-nibble codes before the 16 high-nibble codes, just as the original
intrinsic does. The pair-loop logic is unchanged.

This executes real RVV instructions in QEMU. It checks these isolated kernels,
not model inference, native hardware performance, or the current upstream tree.

## Start with IQ4_NL at VLEN=128

Source: `/home/ilker-pc/llama.cpp/ggml/src/ggml-cpu/arch/riscv/quants.c`.

1. Line 5592: the public dispatcher selects the 128-bit kernel at line 5479.
2. Line 5485: `n` must be divisible by 32. One block is a valid input.
3. Line 5491: `nb = n / QK4_NL`, so `n=32` means one block.
4. Lines 5493-5494: `ib=0`, `sumf=0`.
5. Line 5501: `ib + 1 < nb` means `1 < 1`, which is false.
6. Line 5531: the function writes zero to `*s`.

For three blocks the loop processes indices 0 and 1, increments `ib` to 2,
then stops because `3 < 3` is false. Block 2 contributes nothing.
The generic reference at `ggml/src/ggml-cpu/quants.c:1254` iterates one block
at a time with `ib < nb` and visits every block.

## What the vector body calculates

Each IQ4_NL block contains 16 packed bytes representing 32 weights, plus a scale.
Each Q8_0 block contains 32 signed activation values, plus a scale.

- Load 16 packed weight bytes and 32 activation bytes.
- Extract 16 low nibbles and 16 high nibbles. Low nibbles represent positions
  0-15; high nibbles represent positions 16-31.
- Look up each nibble in the 16-entry signed IQ4_NL table using `vrgather`.
- Multiply the decoded weights by the activations, widening to 16 bits.
- Sum the 32 products with a widening reduction to a 32-bit accumulator.
- Multiply by the two block scales and add to the floating-point result.

The loop performs this work independently for two blocks per iteration.
At VLEN=256 the body instead works on two 16-element halves per block,
but the outer pair-loop has the same missing final block.
MXFP4 uses a different decoding table and scale encoding with the same loop.

## Hand calculation for the reproduction

IQ4_NL packed bytes are all `0x88`. Both nibbles index table entry 8, which
decodes to 1. Both block scales are 1. Every Q8 activation is 1.
One block therefore contributes `32 * 1 * 1 = 32`.

MXFP4 packed bytes are all `0x22`. Its table entry 2 is 2, and exponent 127
gives an effective scale of 0.5 because the table stores doubled values.
With Q8 scale 1 and activations 1, each block again contributes 32.

| Blocks | Elements | Hand calculation / generic | RVV, both formats and VLENs |
| --- | --- | --- | --- |
| 0 | 0 | 0 | 0 |
| 1 | 32 | 32 | 0 |
| 2 | 64 | 64 | 64 |
| 3 | 96 | 96 | 64 |
| 4 | 128 | 128 | 128 |
| 5 | 160 | 160 | 128 |

The missing contribution is always the last block in these cases. This is
an outer loop over quantization blocks; choosing a vector length for the
elements inside a block cannot make that outer loop visit the missing block.
