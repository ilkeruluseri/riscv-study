# RISC-V and RVV Programming Exercises

This workbook builds from basic cross-compilation and bit manipulation to a miniature version of a quantized llama.cpp RVV kernel.

Work through the exercises in order. Exercises 0-11 should be completed independently by every team member. Compare solutions only after each person has a working implementation they can explain.

## Ground rules

For every exercise:

1. Write a scalar reference implementation when applicable.
2. Generate deterministic test inputs.
3. Check expected output automatically.
4. Test awkward sizes such as `0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33`.
5. Compile with warnings enabled.
6. Inspect relevant assembly.
7. Be able to explain every line before continuing.

Recommended warnings:

```sh
-Wall -Wextra -Wpedantic -Werror
```

Compile an RVV exercise:

```sh
riscv64-linux-gnu-gcc \
  -O2 \
  -Wall -Wextra -Wpedantic \
  -march=rv64gcv \
  -mabi=lp64d \
  exercise.c \
  -o exercise
```

Run with VLEN=128:

```sh
qemu-riscv64 \
  -L /usr/riscv64-linux-gnu \
  -cpu max,vlen=128,elen=64,vext_spec=v1.0 \
  ./exercise
```

Run with VLEN=256:

```sh
qemu-riscv64 \
  -L /usr/riscv64-linux-gnu \
  -cpu max,vlen=256,elen=64,vext_spec=v1.0 \
  ./exercise
```

Generate assembly:

```sh
riscv64-linux-gnu-gcc \
  -O2 -march=rv64gcv -mabi=lp64d \
  -S exercise.c \
  -o exercise.s
```

Inspect a binary:

```sh
riscv64-linux-gnu-objdump -d -C exercise | less
```

## Progress

- [ ] Exercise 0: Verify the toolchain
- [ ] Exercise 1: Scalar array addition
- [ ] Exercise 2: Pack and unpack nibbles
- [ ] Exercise 3: Signed four-bit values
- [ ] Exercise 4: Scalar dot product
- [ ] Exercise 5: Dependency chains and unrolling
- [ ] Exercise 6: A fake vector machine
- [ ] Exercise 7: First RVV program
- [ ] Exercise 8: Observe VL directly
- [ ] Exercise 9: Scalar-vector multiplication
- [ ] Exercise 10: RVV reduction
- [ ] Exercise 11: RVV dot product
- [ ] Exercise 12: Vectorized nibble extraction
- [ ] Exercise 13: Vector lookup-table decoding
- [ ] Exercise 14: Scalar packed-Q4 by Q8 dot product
- [ ] Exercise 15: RVV packed-Q4 by Q8 dot product
- [ ] Exercise 16: Process two blocks per iteration
- [ ] Exercise 17: LMUL experiment
- [ ] Exercise 18: Differential test harness
- [ ] Final exercise: Trace the real llama.cpp kernel

## Exercise 0: Verify the toolchain

Write a program that prints:

```text
Hello from RISC-V
```

Cross-compile it and run it under QEMU. Verify the binary with `file` and `objdump`.

Done when:

- `file` identifies it as a RISC-V ELF.
- QEMU runs it.
- You can find `main` in the disassembly.

Concepts: cross-compilation, ELF binaries, emulation, disassembly.

## Exercise 1: Scalar array addition

Implement:

```c
void add_i32(const int32_t * a, const int32_t * b, int32_t * result, size_t n);
```

It should calculate:

```text
result[i] = a[i] + b[i]
```

Test empty arrays, one element, non-power-of-two lengths, negative values, and safe values near the integer limits.

Compile at `-O0` and `-O2`, then compare the assembly.

Concepts: loads, stores, pointer arithmetic, branches, and compiler optimization.

## Exercise 2: Pack and unpack nibbles

Implement:

```c
uint8_t pack_nibbles(uint8_t low, uint8_t high);
uint8_t unpack_low(uint8_t packed);
uint8_t unpack_high(uint8_t packed);
```

Store two four-bit values in one byte. Add exhaustive tests for all 256 valid `(low, high)` combinations.

Done when:

```text
unpack_low(pack_nibbles(a, b)) == a
unpack_high(pack_nibbles(a, b)) == b
```

for every valid pair.

Concepts: masks, shifts, packed data, and signedness.

Stretch: define and test behavior for inputs greater than 15.

## Exercise 3: Signed four-bit values

Define a mapping between a four-bit code and a signed value, for example:

```text
0x0 ->  0
0x1 ->  1
...
0x7 ->  7
0x8 -> -8
...
0xF -> -1
```

Implement:

```c
int8_t decode_i4(uint8_t nibble);
```

First implement it without a lookup table. Then implement a second version using a 16-element lookup table. Confirm both versions agree for all possible inputs.

Concepts: sign extension, encodings, represented values, and lookup tables.

## Exercise 4: Scalar dot product

Implement:

```c
int32_t dot_i8_scalar(const int8_t * a, const int8_t * b, size_t n);
```

Calculate the sum of `a[i] * b[i]` using an `int32_t` accumulator.

Determine the largest possible absolute result for 32 elements in the full signed 8-bit range.

Concepts: reductions, accumulation, intermediate widths, and overflow analysis.

## Exercise 5: Dependency chains and unrolling

Implement three scalar dot products:

1. One accumulator
2. Two accumulators
3. Four accumulators

Handle remaining elements correctly when the input size is not divisible by the unroll factor. Compare the generated assembly.

Answer:

- Why might several accumulators help?
- What tail condition did unrolling introduce?
- What happens for lengths 1, 2, and 3 in the four-accumulator version?

Concepts: dependency chains, instruction-level parallelism, unrolling, and loop tails.

## Exercise 6: A fake vector machine

Simulate a four-lane vector register:

```c
struct vec4_i32 {
    int32_t lane[4];
};
```

Implement load, addition, and store operations for this type. Use them to add arrays four elements at a time, including lengths not divisible by four.

This exercise is conceptual, not a performance optimization.

Concepts: lanes, vector operations, main loops, and scalar tails.

## Exercise 7: First RVV program

Rewrite Exercise 1 using RVV intrinsics. Find intrinsics for:

- Selecting VL for 32-bit elements with LMUL=1
- Loading signed 32-bit elements
- Vector-vector addition
- Storing signed 32-bit elements

Use a vector-length-agnostic loop:

```c
size_t offset = 0;

while (offset < n) {
    size_t vl = /* choose VL from n - offset */;

    /* load */
    /* add */
    /* store */

    offset += vl;
}
```

Do not hardcode the number of lanes.

Done when:

- It handles all awkward sizes.
- It produces identical output at VLEN=128 and VLEN=256.
- It matches the scalar reference.
- You can find vector configuration, loads, addition, and stores in the assembly.

## Exercise 8: Observe VL directly

Print the chosen `vl` on every vector-loop iteration. Run with an input length such as 37.

Record and explain the sequences for:

- VLEN=128, SEW=32, LMUL=1
- VLEN=256, SEW=32, LMUL=1
- VLEN=128, SEW=8, LMUL=1
- VLEN=256, SEW=8, LMUL=1

Predict each sequence before running the program.

Concepts: VLEN, SEW, LMUL, VL, VLMAX, and strip mining.

## Exercise 9: Scalar-vector multiplication

Implement with RVV:

```c
void multiply_scalar_i32(const int32_t * input, int32_t scalar, int32_t * output, size_t n);
```

Calculate `output[i] = input[i] * scalar`.

Compare the intrinsic naming for vector-vector and vector-scalar operations.

Concepts: operand forms such as `vv` and `vx`.

## Exercise 10: RVV reduction

Implement:

```c
int32_t sum_i32_rvv(const int32_t * input, size_t n);
```

For each vector chunk:

1. Load the elements.
2. Reduce them to one value.
3. Add that value to a scalar accumulator.
4. Continue with the next chunk.

Compare against a scalar reference using randomized inputs.

Concepts: reductions, scalar extraction, and accumulation across vector iterations.

## Exercise 11: RVV dot product

Implement:

```c
int32_t dot_i8_rvv(const int8_t * a, const int8_t * b, size_t n);
```

Use wider intermediate values than the 8-bit inputs. Determine the required product and accumulator widths before implementing it.

You will likely need 8-bit vector loads, widening multiplication, a widening reduction, and scalar extraction.

Test positive, negative, mixed-sign, and non-multiple lengths under both vector lengths.

Concepts: widening, overflow prevention, and vector reductions.

## Exercise 12: Vectorized nibble extraction

Given packed bytes, produce:

```text
low[i]  = packed[i] & 0x0f
high[i] = packed[i] >> 4
```

Implement scalar and RVV versions using unsigned byte loads, vector-scalar AND, logical shift, and stores.

Test every possible byte value.

Concepts: vectorized bit manipulation and Q4 unpacking.

## Exercise 13: Vector lookup-table decoding

Create a 16-element signed lookup table. Given nibble indices, implement:

```text
decoded[i] = values[index[i]]
```

Write scalar and RVV gather versions. Test every index and then repeated, reversed, and randomized index patterns.

Concepts: vector gather and non-linear quantized encodings.

## Exercise 14: Scalar packed-Q4 by Q8 dot product

Define a Q4 block containing:

- 16 packed bytes representing 32 Q4 values
- One floating-point scale

Define a Q8 block containing:

- 32 signed 8-bit values
- One floating-point scale

Implement:

```c
float dot_q4_q8_scalar(const q4_block * weights, const q8_block * activations);
```

The implementation should:

1. Unpack 32 Q4 codes.
2. Decode them.
3. Multiply them by the 32 Q8 values.
4. Accumulate into an integer.
5. Apply both scales.

Keep this reference implementation simple and obvious. Verify at least one result manually.

## Exercise 15: RVV packed-Q4 by Q8 dot product

Rewrite Exercise 14 using RVV:

1. Load 16 packed bytes.
2. Extract low and high nibbles.
3. Form or process 32 indices.
4. Decode with a vector gather.
5. Load 32 Q8 values.
6. Widen and multiply.
7. Reduce.
8. Apply both scales.

Compare against the scalar implementation over thousands of deterministic randomized cases at both VLEN settings.

Do not optimize for two blocks yet.

## Exercise 16: Process two blocks per iteration

Extend the previous implementation to multiple blocks:

```c
float dot_blocks(const q4_block * weights, const q8_block * activations, size_t block_count);
```

Process two blocks per iteration:

```c
for (; block + 1 < block_count; block += 2) {
    /* Process two blocks. */
}
```

First omit tail handling intentionally. Run with block counts `1, 2, 3, 4, 5, 7, 8` and record the failure pattern. Then fix it.

Explain:

- Why even counts pass
- Why odd counts fail
- Why one block produces no useful contribution
- Why vector-lane tail handling does not fix the block-loop tail
- Why tests using only large even dimensions miss the bug

This exercise recreates the structure of llama.cpp issue #29131.

## Exercise 17: LMUL experiment

Implement equivalent operations using two appropriate LMUL choices. For each version calculate:

```text
VLMAX = VLEN / SEW x LMUL
```

Inspect the assembly and record:

- Vector-register capacity
- Loop iteration count
- Additional moves
- Possible stack spills
- How widening changes the destination register group

Do not declare a performance winner from QEMU wall-clock timings.

Concepts: register grouping, capacity, widening, and register pressure.

## Exercise 18: Differential test harness

Build a reusable harness that:

1. Generates deterministic pseudo-random inputs.
2. Runs the scalar implementation.
3. Runs the RVV implementation.
4. Calculates absolute and relative error.
5. Prints the seed and failing input when results differ.
6. Tests multiple lengths and block counts.
7. Returns a nonzero status on failure.
8. Runs under both QEMU vector lengths.

Use targeted boundary cases before randomized cases. Random testing supplements boundary analysis; it does not replace it.

## Final exercise: Trace the real llama.cpp kernel

After Exercise 16, inspect these functions in:

`/home/ilker-pc/llama.cpp/ggml/src/ggml-cpu/arch/riscv/quants.c`

- `ggml_vec_dot_iq4_nl_q8_0_vl128`
- `ggml_vec_dot_iq4_nl_q8_0_vl256`
- `ggml_vec_dot_mxfp4_q8_0_vl128`
- `ggml_vec_dot_mxfp4_q8_0_vl256`
- Their public dispatch functions

For each section, write private notes answering:

- What is loaded?
- How many elements are active?
- What are SEW and LMUL?
- How are packed values decoded?
- Where does widening occur?
- Where does reduction occur?
- Where are scales applied?
- What happens when the block count is odd?
- Which behavior depends on VLEN?

Do not modify llama.cpp yet. First reproduce the issue and explain the intended behavior to another team member.

## Team workflow

Exercises 0-11 should be completed independently by all three members.

For later exercises:

- Person A implements the scalar reference.
- Person B implements the RVV version.
- Person C builds the differential tests and inspects assembly.

Rotate roles for the next exercise. A person who did not write a function should explain it line by line. If they cannot, the group is not finished.

## Reference material

- RISC-V V extension: https://docs.riscv.org/reference/isa/unpriv/v-st-ext
- RVV C intrinsic specification: https://github.com/riscv-non-isa/riscv-rvv-intrinsic-doc
- llama.cpp issue #29131: https://github.com/ggml-org/llama.cpp/issues/29131
- llama.cpp contributor rules: `/home/ilker-pc/llama.cpp/CONTRIBUTING.md`
- llama.cpp agent rules: `/home/ilker-pc/llama.cpp/AGENTS.md`
