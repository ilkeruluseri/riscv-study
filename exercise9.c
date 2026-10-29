#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <riscv_vector.h>

void multiply_scalar_i32(const int32_t *input,
                         int32_t scalar,
                         int32_t *output,
                         size_t n) {
    /* TODO: implement scalar-vector multiplication with RVV intrinsics. */
    size_t offset = 0;
    while (offset < n) {
        size_t remaining = n - offset;
        size_t vl = __riscv_vsetvl_e32m1(remaining);

        vint32m1_t vector = __riscv_vle32_v_i32m1(input + offset, vl);
        vint32m1_t product = __riscv_vmul_vx_i32m1(vector, scalar, vl);

        __riscv_vse32_v_i32m1(output + offset, product, vl);
        offset += vl;
    }
}

static void multiply_scalar_i32_reference(const int32_t *input,
                                          int32_t scalar,
                                          int32_t *output,
                                          size_t n) {
    for (size_t i = 0; i < n; i++) {
        output[i] = input[i] * scalar;
    }
}

static int check_case(size_t n, int32_t scalar) {
    enum { CAPACITY = 259 };
    static const int32_t guard = INT32_C(0x55555555);
    int32_t input[CAPACITY];
    int32_t expected[CAPACITY];
    int32_t storage[CAPACITY + 2];
    int32_t *const actual = &storage[1];

    for (size_t i = 0; i < CAPACITY; i++) {
        input[i] = (int32_t) ((i * 97 + 31) % 100001) - 50000;
        expected[i] = guard;
        actual[i] = guard;
    }
    storage[0] = guard;
    storage[CAPACITY + 1] = guard;

    multiply_scalar_i32_reference(input, scalar, expected, n);
    multiply_scalar_i32(input, scalar, actual, n);

    for (size_t i = 0; i < n; i++) {
        if (actual[i] != expected[i]) {
            fprintf(stderr,
                    "n=%zu, scalar=%" PRId32 ", index=%zu: "
                    "expected %" PRId32 ", got %" PRId32 "\n",
                    n,
                    scalar,
                    i,
                    expected[i],
                    actual[i]);
            return 1;
        }
    }

    for (size_t i = n; i < CAPACITY; i++) {
        if (actual[i] != guard) {
            fprintf(stderr,
                    "n=%zu, scalar=%" PRId32
                    ": output[%zu] was modified past the requested length\n",
                    n,
                    scalar,
                    i);
            return 1;
        }
    }

    if (storage[0] != guard || storage[CAPACITY + 1] != guard) {
        fprintf(stderr,
                "n=%zu, scalar=%" PRId32
                ": output was modified outside its allocation\n",
                n,
                scalar);
        return 1;
    }

    return 0;
}

static int check_boundary_values(void) {
    static const int32_t input[] = {
        INT32_MAX, INT32_MIN + 1, INT32_MAX - 10, INT32_MIN + 10,
    };
    static const int32_t expected[] = {
        -INT32_MAX, INT32_MAX, -(INT32_MAX - 10), INT32_MAX - 9,
    };
    int32_t actual[4] = { 0, 0, 0, 0 };

    multiply_scalar_i32(input, -1, actual, 4);

    for (size_t i = 0; i < sizeof(actual) / sizeof(actual[0]); i++) {
        if (actual[i] != expected[i]) {
            fprintf(stderr,
                    "boundary index=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                    i,
                    expected[i],
                    actual[i]);
            return 1;
        }
    }

    return 0;
}

int main(void) {
    static const size_t sizes[] = {
        0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33, 37, 127, 128, 129, 257,
    };
    static const int32_t scalars[] = { 0, 1, -1, 7, -11 };

    for (size_t scalar = 0;
         scalar < sizeof(scalars) / sizeof(scalars[0]);
         scalar++) {
        for (size_t size = 0; size < sizeof(sizes) / sizeof(sizes[0]); size++) {
            if (check_case(sizes[size], scalars[scalar]) != 0) {
                return 1;
            }
        }
    }

    if (check_boundary_values() != 0) {
        return 1;
    }

    puts("All RVV scalar-multiplication checks passed");
    return 0;
}
