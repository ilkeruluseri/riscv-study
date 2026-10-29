#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>


void add_i32(const int32_t * a, const int32_t * b, int32_t * result, size_t n) {
    for (size_t i = 0; i < n; i++) {
        result[i] = a[i] + b[i];
    }
}

int main(void) {
    static const size_t sizes[] = { 0, 1, 3, 4, 7, 16, 17 };
    static const int32_t untouched = INT32_C(0x55555555);
    int failures = 0;

    for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
        const size_t n = sizes[test];
        int32_t a[17];
        int32_t b[17];
        int32_t result[17];

        for (size_t i = 0; i < 17; i++) {
            a[i] = (int32_t) (3 * i) - 20;
            b[i] = 12 - (int32_t) (2 * i);
            result[i] = untouched;
        }

        add_i32(a, b, result, n);

        for (size_t i = 0; i < n; i++) {
            const int32_t expected = a[i] + b[i];
            if (result[i] != expected) {
                fprintf(stderr, "n=%zu, index=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                        n, i, expected, result[i]);
                failures++;
            }
        }

        for (size_t i = n; i < 17; i++) {
            if (result[i] != untouched) {
                fprintf(stderr, "n=%zu: result[%zu] was modified past the requested length\n", n, i);
                failures++;
            }
        }
    }

    {
        const int32_t a[]        = { INT32_MAX, INT32_MIN, INT32_MAX - 10, INT32_MIN + 10 };
        const int32_t b[]        = { 0,         0,         -10,            10 };
        const int32_t expected[] = { INT32_MAX, INT32_MIN, INT32_MAX - 20, INT32_MIN + 20 };
        int32_t result[4] = { 0 };

        add_i32(a, b, result, 4);

        for (size_t i = 0; i < 4; i++) {
            if (result[i] != expected[i]) {
                fprintf(stderr, "boundary index=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                        i, expected[i], result[i]);
                failures++;
            }
        }
    }

    if (failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }

    puts("All add_i32 checks passed");
    return 0;
}
