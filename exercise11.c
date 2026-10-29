#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <riscv_vector.h>

int32_t dot_i8_rvv(const int8_t *a, const int8_t *b, size_t n) {
    size_t offset = 0;
    int32_t sum = 0;
    while (offset < n) {
        size_t remaining = n - offset;
        size_t vl = __riscv_vsetvl_e8m1(remaining);

        vint8m1_t va = __riscv_vle8_v_i8m1(a + offset, vl);
        vint8m1_t vb = __riscv_vle8_v_i8m1(b + offset, vl);

        vint16m2_t products = __riscv_vwmul_vv_i16m2(va, vb, vl);

        vint32m1_t zero = __riscv_vmv_v_x_i32m1(0, 1);

        vint32m1_t reduced = __riscv_vwredsum_vs_i16m2_i32m1(products, zero, vl);

        int32_t chunk_sum = __riscv_vmv_x_s_i32m1_i32(reduced);
        sum += chunk_sum;

        offset += vl;
    }
    return sum;
}

static int32_t dot_i8_scalar(const int8_t *a, const int8_t *b, size_t n) {
    int32_t sum = 0;

    for (size_t i = 0; i < n; i++) {
        sum += a[i] * b[i];
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
    int8_t a[CAPACITY];
    int8_t b[CAPACITY];
    uint32_t random_state = UINT32_C(0x74b9d21f);

    for (size_t i = 0; i < CAPACITY; i++) {
        a[i] = (int8_t) next_random(&random_state);
        b[i] = (int8_t) next_random(&random_state);
    }

    for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
        const size_t n = sizes[test];
        const int32_t expected = dot_i8_scalar(a, b, n);
        const int32_t actual = dot_i8_rvv(a, b, n);

        if (actual != expected) {
            fprintf(stderr,
                    "random n=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                    n,
                    expected,
                    actual);
            return 1;
        }
    }

    return 0;
}

static int check_sign_patterns(void) {
    static const int8_t a[] = {
        5, -5, 5, -5, 127, -128, 100, -100, 1, -1,
    };
    static const int8_t b[] = {
        7, 7, -7, -7, 127, -128, -100, 100, -1, -1,
    };
    const int32_t expected = dot_i8_scalar(a, b, sizeof(a) / sizeof(a[0]));
    const int32_t actual = dot_i8_rvv(a, b, sizeof(a) / sizeof(a[0]));

    if (actual != expected) {
        fprintf(stderr,
                "sign patterns: expected %" PRId32 ", got %" PRId32 "\n",
                expected,
                actual);
        return 1;
    }

    return 0;
}

static int check_wide_accumulation(void) {
    enum { LENGTH = 65537 };
    static int8_t a[LENGTH];
    static int8_t b[LENGTH];
    int64_t expected = 0;

    for (size_t i = 0; i < LENGTH; i++) {
        a[i] = INT8_MIN;
        b[i] = INT8_MIN;
        expected += (int32_t) a[i] * b[i];
    }

    const int32_t actual = dot_i8_rvv(a, b, LENGTH);

    if (actual != (int32_t) expected) {
        fprintf(stderr,
                "wide accumulation: expected %" PRId64 ", got %" PRId32 "\n",
                expected,
                actual);
        return 1;
    }

    return 0;
}

int main(void) {
    if (check_random_inputs() != 0 ||
        check_sign_patterns() != 0 ||
        check_wide_accumulation() != 0) {
        return 1;
    }

    puts("All RVV i8 dot-product checks passed");
    return 0;
}
