#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <riscv_vector.h>

#define GGML_COMMON_IMPL_C
#include "ggml-common.h"
#include "ggml-quants.h"
#include "ggml-impl.h"
#define NOINLINE __attribute__((noinline))
#define UNUSED GGML_UNUSED
#if defined(__riscv_zfhmin)
#error "This experiment pins rv64gcv and its table-based FP16 conversion"
#endif
static float ggml_table_f32_f16[1 << 16];
#include "conversion.inc"

#if defined(__GNUC__) && !defined(__clang__) && __GNUC__ < 14
static inline vuint8m2_t concat_u8m1(vuint8m1_t lo, vuint8m1_t hi) {
    vuint8m2_t result = __riscv_vundefined_u8m2();
    result = __riscv_vset_v_u8m1_u8m2(result, 0, lo);
    return __riscv_vset_v_u8m1_u8m2(result, 1, hi);
}
#define __riscv_vcreate_v_u8m1_u8m2 concat_u8m1
#endif

#include "kernels.inc"

enum { MAX_BLOCKS = 257 };
static uint32_t state = UINT32_C(0x19b4a73d);
static unsigned case_number;
typedef void (*dot_function)(int, float *, size_t, const void *, size_t,
                             const void *, size_t, int);

static uint32_t random_u32(void) {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

static void fill(block_iq4_nl *x, block_q8_0 *y, int blocks, int pattern) {
    static const float scales[] = {0.0f, 1.0f, -1.0f, 0.5f, 0.25f, 0.3f, 1.7f, 0.0001f};
    for (int b = 0; b < blocks; ++b) {
        x[b].d = GGML_FP32_TO_FP16(scales[random_u32() % 8]);
        y[b].d = GGML_FP32_TO_FP16(scales[random_u32() % 8]);
        for (int j = 0; j < 16; ++j) {
            x[b].qs[j] = pattern >= 0 ? (uint8_t)pattern : (uint8_t)random_u32();
        }
        for (int j = 0; j < 32; ++j) {
            const int values[] = {-128, 127, -1, 0, 1, j - 16, (j & 1) ? 127 : -128};
            y[b].qs[j] = pattern >= 0 ? (int8_t)values[b % 7] :
                                      (int8_t)((int)(random_u32() % 256) - 128);
        }
    }
}

static double independent_reference(const block_iq4_nl *x, const block_q8_0 *y, int blocks) {
    static const int table[16] = {
        -127, -104, -83, -65, -49, -35, -22, -10, 1, 13, 25, 38, 53, 69, 89, 113
    };
    double total = 0;
    for (int b = 0; b < blocks; ++b) {
        int64_t dot = 0;
        for (int j = 0; j < 32; ++j) {
            const unsigned packed = x[b].qs[j % 16];
            const unsigned code = j < 16 ? packed % 16 : packed / 16;
            dot += (int64_t)table[code] * y[b].qs[j];
        }
        total += (double)GGML_FP16_TO_FP32(x[b].d) *
                 GGML_FP16_TO_FP32(y[b].d) * (double)dot;
    }
    return total;
}

static float invoke(dot_function fn, const block_iq4_nl *x, const block_q8_0 *y, int blocks) {
    struct { float before, result, after; } output = {12345.0f, NAN, -54321.0f};
    fn(blocks * 32, &output.result, 0, x, 0, y, 0, 1);
    if (output.before != 12345.0f || output.after != -54321.0f) {
        fprintf(stderr, "Output guard damaged in case %u\n", case_number);
        exit(1);
    }
    return output.result;
}

static void check(const block_iq4_nl *x, const block_q8_0 *y, int blocks) {
    const float reference = invoke(ggml_vec_dot_iq4_nl_q8_0_generic, x, y, blocks);
    const float a = invoke(baseline, x, y, blocks);
    const float b = invoke(candidate, x, y, blocks);
    const double expected = independent_reference(x, y, blocks);
    /* Bound cancellation by the sum of absolute block contributions. */
    double magnitude = 0;
    for (int i = 0; i < blocks; ++i) {
        magnitude += fabs(independent_reference(x + i, y + i, 1));
    }
    const double tolerance = 1e-5 + 2e-6 * magnitude;
    const float original_result = (blocks % 2 == 0) ? invoke(original, x, y, blocks) : reference;
    if (!isfinite(a) || !isfinite(b) || !isfinite(reference) ||
        memcmp(&a, &b, sizeof(a)) != 0 ||
        fabs((double)a - reference) > tolerance ||
        fabs((double)reference - expected) > tolerance ||
        fabs((double)a - expected) > tolerance ||
        fabs((double)original_result - reference) > tolerance) {
        fprintf(stderr, "FAIL case=%u blocks=%d rng=0x%08" PRIx32
                " generic=%.9g baseline=%.9g candidate=%.9g double=%.17g tolerance=%.9g\n",
                case_number, blocks, state, reference, a, b, expected, tolerance);
        for (int i = 0; i < blocks; ++i) {
            fprintf(stderr, "block=%d scales=%04x,%04x packed=", i, x[i].d, y[i].d);
            for (int j = 0; j < 16; ++j) fprintf(stderr, "%02x", x[i].qs[j]);
            fprintf(stderr, " activations=");
            for (int j = 0; j < 32; ++j) fprintf(stderr, "%02x", (uint8_t)y[i].qs[j]);
            fputc('\n', stderr);
        }
        exit(1);
    }
    ++case_number;
}

struct guarded { void *mapping; size_t length; void *data; };

static struct guarded guard_input(const void *input, size_t size, int at_end) {
    const long page_query = sysconf(_SC_PAGESIZE);
    if (page_query <= 0) { perror("sysconf"); exit(1); }
    const size_t page = (size_t)page_query;
    const size_t payload = ((size + page - 1) / page + 1) * page;
    const size_t length = payload + 2 * page;
    char *base = mmap(NULL, length, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base == MAP_FAILED) { perror("mmap"); exit(1); }
    if (mprotect(base + page, payload, PROT_READ | PROT_WRITE) != 0) {
        perror("mprotect"); exit(1);
    }
    void *data = at_end ? base + page + payload - size : base + page;
    if (size) memcpy(data, input, size);
    if (mprotect(base + page, payload, PROT_READ) != 0) { perror("mprotect"); exit(1); }
    return (struct guarded){base, length, data};
}

static void tests(void) {
    block_iq4_nl x[MAX_BLOCKS];
    block_q8_0 y[MAX_BLOCKS];
    const int counts[] = {0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 127, 128, 129, 256, 257};
    int failures = 0;
    for (int n = 0; n <= 5; ++n) {
        fill(x, y, n, 0x88);
        for (int i = 0; i < n; ++i) {
            x[i].d = y[i].d = GGML_FP32_TO_FP16(1.0f);
            memset(y[i].qs, 1, sizeof(y[i].qs));
        }
        const float actual = invoke(original, x, y, n);
        const float expected = (float)(32 * n);
        printf("original: blocks=%d expected=%.0f actual=%.0f\n", n, expected, actual);
        failures += actual != expected;
        if (actual != (float)(64 * (n / 2))) exit(1);
        check(x, y, n);
    }
    if (failures != 3) { fprintf(stderr, "Expected three known odd-block failures\n"); exit(1); }
    for (unsigned c = 0; c < sizeof(counts)/sizeof(counts[0]); ++c) {
        for (int pattern = 0; pattern < 256; ++pattern) {
            fill(x, y, counts[c], pattern);
            check(x, y, counts[c]);
        }
        fill(x, y, counts[c], -1);
        for (int side = 0; side < 2; ++side) {
            struct guarded gx = guard_input(x, counts[c] * sizeof(x[0]), side);
            struct guarded gy = guard_input(y, counts[c] * sizeof(y[0]), side);
            check(gx.data, gy.data, counts[c]);
            if (munmap(gx.mapping, gx.length) || munmap(gy.mapping, gy.length)) {
                perror("munmap"); exit(1);
            }
        }
    }
    for (int i = 0; i < 3000; ++i) {
        const int n = (int)(random_u32() % (MAX_BLOCKS + 1));
        fill(x, y, n, -1);
        check(x, y, n);
    }
    printf("PASS: %u cases; baseline/candidate bit-identical; generic and double references agree within tolerance; 38 guarded cases\n", case_number);
}

static uint64_t nanoseconds(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) { perror("clock_gettime"); exit(1); }
    return (uint64_t)now.tv_sec * UINT64_C(1000000000) + (uint64_t)now.tv_nsec;
}

static volatile float benchmark_sink;

static uint64_t timed(dot_function fn, const block_iq4_nl *x, const block_q8_0 *y,
                      int blocks, int iterations) {
    float result = 0;
    const uint64_t start = nanoseconds();
    for (int i = 0; i < iterations; ++i) {
        fn(blocks * 32, &result, 0, x, 0, y, 0, 1);
        benchmark_sink = result;
    }
    return nanoseconds() - start;
}

static int positive_number(const char *value, int maximum) {
    char *end;
    errno = 0;
    const long parsed = strtol(value, &end, 10);
    if (errno || *end || end == value || parsed < 1 || parsed > maximum) {
        fprintf(stderr, "Expected integer in 1..%d: %s\n", maximum, value);
        exit(2);
    }
    return (int)parsed;
}

static void benchmark(int iterations, int samples) {
    block_iq4_nl x[MAX_BLOCKS];
    block_q8_0 y[MAX_BLOCKS];
    const int counts[] = {1, 2, 8, 32, 128, 129, 256};
    fill(x, y, MAX_BLOCKS, -1);
    printf("sample,position,variant,blocks,iterations,total_ns,ns_per_call\n");
    for (unsigned c = 0; c < sizeof(counts)/sizeof(counts[0]); ++c) {
        check(x, y, counts[c]);
        (void)timed(baseline, x, y, counts[c], 100);
        (void)timed(candidate, x, y, counts[c], 100);
        for (int sample = 0; sample < samples; ++sample) {
            for (int position = 0; position < 2; ++position) {
                const int which = (sample + position) % 2;
                const uint64_t elapsed = timed(which ? candidate : baseline, x, y,
                                               counts[c], iterations);
                printf("%d,%d,%s,%d,%d,%" PRIu64 ",%.3f\n", sample, position,
                       which ? "candidate" : "baseline", counts[c], iterations,
                       elapsed, (double)elapsed / iterations);
            }
        }
    }
}

int main(int argc, char **argv) {
    for (unsigned i = 0; i < (1u << 16); ++i) {
        ggml_table_f32_f16[i] = GGML_FP16_TO_FP32((ggml_fp16_t)i);
    }
    const size_t vlen = __riscv_vlenb() * 8;
    if (vlen != 128 && vlen != 256 && vlen != 512) {
        fprintf(stderr, "Study validates only VLEN 128, 256 and 512; got %zu\n", vlen);
        return 2;
    }
    fprintf(stderr, "VLEN=%zu seed=0x%08" PRIx32 "\n", vlen, state);
    if (argc >= 2 && strcmp(argv[1], "--bench") == 0 && argc <= 4) {
        benchmark(argc >= 3 ? positive_number(argv[2], 10000000) : 10000,
                  argc >= 4 ? positive_number(argv[3], 1001) : 21);
    } else if (argc == 1) {
        tests();
    } else {
        fprintf(stderr, "usage: %s [--bench [iterations [samples]]]\n", argv[0]);
        return 2;
    }
    return 0;
}
