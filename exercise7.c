#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <riscv_vector.h>

void add_i32_rvv(const int32_t *a,
                 const int32_t *b,
                 int32_t *result,
                 size_t n) {
    size_t offset = 0;

    while (offset < n) {
        size_t remaining = n - offset;
        size_t vl = __riscv_vsetvl_e32m1(remaining);

        vint32m1_t left = __riscv_vle32_v_i32m1(a + offset, vl);
        vint32m1_t right = __riscv_vle32_v_i32m1(b + offset, vl);
        vint32m1_t sum = __riscv_vadd_vv_i32m1(left, right, vl);

        __riscv_vse32_v_i32m1(result + offset, sum, vl);

        offset += vl;
    }
}

static void add_i32_scalar(const int32_t *a,
                           const int32_t *b,
                           int32_t *result,
                           size_t n) {
    for (size_t i = 0; i < n; i++) {
        result[i] = a[i] + b[i];
    }
}

static int check_size(size_t n) {
    enum { CAPACITY = 259 };
    static const int32_t guard = INT32_C(0x55555555);
    int32_t a[CAPACITY];
    int32_t b[CAPACITY];
    int32_t expected[CAPACITY];
    int32_t storage[CAPACITY + 2];
    int32_t *const actual = &storage[1];
    int failures = 0;

    for (size_t i = 0; i < CAPACITY; i++) {
        a[i] = (int32_t) ((i * 97 + 31) % 200001) - 100000;
        b[i] = (int32_t) ((i * 53 + 7) % 160001) - 80000;
        expected[i] = guard;
        actual[i] = guard;
    }
    storage[0] = guard;
    storage[CAPACITY + 1] = guard;

    add_i32_scalar(a, b, expected, n);
    add_i32_rvv(a, b, actual, n);

    for (size_t i = 0; i < n; i++) {
        if (actual[i] != expected[i]) {
            fprintf(stderr,
                    "n=%zu, index=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                    n,
                    i,
                    expected[i],
                    actual[i]);
            failures++;
            break;
        }
    }

    for (size_t i = n; i < CAPACITY; i++) {
        if (actual[i] != guard) {
            fprintf(stderr,
                    "n=%zu: result[%zu] was modified past the requested length\n",
                    n,
                    i);
            failures++;
            break;
        }
    }

    if (storage[0] != guard || storage[CAPACITY + 1] != guard) {
        fprintf(stderr, "n=%zu: result was modified outside its allocation\n", n);
        failures++;
    }

    return failures;
}

static int check_boundary_values(void) {
    static const int32_t a[] = {
        INT32_MAX, INT32_MIN, INT32_MAX - 10, INT32_MIN + 10,
    };
    static const int32_t b[] = { 0, 0, -10, 10 };
    static const int32_t expected[] = {
        INT32_MAX, INT32_MIN, INT32_MAX - 20, INT32_MIN + 20,
    };
    int32_t actual[4] = { 0, 0, 0, 0 };
    int failures = 0;

    add_i32_rvv(a, b, actual, 4);

    for (size_t i = 0; i < sizeof(actual) / sizeof(actual[0]); i++) {
        if (actual[i] != expected[i]) {
            fprintf(stderr,
                    "boundary index=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                    i,
                    expected[i],
                    actual[i]);
            failures++;
        }
    }

    return failures;
}

int main(void) {
    static const size_t sizes[] = {
        0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33, 37, 127, 128, 129, 257,
    };
    int failures = 0;

    for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
        failures += check_size(sizes[test]);
    }
    failures += check_boundary_values();

    if (failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }

    puts("All RVV array-addition checks passed");
    return 0;
}
