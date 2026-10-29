#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <riscv_vector.h>

void decode_table_scalar(const int8_t values[16],
                         const uint8_t *indices,
                         int8_t *decoded,
                         size_t n) {
    for (size_t i = 0; i < n; i++) {
        decoded[i] = values[indices[i]];
    }
}

void decode_table_rvv(const int8_t values[16],
                      const uint8_t *indices,
                      int8_t *decoded,
                      size_t n) {
    const size_t table_vl = __riscv_vsetvl_e8m1(16);
    const vint8m1_t table = __riscv_vle8_v_i8m1(values, table_vl);
    size_t offset = 0;

    while (offset < n) {
        const size_t vl = __riscv_vsetvl_e8m1(n - offset);
        const vuint8m1_t index =
            __riscv_vle8_v_u8m1(indices + offset, vl);
        const vint8m1_t result =
            __riscv_vrgather_vv_i8m1(table, index, vl);

        __riscv_vse8_v_i8m1(decoded + offset, result, vl);
        offset += vl;
    }
}

typedef void (*decode_function)(
    const int8_t *, const uint8_t *, int8_t *, size_t);

struct implementation {
    const char *name;
    decode_function decode;
};

static int check_case(const struct implementation *implementation,
                      const char *pattern_name,
                      const int8_t values[16],
                      const uint8_t *indices,
                      size_t n) {
    enum { CAPACITY = 259 };
    static const int8_t guard = INT8_C(85);
    int8_t decoded[CAPACITY];

    for (size_t i = 0; i < CAPACITY; i++) {
        decoded[i] = guard;
    }

    implementation->decode(values, indices, decoded, n);

    for (size_t i = 0; i < n; i++) {
        const int8_t expected = values[indices[i]];

        if (decoded[i] != expected) {
            fprintf(stderr,
                    "%s, pattern=%s, n=%zu, index=%zu, table index=%u: "
                    "expected %d, got %d\n",
                    implementation->name,
                    pattern_name,
                    n,
                    i,
                    indices[i],
                    expected,
                    decoded[i]);
            return 1;
        }
    }

    for (size_t i = n; i < CAPACITY; i++) {
        if (decoded[i] != guard) {
            fprintf(stderr,
                    "%s, pattern=%s, n=%zu: decoded[%zu] was modified "
                    "past the requested length\n",
                    implementation->name,
                    pattern_name,
                    n,
                    i);
            return 1;
        }
    }

    return 0;
}

static uint32_t next_random(uint32_t *state) {
    uint32_t value = *state;

    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

int main(void) {
    enum { CAPACITY = 259 };
    static const int8_t values[16] = {
        7, -3, 12, -8, 0, 5, -1, 15,
        -16, 4, -7, 9, -12, 2, -5, 11,
    };
    static const size_t sizes[] = {
        0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33, 37,
        127, 128, 129, 255, 256, 257, 259,
    };
    static const struct implementation implementations[] = {
        { "scalar", decode_table_scalar },
        { "RVV", decode_table_rvv },
    };
    uint8_t ascending[CAPACITY];
    uint8_t reversed[CAPACITY];
    uint8_t repeated[CAPACITY];
    uint8_t randomized[CAPACITY];
    uint32_t random_state = UINT32_C(0xc83a91e5);

    for (size_t i = 0; i < CAPACITY; i++) {
        ascending[i] = (uint8_t) (i % 16);
        reversed[i] = (uint8_t) (15 - i % 16);
        repeated[i] = (uint8_t) ((i / 7) % 16);
        randomized[i] = (uint8_t) (next_random(&random_state) & 0x0f);
    }

    for (size_t implementation = 0;
         implementation < sizeof(implementations) / sizeof(implementations[0]);
         implementation++) {
        for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
            const size_t n = sizes[test];

            if (check_case(&implementations[implementation],
                           "ascending", values, ascending, n) != 0 ||
                check_case(&implementations[implementation],
                           "reversed", values, reversed, n) != 0 ||
                check_case(&implementations[implementation],
                           "repeated", values, repeated, n) != 0 ||
                check_case(&implementations[implementation],
                           "randomized", values, randomized, n) != 0) {
                return 1;
            }
        }
    }

    puts("All scalar and RVV table-decoding checks passed");
    return 0;
}
