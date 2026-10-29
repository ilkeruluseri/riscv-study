#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

int32_t dot_i8_one_accumulator(const int8_t *a, const int8_t *b, size_t n) {
    int32_t sum = 0;

    for (size_t i = 0; i < n; i++) {
        sum += a[i] * b[i];
    }

    return sum;
}

int32_t dot_i8_two_accumulators(const int8_t *a, const int8_t *b, size_t n) {
    int32_t acc1 = 0;
    int32_t acc2 = 0;
    

    for (size_t i = 0; i + 1 < n; i+=2) {
        acc1 += a[i] * b[i];
        acc2 += a[i + 1] * b[i + 1];
    }
    if (n % 2 == 1) {
        acc2 += a[n - 1] * b[n - 1];
    }

    return acc1 + acc2;
}

int32_t dot_i8_four_accumulators(const int8_t *a, const int8_t *b, size_t n) {
    int32_t acc1 = 0;
    int32_t acc2 = 0;
    int32_t acc3 = 0;
    int32_t acc4 = 0;

    for (size_t i = 0; i + 3 < n; i+=4) {
        acc1 += a[i] * b[i];
        acc2 += a[i + 1] * b[i + 1];
        acc3 += a[i + 2] * b[i + 2];
        acc4 += a[i + 3] * b[i + 3];
    }
    switch (n % 4) {
        case 0:
            break;
        case 1:
            acc4 += a[n - 1] * b[n - 1];
            break;
        case 2:
            acc4 += a[n - 1] * b[n - 1];
            acc4 += a[n - 2] * b[n - 2];
            break;
        case 3:
            acc4 += a[n - 1] * b[n - 1];
            acc4 += a[n - 2] * b[n - 2];
            acc4 += a[n - 3] * b[n - 3];
            break;
    }
    return acc1 + acc2 + acc3 + acc4;
}

struct test_case {
    size_t n;
    int32_t expected;
};

struct implementation {
    const char *name;
    int32_t (*dot)(const int8_t *, const int8_t *, size_t);
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
    static const struct implementation implementations[] = {
        { "one accumulator", dot_i8_one_accumulator },
        { "two accumulators", dot_i8_two_accumulators },
        { "four accumulators", dot_i8_four_accumulators },
    };
    int8_t a[33];
    int8_t b[33];
    int failures = 0;

    for (size_t i = 0; i < 33; i++) {
        a[i] = (int8_t) ((i * 37 + 13) % 256 - 128);
        b[i] = (int8_t) ((i * 73 + 29) % 256 - 128);
    }

    for (size_t implementation = 0;
         implementation < sizeof(implementations) / sizeof(implementations[0]);
         implementation++) {
        for (size_t test = 0; test < sizeof(cases) / sizeof(cases[0]); test++) {
            const int32_t actual = implementations[implementation].dot(
                a, b, cases[test].n);

            if (actual != cases[test].expected) {
                fprintf(stderr,
                        "%s, n=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                        implementations[implementation].name,
                        cases[test].n,
                        cases[test].expected,
                        actual);
                failures++;
            }
        }
    }

    if (failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }

    puts("All unrolled dot-product checks passed");
    return 0;
}
