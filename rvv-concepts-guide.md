# Concepts for the RISC-V and RVV exercises

Read this alongside [rvv-exercises.md](rvv-exercises.md). Each numbered section prepares you for the matching exercise. Start at 0 even if you have already written some of the programs: predicting an example and explaining its result is more useful than copying it.

The destination is a small quantized dot product: unpack compact weights, decode them, multiply by activations, reduce the products, and apply scales. Those operations appear inside real inference kernels.

Code blocks marked **complete example** are independent programs. Other C blocks illustrate a function or a fragment and assume the headers and surrounding variables described nearby. They are teaching examples, not exact llama.cpp implementations.

## Reading order

| Exercises | Main question |
| --- | --- |
| 0–3 | How does a C program run on RISC-V, and what do its bytes mean? |
| 4–6 | How do dot products, dependencies, and lanes work? |
| 7–11 | How do we express safe array arithmetic with RVV? |
| 12–15 | How do packed quantized values become a vector dot product? |
| 16–18 | How do we handle boundaries, explore alternatives, and verify results? |
| Final | How do we recognize these operations inside llama.cpp? |

## 0. Toolchain: from source code to execution

### Host, target, compiler, emulator

The **host** runs your development tools. The **target** executes the compiled program. Here, your host can be an x86-64 PC while the target is a 64-bit RISC-V Linux machine.

A cross-compiler runs on the host and produces target machine code. QEMU executes that target code through emulation. Neither step requires owning a RISC-V board.

The usual stages are:

```text
hello.c -> preprocessing -> compilation -> assembly -> object file -> linking -> executable
```

An object file contains machine instructions and information the linker uses to connect functions and data. An ELF executable also describes how the operating system should load the program.

**Complete example:** save as `hello-example.c` in a scratch directory.

```c
#include <stdio.h>

int main(void) {
    puts("Hello from RISC-V");
    return 0;
}
```

Compile and inspect it:

```sh
riscv64-linux-gnu-gcc -O2 -Wall -Wextra -Wpedantic -Werror \
    -march=rv64gcv -mabi=lp64d hello-example.c -o hello-example
file hello-example
riscv64-linux-gnu-objdump -d hello-example
```

The options express different choices:

| Option | Meaning |
| --- | --- |
| `-march=rv64gcv` | Allow RV64 instructions, the general-purpose `G` extension group, compressed instructions (`C`), and vectors (`V`) |
| `-mabi=lp64d` | Use the ABI with 64-bit pointers and `long`, and the double-precision hardware floating-point calling convention |
| `-O2` | Enable compiler optimizations |
| `-Wall -Wextra -Wpedantic -Werror` | Enable useful diagnostics and reject warnings |
| `-S` | Produce assembly text instead of a linked executable |
| `-c` | Produce an object file instead of linking |

An **ABI** is a contract between compiled components: argument passing, return values, register preservation, and data layout. An **ISA** defines available machine instructions. Libraries must be compatible with the selected ABI.

Run the executable:

```sh
qemu-riscv64 -L /usr/riscv64-linux-gnu \
    -cpu max,vlen=128,elen=64,vext_spec=v1.0 ./hello-example
```

`-L` points QEMU at the target dynamic loader and libraries. `vlen` selects the emulated vector-register width; `elen` is the maximum supported vector element width. Neither is the same as the CPU's 64-bit scalar register width.

If execution fails, distinguish a missing target loader/library from an unsupported instruction or a program bug.

**Before moving on:** explain why compiling with your PC's ordinary `gcc` does not produce the same executable, and locate `main` in the disassembly.

## 1. Arrays, pointers, and scalar arithmetic

### What an array access means

```c
#include <stddef.h>
#include <stdint.h>

void copy_i32(const int32_t *src, int32_t *dst, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        dst[i] = src[i];
    }
}
```

`src` points to the first element. `src[i]` means `*(src + i)`. Pointer arithmetic advances in elements: `src + 1` advances by `sizeof(int32_t)` bytes, normally four here.

`const int32_t *src` prevents modifying elements through `src`. It does not promise that no other pointer can modify them. `size_t` is the unsigned type used for object sizes and array lengths.

For valid nonoverlapping arrays, one iteration loads an element and stores it elsewhere. Exercise 1 adds a second load and an addition. State your overlap assumptions: exact in-place operation and partially overlapping ranges are different cases.

### C arithmetic has a contract

Signed overflow in C is undefined behavior. Do not use an overflowing scalar reference to judge the vector implementation.

```c
int32_t a = 1000000000;
int32_t b = 1000000000;
int64_t wide = (int64_t) a + b;
```

The cast occurs **before** addition. `(int64_t)(a + b)` would widen only after evaluating the potentially overflowing expression.

For an `int32_t` output, choose test inputs whose result fits, or explicitly design a different arithmetic contract. Vector integer addition wraps at its element width; that does not make an overflowing scalar C expression valid.

With `n == 0`, the loop accesses no elements. Test that boundary deliberately.

### Reading assembly

Compare `-O0` and `-O2`. Look for loads, stores, loop branches, and address updates. Registers hold both pointers and values; not every load in unoptimized code corresponds to a useful array load.

For a scalar baseline that should remain scalar during these exercises, add `-fno-tree-vectorize`. Otherwise the compiler may vectorize ordinary C loops itself.

**Before moving on:** explain the difference between an element index and a byte offset, and identify which test values would overflow your addition.

## 2. Bits, nibbles, masks, and shifts

A byte contains eight bits. A nibble contains four, giving 16 possible codes. Two nibbles fit in one byte.

```text
packed byte: 1010 0011 = 0xA3
high nibble: 1010      = 10
low nibble:       0011 = 3
```

Useful operations on unsigned values:

```c
uint8_t byte = UINT8_C(0xa3);
unsigned low = byte & 0x0fu;       // 3
unsigned high = byte >> 4;        // 10
unsigned combined = (high << 4) | low; // 163, or 0xa3
```

`&` keeps bits selected by a mask. `|` combines bits. `<<` moves bits toward higher positions. Right-shifting a nonnegative unsigned value fills the new high positions with zeros.

Small C integer types undergo **integer promotion** in expressions. On this target, a `uint8_t` promotes to `int`, which can represent every byte value. Using explicitly unsigned constants keeps the intended bit operations clear.

Keep packed storage unsigned. Signed right shifts introduce signedness questions that are unnecessary when extracting codes.

Define the packing function's input contract. Either require both inputs to be in `0..15`, or explicitly mask them. Quietly accepting invalid codes and rejecting them are different APIs.

There are only `16 * 16 = 256` valid nibble pairs. Test all of them; randomness adds no coverage to that finite input space.

**Before moving on:** predict the low and high nibbles of `0xF0`, `0x0F`, and `0x79` without running code.

## 3. Storage codes and signed values

A four-bit pattern does not determine its interpretation. The same code might represent an unsigned integer, a signed integer, or an entry in a nonlinear table.

For four-bit two's-complement values:

```text
code 0..7  represents  0..7
code 8..15 represents -8..-1
```

For a valid code, the mathematical decoding is:

```text
decoded = code             when code < 8
decoded = code - 16        otherwise
```

Do that subtraction in a signed type wide enough for the result. Avoid relying on an out-of-range unsigned-to-signed cast to express the encoding.

A table provides another representation of a mapping:

```c
static const int8_t signed_i4[16] = {
     0,  1,  2,  3,  4,  5,  6,  7,
    -8, -7, -6, -5, -4, -3, -2, -1,
};
```

For another quantization format, code 8 could map to 1 instead of -8. Never substitute a familiar signed-nibble mapping for a format's actual table.

This is also why casting a whole packed byte to `int8_t` does not decode either of its four-bit fields.

**Before moving on:** explain how code `0xF` can represent 15, -1, or a table-selected value, depending on the format.

## 4. Dot products, reductions, and overflow bounds

A dot product multiplies corresponding elements, then sums the products:

```text
a = [ 2, -3, 4 ]
b = [ 5,  6, 7 ]
dot(a,b) = 2*5 + (-3)*6 + 4*7 = 20
```

The sum is a **reduction**: many values become one value.

For signed bytes, each input is in `[-128, 127]`. The largest positive product is `(-128)*(-128) = 16384`; the most negative is `(-128)*127 = -16256`. Products fit in signed 16 bits, but a sum of many products may not.

For 32 elements:

```text
maximum absolute sum <= 32 * 16384 = 524288
```

A signed 32-bit accumulator comfortably holds this. For arbitrary `n`, an `int32_t` return type still needs an input bound. The conservative full-range guarantee is `n <= 131071`, since `131072 * 16384 = 2147483648` exceeds `INT32_MAX`.

Write down bounds before selecting types. A wider output does not repair products that have already overflowed at a narrower width.

```c
int32_t product = (int32_t) a[i] * (int32_t) b[i];
```

Here the product is explicitly evaluated at 32 bits. Ordinary scalar integer promotion also makes multiplication of two `int8_t` values safe on this target. Vector byte multiplication has different width semantics, which matters in exercise 11.

**Before moving on:** explain why 16 bits suffice for each byte product but not for the entire 32-element sum.

## 5. Dependencies, independent accumulators, and unrolling

A loop with one accumulator creates a chain:

```text
s1 = s0 + product0
s2 = s1 + product1
s3 = s2 + product2
```

Each addition depends on the preceding result. Independent accumulators can expose work the processor can schedule concurrently:

```text
even_sum accumulates products 0, 2, 4, ...
odd_sum  accumulates products 1, 3, 5, ...
result = even_sum + odd_sum
```

**Unrolling** puts multiple original iterations into one loop body. Unrolling alone does not necessarily remove the accumulation dependency; multiple accumulators change that dependency structure.

A general two-element loop shape is:

```c
size_t i = 0;
for (; n - i >= 2; i += 2) {
    /* Process i and i + 1. */
}
for (; i < n; ++i) {
    /* Process the remaining element. */
}
```

The invariant is `i <= n`, so `n - i` is safe. The first loop only runs when two elements remain. The second loop handles the tail. In a four-element version, lengths 1–3 skip the main loop completely.

More accumulators also require more live registers, code, and a final combination. The compiler and CPU may already hide the original dependency. Inspect and measure instead of assuming improvement.

Integer reassociation preserves exact results only within the relevant bounds. Floating-point addition is not associative: changing grouping can change rounding.

**Before moving on:** draw the accumulator dependencies and hand-trace the remaining-element loop for lengths 0–5.

## 6. A conceptual vector machine

A vector register can hold several elements. Each position is a **lane** in our conceptual model.

```text
a register: [10, 20, 30, 40]
b register: [ 1,  2,  3,  4]
addition:   [11, 22, 33, 44]
```

You can model an operation with a struct:

```c
struct vec4_i32 {
    int32_t lane[4];
};

struct vec4_i32 negate4(struct vec4_i32 input) {
    struct vec4_i32 result;
    for (size_t lane = 0; lane < 4; ++lane) {
        result.lane[lane] = -input.lane[lane];
    }
    return result;
}
```

Assume no input is `INT32_MIN`, whose negation cannot fit in `int32_t`.

Separate three actions: load array elements into a register, compute with registers, store results back to memory. A register is not the same thing as the original array.

A four-element load requires four valid elements. Reading beyond the array and later ignoring the extra values is still invalid.

This model explains dataflow. It does not specify how many physical execution units a real vector CPU has, or how many cycles an instruction takes.

**Before moving on:** explain why a ten-element array cannot safely use three unconditional four-element loads.

## 7. RVV types, intrinsics, and strip mining

An **intrinsic** is a compiler-supported C interface to an operation. Include `<riscv_vector.h>`. The compiler allocates registers and emits configuration instructions as needed.

An example type is `vint32m1_t`: signed 32-bit elements using register grouping `m1`. It is a scalable vector type, not an ordinary C array with a fixed lane count.

**Complete example:** the operation below adds a constant to an array. It gives you the loop structure for exercise 7 without implementing its two-array addition.

```c
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <riscv_vector.h>

static void add_constant(const int32_t *src, int32_t *dst,
                         size_t n, int32_t amount) {
    size_t offset = 0;
    while (offset < n) {
        size_t vl = __riscv_vsetvl_e32m1(n - offset);
        vint32m1_t x = __riscv_vle32_v_i32m1(src + offset, vl);
        vint32m1_t y = __riscv_vadd_vx_i32m1(x, amount, vl);
        __riscv_vse32_v_i32m1(dst + offset, y, vl);
        offset += vl;
    }
}

int main(void) {
    int32_t src[19];
    int32_t dst[19];
    for (size_t i = 0; i < 19; ++i) {
        src[i] = (int32_t) i - 9;
    }
    add_constant(src, dst, 19, 5);
    for (size_t i = 0; i < 19; ++i) {
        if (dst[i] != src[i] + 5) {
            return 1;
        }
    }
    puts("RVV add-constant example passed");
    return 0;
}
```

This is **strip mining**: process the array in chunks whose active length is selected at runtime. The important invariant is that the next iteration starts after exactly the elements just processed.

Read intrinsic names in pieces:

```text
__riscv_ vle32 _v_ i32m1
          load     result type
          32-bit elements

__riscv_ vadd _vx_ i32m1
          add  vector + scalar
```

The `vl` argument controls the active element count. It is not a byte count. Keep load, computation, and store counts consistent.

Default unmasked arithmetic generally leaves destination tail elements unspecified. Only store the active elements. Keeping a value alive across iterations with shrinking `vl` requires care if later computation reads the old tail; these examples avoid that pattern.

**Before moving on:** explain why advancing by a guessed lane count is wrong and why an empty input skips vector operations.

## 8. VLEN, SEW, LMUL, VLMAX, AVL, and VL

Keep these quantities distinct:

| Name | Meaning | Example |
| --- | --- | --- |
| VLEN | Bits in one architectural vector register | 128 |
| SEW | Selected element width in bits | 32 |
| LMUL | Register grouping multiplier | 1 |
| VLMAX | Maximum element count for this configuration | 4 |
| AVL | Application's requested element count | 37 remaining |
| VL | Active element count selected for the operation | At most 4 here |

```text
VLMAX = (VLEN / SEW) * LMUL
```

Some capacities at LMUL=1:

| VLEN | SEW=8 | SEW=16 | SEW=32 |
| --- | --- | --- | --- |
| 128 bits | 16 | 8 | 4 |
| 256 bits | 32 | 16 | 8 |

Do not assume that selecting VL always computes `min(AVL, VLMAX)`. For `VLMAX < AVL < 2*VLMAX`, RVV permits balanced choices between `ceil(AVL/2)` and VLMAX. If AVL fits, VL equals AVL; if AVL is at least twice VLMAX, VL equals VLMAX. The loop must use the returned value. See the [ISA specification's VL constraints](https://docs.riscv.org/reference/isa/v20260120/unpriv/v-st-ext.html).

For example, with 37 elements and VLMAX=32, a first chunk of 32 followed by 5 is legal, but 19 followed by 18 is also legal. Observe what QEMU chooses without treating that choice as a universal hardware rule.

Print `size_t` with `%zu`:

```c
printf("remaining=%zu, vl=%zu\n", n - offset, vl);
```

Remove printing before timing. Printing changes the workload dramatically.

**Before moving on:** calculate capacities yourself, then distinguish what a prediction requires from what the ISA permits.

## 9. Vector-vector and vector-scalar operations

Operand forms describe where inputs come from:

| Form | Meaning |
| --- | --- |
| `vv` | Vector and vector |
| `vx` | Vector and scalar integer register |
| `vi` | Vector and immediate encoded in an instruction |
| `vf` | Vector and scalar floating-point register |

For example, a signed 32-bit vector-scalar multiply is expressed as:

```c
vint32m1_t result = __riscv_vmul_vx_i32m1(input, factor, vl);
```

The intrinsic need not map one-to-one to a single final instruction in every context. The compiler may select immediate forms or optimize operations away.

Ordinary vector multiplication keeps the destination element width. For exercise 9, constrain inputs so the mathematical product fits signed 32 bits, matching a defined scalar C reference.

**Before moving on:** identify which operand varies by lane and which is shared by all active lanes.

## 10. Reduction and scalar extraction

Elementwise addition produces a vector; reduction produces one useful total.

For a chunk `[3, -1, 5]`, a sum reduction with a zero seed gives 7. The seed is an initial value, not another array element.

For a loaded `vint32m1_t x` and its active count `vl`:

```c
vint32m1_t seed = __riscv_vmv_v_x_i32m1(0, 1);
vint32m1_t reduced = __riscv_vredsum_vs_i32m1_i32m1(x, seed, vl);
int32_t chunk_sum = __riscv_vmv_x_s_i32m1_i32(reduced);
```

Only element zero of `seed` supplies the initial sum. The reduction puts the useful result in element zero of `reduced`. Scalar extraction retrieves that element; it does not sum the vector itself.

Maintain a scalar running total across chunks. Do not reset the overall total inside the chunk loop. Equally, do not put the old total into the seed and then add it again afterward.

`vredsum` does not widen. Both each chunk sum and the overall scalar sum must fit the intended arithmetic contract. For initial tests use small bounded values; consider an `int64_t` oracle when checking bounds.

**Before moving on:** hand-trace a seven-element input split into chunks of four and three, showing each seed, chunk result, and running total.

## 11. Widening multiplication and widening reduction

With vector arithmetic, multiplying two byte vectors into another byte vector loses high product bits. Widen **during** multiplication.

The intended types are:

```text
signed 8-bit inputs -> signed 16-bit products -> signed 32-bit sum
```

**Complete example:** this computes one chunk containing at most 16 elements. Its precondition is deliberately small; exercise 11 generalizes it to an entire array.

```c
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <riscv_vector.h>

static int32_t dot_small(const int8_t *a, const int8_t *b, size_t n) {
    if (n == 0) {
        return 0;
    }
    // Precondition: n <= 16 on the RVV 1.0 targets used here.
    size_t vl = __riscv_vsetvl_e8m1(n);
    vint8m1_t va = __riscv_vle8_v_i8m1(a, vl);
    vint8m1_t vb = __riscv_vle8_v_i8m1(b, vl);
    vint16m2_t products = __riscv_vwmul_vv_i16m2(va, vb, vl);
    vint32m1_t seed = __riscv_vmv_v_x_i32m1(0, 1);
    vint32m1_t total =
        __riscv_vwredsum_vs_i16m2_i32m1(products, seed, vl);
    return __riscv_vmv_x_s_i32m1_i32(total);
}

int main(void) {
    const int8_t a[] = {-128, -3, 4};
    const int8_t b[] = {-128, 6, 7};
    if (dot_small(a, b, 3) != 16394 || dot_small(a, b, 0) != 0) {
        return 1;
    }
    puts("RVV widening example passed");
    return 0;
}
```

Why `i16m2`? Doubling the element width while retaining the same number of products requires twice the register-group storage. `e8,m1` and `e16,m2` have equal element capacities.

The widening reduction is special: its destination holds a scalar reduction result in an `m1` vector. Do not apply the elementwise widening rule blindly to its result type.

When generalizing this example, iterate by the returned VL and bound the total sum as in exercise 4. Include products such as `127*127` and `(-128)*(-128)` to expose accidental byte-width multiplication.

**Before moving on:** annotate every intermediate with signedness, element width, grouping, and active count.

## 12. Vectorized packed-byte extraction

The scalar bit operations from exercise 2 apply independently to vector lanes:

```c
vuint8m1_t packed = __riscv_vle8_v_u8m1(src, vl);
vuint8m1_t low = __riscv_vand_vx_u8m1(packed, 15, vl);
vuint8m1_t high = __riscv_vsrl_vx_u8m1(packed, 4, vl);
```

Use logical right shift (`vsrl`) for unsigned codes. Arithmetic right shift (`vsra`) would replicate the sign bit and express a different operation.

Each input byte produces two codes. Loading 16 bytes yields 16 low codes and 16 high codes, representing 32 values. This is not a single 32-element vector yet.

Distinguish layout choices:

```text
interleaved: low0, high0, low1, high1, ...
split:       low0, low1, ..., low15, high0, high1, ..., high15
```

The same bytes can participate in either convention. Your format specifies which logical position each nibble represents. For the toy blocks below, we will use split ordering.

**Before moving on:** explain why byte count, code count, and vector active count cannot be used interchangeably.

## 13. Lookup-table decoding with register gather

Suppose codes index this illustrative nonlinear table:

```c
static const int8_t values[16] = {
    -20, -15, -11, -8, -6, -4, -2, -1,
      1,   2,   4,  6,  8, 11, 15, 20,
};
```

Codes `[0, 8, 15]` decode to `[-20, 1, 20]`. The codes are unsigned indices; the decoded values are signed numbers.

For `count` valid codes with `count <= 16`:

```c
size_t table_vl = __riscv_vsetvl_e8m1(16);
vint8m1_t table = __riscv_vle8_v_i8m1(values, table_vl);
size_t vl = __riscv_vsetvl_e8m1(count);
vuint8m1_t indices = __riscv_vle8_v_u8m1(codes, vl);
vint8m1_t decoded = __riscv_vrgather_vv_i8m1(table, indices, vl);
```

`vrgather` selects elements from a vector register. It is different from an indexed memory load. Load all 16 table entries first, even when the output chunk has fewer than 16 elements. A short output can still contain code 15 and need table entry 15.

The loaded table is a separate source operand, so a later short output operation does not itself overwrite it. Keep every index in `0..15`: unused source elements beyond the initialized table must not become lookup inputs. The [ISA gather section](https://docs.riscv.org/reference/isa/v20260120/unpriv/v-st-ext.html#_vector_register_gather_instructions) describes register indexing, including indices outside the active output range.

For a general output array, keep this table value and loop over chunks of indices. Test short arrays containing large valid indices, repeated indices, reversed order, and all 16 codes.

**Before moving on:** explain why loading only three table entries is wrong when decoding three codes `[0, 8, 15]`.

## 14. Quantized blocks and scale factors

Quantization represents real values with compact codes and associated metadata. For our toy model:

```text
weight[i]     approximately weight_scale * decoded_q4[i]
activation[i] approximately activation_scale * q8[i]
```

Define the storage format explicitly:

```c
typedef struct {
    uint8_t packed[16];
    float scale;
} q4_block;

typedef struct {
    int8_t values[32];
    float scale;
} q8_block;
```

These are teaching structures. Real formats may use half-precision scales, exponent encodings, sub-block scales, or different tables. Do not cast real llama.cpp blocks to these types.

For split nibble ordering:

```text
code[i]      = packed[i] & 15     for i=0..15
code[i + 16] = packed[i] >> 4     for i=0..15
```

Decide whether to use exercise 3's signed mapping or exercise 13's table, and use the same mapping in every implementation and manual calculation. For the following example, use the table from section 13.

The block dot product is:

```text
integer_sum = sum(decoded_q4[i] * q8[i]), i=0..31
result = (weight_scale * activation_scale) * integer_sum
```

Both scales are constant inside the block, so they can be factored outside its integer sum. That is what makes this computation attractive: most work uses compact integers.

Manual case:

```text
all packed bytes = 0x88 -> every decoded weight = table[8] = 1
all q8 values = 2
weight scale = 0.5
activation scale = 0.25
integer sum = 32 * 1 * 2 = 64
result = 0.5 * 0.25 * 64 = 8
```

For multiple blocks with different scales, scale each block's sum before combining it with other blocks. One shared scale cannot generally be applied to the grand integer total.

This reference computes exactly what the quantized representation means, subject to float rounding. It does not reconstruct the original unquantized model exactly; quantization already introduced approximation.

**Before moving on:** make a second hand calculation with negative values and different low and high nibbles.

## 15. Combining the operations into an RVV kernel

Build the one-block kernel as a sequence of independently understandable transformations:

```text
16 packed bytes
    -> 16 low codes and 16 high codes
    -> 16 decoded low values and 16 decoded high values
    -> pair with activations [0..15] and [16..31]
    -> widened products
    -> integer reductions
    -> combine integer sums
    -> multiply by the block scales
```

Start by processing the halves separately. This avoids needing a vector concatenation helper and makes the logical ordering visible. Optimize representation only after this path is correct.

At a half-block offset `i`, the relevant addresses are:

```text
packed bytes:         weights->packed + i
low-half activations: activations->values + i
high-half activations:activations->values + 16 + i
```

The requested element count must not exceed the remaining half length. A VLEN=256 register can hold 32 byte elements, but the packed array still has only 16 bytes. Hardware capacity is not permission to read extra memory.

The exercise is to connect the already introduced operations, not to discover a new mathematical formula. Keep the scalar reference structurally simple and use a separate manual case to check that both versions implement the intended layout.

Debugging becomes easier if you compare intermediates in order: extracted codes, decoded weights, products, integer sums, then scaled output. A wrong float result can originate in a nibble ordering error long before floating-point arithmetic happens.

**Before moving on:** explain the source address and logical element number for every lane in the two halves.

## 16. Block loops have their own tails

There are now two different boundaries:

1. Elements inside a vector chunk, handled through VL.
2. Blocks inside an unrolled outer loop, handled through outer-loop control.

For three blocks, a two-block loop visits:

```text
iteration 1: blocks 0 and 1
remainder:   block 2
```

Adjusting VL inside blocks 0 and 1 cannot make the outer loop visit block 2.

A general shape is:

```c
size_t block = 0;
for (; block_count - block >= 2; block += 2) {
    /* Compute two complete, separately scaled block contributions. */
}
if (block < block_count) {
    /* Compute one complete block contribution. */
}
```

For one block the pair loop executes zero times. For zero blocks, neither path should dereference an input pointer. For odd counts, exactly one block remains.

Use distinct block contents and scales in addition to identical blocks. Identical inputs expose dropped contributions, but varied inputs are better at exposing accidental duplication or mismatched weight/activation pointers.

**Before moving on:** write down visited block indices for counts 0–8 before running the tests.

## 17. LMUL, register capacity, and register pressure

LMUL changes the storage available to a vector value. Increasing it can process more elements per operation, but also occupies more architectural registers.

For VLEN=128:

| Configuration | Capacity |
| --- | --- |
| `e8,m1` | 16 byte elements |
| `e8,m2` | 32 byte elements |
| `e16,m2` | 16 halfword elements |
| `e16,m4` | 32 halfword elements |

The widening chains preserve element counts:

```text
8-bit m1 inputs -> 16-bit m2 products
8-bit m2 inputs -> 16-bit m4 products
```

Larger groups can reduce loop overhead while increasing **register pressure**: how many values need registers at the same time. The compiler may need extra moves or spill values to the stack.

**Liveness** matters. A table, two inputs, unpacked codes, decoded weights, products, and accumulators all compete for storage if they remain live together. Reusing a value sooner can matter as much as changing LMUL.

Fractional groups such as `mf2` also exist. For example, `e8,mf2` and `e16,m1` have equal capacity. Learn the basic widening chain before exploring them.

Do not infer physical execution throughput from VLEN or LMUL. A CPU can execute a wide architectural operation over multiple cycles.

Inspect assembly for loop counts, configuration changes, extra moves, and stack traffic. Confirm apparent spills are vector values rather than ordinary scalar stack use. Then measure on native hardware when available.

**Before moving on:** explain a reason larger LMUL might help and a reason it might hurt on the same processor.

## 18. Differential testing and reproducible failures

A **differential test** compares two implementations on the same input. It is most convincing when they do not share the same tricky decoding helper: otherwise one mistake can appear in both.

Use three checks where possible:

```text
hand calculation -> simple scalar implementation -> RVV implementation
```

### Deterministic data generation

A fixed seed makes random inputs reproducible. This generator is sufficient for exercise data, not cryptography:

```c
static uint32_t next_random(uint32_t *state) {
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;
    return x;
}
```

Start from a nonzero seed. Generate signed byte test values without relying on an out-of-range cast:

```c
int value = (int) (next_random(&state) & 255u) - 128;
int8_t sample = (int8_t) value;
```

Generate packed bytes from `0..255`, and initially use bounded finite scales. Preserve the original seed and case index; printing only the mutated generator state may make a failure harder to replay.

### Integer and floating-point comparisons

For defined integer arithmetic, demand exact equality. For floats, define a tolerance based on the computation and its magnitude:

```c
#include <math.h>

static int close_finite(float actual, float expected,
                        float atol, float rtol) {
    if (!isfinite(actual) || !isfinite(expected)) {
        return 0;
    }
    double error = fabs((double) actual - (double) expected);
    return error <= (double) atol + (double) rtol * fabs((double) expected);
}
```

Assume nonnegative tolerances. This helper intentionally rejects nonfinite results because our initial input contract expects finite outputs. If nonfinite values are part of a later API, define their comparison separately.

Absolute tolerance protects near-zero comparisons. Relative tolerance scales with the reference magnitude. Relative error alone is undefined at zero and can be misleading near cancellation. Do not enlarge tolerances until a broken kernel passes.

Print the actual absolute error and relative error when meaningful. For an expected zero, report relative error as unavailable and retain the absolute error.

### Targeted cases before random cases

| Case | Intended failure to expose |
| --- | --- |
| Empty input | Invalid unconditional access or incorrect identity |
| One element / one block | Main loop that never runs |
| Around VLMAX | Chunk transitions and tails |
| Odd block counts | Missing outer remainder |
| Distinct low/high nibble patterns | Wrong layout or activation pairing |
| Largest products and mixed signs | Narrow intermediates or wrong signedness |
| Different block scales | Applying one scale to several blocks |
| Short lookup input containing code 15 | Incomplete table initialization |

Put known guard values beyond output ranges and verify they stay unchanged. Guards detect some overwrites; they do not establish that no out-of-bounds reads occurred.

On failure, report the implementation, seed, case index, input length, block count, input bytes, scales, expected output, and actual output. Return a nonzero exit status. Run the same suite under both QEMU VLEN settings.

**Before moving on:** demonstrate that one deliberately introduced mistake causes a reproducible test failure, then remove it.

## Final exercise: reading a real llama.cpp kernel

Use [the saved investigation](llama-bug-repro/README.md) as a local starting point. Its line numbers describe a particular checkout and can become stale.

Choose one function and annotate it in your own notes:

| Code region | What to establish |
| --- | --- |
| Public dispatcher | Which hardware/shape conditions select this implementation? |
| Block definition | What does each byte and scale encode? |
| Loads | Which logical values and how many valid bytes are read? |
| Unpacking | Which logical positions do low and high nibbles represent? |
| Table lookup | What does each code actually mean? |
| Multiplication | What are input and product widths and signedness? |
| Reduction | What is being summed and what is its bound? |
| Scaling | Which scale belongs to which sum? |
| Outer loop | Which block indices are visited? |
| Return | How are block contributions combined? |

Trace one small valid input by hand. Compare your explanation against the scalar reference. The toy format teaches the operations; the real block definitions determine the actual semantics.

Then trace one caller upward. A locally impressive kernel is only useful to a workload that actually selects it. Find which operation, tensor types, and input shapes reach it.

You are ready to propose a change when you can explain the existing path and one specific hypothesis, such as: “this repeated setup appears in the hot loop; moving it may reduce instructions without increasing spills.” You still need measurements to establish that hypothesis.

## After the exercises: turning understanding into performance evidence

Keep correctness and timing as separate activities. QEMU is useful for execution checks; its wall-clock time does not establish a native RVV performance improvement.

On native hardware, compare the original and modified implementation with identical compiler options and workloads. Keep the source revisions, CPU details, runtime settings, raw samples, and exact commands.

Measure the kernel, its containing tensor operation, and actual inference. A model-level speedup is limited by how much execution time the changed path accounts for. For example, if a kernel accounts for 20% of runtime and becomes twice as fast, the ideal total runtime becomes `0.8 + 0.2/2 = 0.9`, giving about `1.11x` overall speedup.

Use repeated, interleaved before/after runs, warmups, consistent affinity, and controlled competing load and thermals. Report variation and regressions as well as improvements. Do not select only the fastest run.

`llama-bench` separates prompt processing and token generation and can retain individual timing samples in JSON. Its measurements exclude tokenization and sampling. Consult the [benchmark documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/llama-bench/README.md) for the checked-out version's options.

Before preparing an upstream contribution, reread [CONTRIBUTING.md](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md) and [AGENTS.md](https://github.com/ggml-org/llama.cpp/blob/master/AGENTS.md). You must understand the design, perform the review and required validation, disclose meaningful AI assistance, and write your own public submission and responses.

## How to study each section

1. Read the concepts and predict the examples' results.
2. Implement the corresponding exercise without opening your previous solution.
3. Check a hand-calculated case and the boundary cases.
4. Explain the generated assembly at the level of loads, computation, stores, and loops.
5. Explain the implementation to a teammate who did not write it.

If a section is difficult, return to its prerequisites. Widening builds on integer bounds; quantized dot products build on nibble layout and decoding; optimization builds on understanding and a trustworthy comparison.

## Technical references and local compatibility

- [RISC-V Vector ISA, version 1.0](https://docs.riscv.org/reference/isa/v20260120/unpriv/v-st-ext.html): architectural behavior, especially VL selection, widening, reductions, and gather.
- [RVV intrinsic specification](https://github.com/riscv-non-isa/riscv-rvv-intrinsic-doc/blob/main/doc/rvv-intrinsic-spec.adoc): C interfaces, vector types, naming, and policies.
- [Intrinsic repository compatibility notes](https://github.com/riscv-non-isa/riscv-rvv-intrinsic-doc): compiler/API version distinctions. GCC 13 implements an older intrinsic API than GCC 14; ISA version and intrinsic API version are separate concepts.

This workspace currently provides GCC 13.3 and QEMU 8.2.2. The two complete RVV examples above use interfaces available here. Newer documentation may show additional helpers not present in this compiler. Check a missing intrinsic against the installed compiler's API before treating it as a misunderstanding of RVV.
