#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <riscv_vector.h>

int32_t sum_i32_rvv(const int32_t *input, size_t n) {
    size_t offset = 0;
    int32_t sum = 0;
    while (offset < n) {
        size_t remaining = n - offset;
        size_t vl = __riscv_vsetvl_e32m1(remaining);

        vint32m1_t values = __riscv_vle32_v_i32m1(input + offset, vl);
        vint32m1_t zero = __riscv_vmv_v_x_i32m1(0, vl);
        vint32m1_t reduced = __riscv_vredsum_vs_i32m1_i32m1(values, zero, vl);

        int32_t chunk_sum = __riscv_vmv_x_s_i32m1_i32(reduced);
        sum += chunk_sum;
        offset += vl;
    }
    
    return sum;
}

static int32_t sum_i32_scalar(const int32_t *input, size_t n) {
    int32_t sum = 0;

    for (size_t i = 0; i < n; i++) {
        sum += input[i];
    }

    return sum;
}

static uint32_t next_random(uint32_t *state) {
    uint32_t value = *state;

    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

static int check_random_inputs(void) {
    enum { CAPACITY = 4097 };
    static const size_t sizes[] = {
        0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33, 37,
        127, 128, 129, 255, 256, 257, 511, 512, 513, 1023, 4097,
    };
    int32_t input[CAPACITY];
    uint32_t random_state = UINT32_C(0x8e51c2a7);

    for (size_t i = 0; i < CAPACITY; i++) {
        input[i] = (int32_t) (next_random(&random_state) % 2001) - 1000;
    }

    for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
        const size_t n = sizes[test];
        const int32_t expected = sum_i32_scalar(input, n);
        const int32_t actual = sum_i32_rvv(input, n);

        if (actual != expected) {
            fprintf(stderr,
                    "n=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                    n,
                    expected,
                    actual);
            return 1;
        }
    }

    return 0;
}

static int check_boundary_values(void) {
    static const int32_t inputs[][3] = {
        { INT32_MAX, 0, 0 },
        { INT32_MIN, 0, 0 },
        { INT32_MAX, -1, -INT32_MAX },
        { INT32_MIN, 1, INT32_MAX },
    };
    static const size_t sizes[] = { 1, 1, 3, 3 };
    static const int32_t expected[] = { INT32_MAX, INT32_MIN, -1, 0 };

    for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
        const int32_t actual = sum_i32_rvv(inputs[test], sizes[test]);

        if (actual != expected[test]) {
            fprintf(stderr,
                    "boundary test %zu: expected %" PRId32 ", got %" PRId32 "\n",
                    test,
                    expected[test],
                    actual);
            return 1;
        }
    }

    return 0;
}

int main(void) {
    if (check_random_inputs() != 0 || check_boundary_values() != 0) {
        return 1;
    }

    puts("All RVV reduction checks passed");
    return 0;
}
