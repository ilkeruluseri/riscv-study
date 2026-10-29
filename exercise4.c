#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

int32_t dot_i8_scalar(const int8_t *a, const int8_t *b, size_t n) {
    /* TODO: calculate the dot product using an int32_t accumulator. */
    int32_t acc = 0;
    for (size_t i = 0; i < n; i++) {
        acc += a[i] * b[i];
    }
    return acc;
}

struct test_case {
    size_t n;
    int32_t expected;
};

int main(void) {
    static const struct test_case cases[] = {
        { 0, 0 },
        { 1, 11385 },
        { 2, 13413 },
        { 3, 11486 },
        { 7, 18508 },
        { 15, 48248 },
        { 16, 50264 },
        { 17, 48689 },
        { 31, 86544 },
        { 32, 87472 },
        { 33, 84457 },
    };
    int8_t a[33];
    int8_t b[33];
    int failures = 0;

    for (size_t i = 0; i < 33; i++) {
        a[i] = (int8_t) ((i * 37 + 13) % 256 - 128);
        b[i] = (int8_t) ((i * 73 + 29) % 256 - 128);
    }

    for (size_t test = 0; test < sizeof(cases) / sizeof(cases[0]); test++) {
        const int32_t actual = dot_i8_scalar(a, b, cases[test].n);

        if (actual != cases[test].expected) {
            fprintf(stderr,
                    "n=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                    cases[test].n, cases[test].expected, actual);
            failures++;
        }
    }

    if (failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }

    puts("All scalar dot-product checks passed");
    return 0;
}
