#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <riscv_vector.h>

void unpack_nibbles_scalar(const uint8_t *packed,
                           uint8_t *low,
                           uint8_t *high,
                           size_t n) {
    for (size_t i = 0; i < n; i++) {
        low[i] = packed[i] & 0x0f;
        high[i] = packed[i] >> 4;
    }
}

void unpack_nibbles_rvv(const uint8_t *packed,
                        uint8_t *low,
                        uint8_t *high,
                        size_t n) {
    size_t offset = 0;
    
    while (offset < n) {
        size_t remaining = n - offset;

        size_t vl = __riscv_vsetvl_e8m1(remaining);
        vuint8m1_t bytes = __riscv_vle8_v_u8m1(packed + offset, vl);

        vuint8m1_t low_bits = __riscv_vand_vx_u8m1(bytes, 0x0f, vl);
        vuint8m1_t high_bits = __riscv_vsrl_vx_u8m1(bytes, 4, vl);

        __riscv_vse8_v_u8m1(low + offset, low_bits, vl);
        __riscv_vse8_v_u8m1(high + offset, high_bits, vl);

        offset += vl;
    }
}

typedef void (*unpack_function)(
    const uint8_t *, uint8_t *, uint8_t *, size_t);

struct implementation {
    const char *name;
    unpack_function unpack;
};

static int check_case(const struct implementation *implementation, size_t n) {
    enum { CAPACITY = 259 };
    static const uint8_t guard = UINT8_C(0xa5);
    uint8_t packed[CAPACITY];
    uint8_t low[CAPACITY];
    uint8_t high[CAPACITY];

    for (size_t i = 0; i < CAPACITY; i++) {
        packed[i] = (uint8_t) i;
        low[i] = guard;
        high[i] = guard;
    }

    implementation->unpack(packed, low, high, n);

    for (size_t i = 0; i < n; i++) {
        const uint8_t expected_low = packed[i] & UINT8_C(0x0f);
        const uint8_t expected_high = packed[i] >> 4;

        if (low[i] != expected_low || high[i] != expected_high) {
            fprintf(stderr,
                    "%s, n=%zu, index=%zu, packed=0x%02x: "
                    "expected low=%u high=%u, got low=%u high=%u\n",
                    implementation->name,
                    n,
                    i,
                    packed[i],
                    expected_low,
                    expected_high,
                    low[i],
                    high[i]);
            return 1;
        }
    }

    for (size_t i = n; i < CAPACITY; i++) {
        if (low[i] != guard || high[i] != guard) {
            fprintf(stderr,
                    "%s, n=%zu: output index %zu was modified past "
                    "the requested length\n",
                    implementation->name,
                    n,
                    i);
            return 1;
        }
    }

    return 0;
}

int main(void) {
    static const size_t sizes[] = {
        0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33, 37,
        127, 128, 129, 255, 256, 257, 259,
    };
    static const struct implementation implementations[] = {
        { "scalar", unpack_nibbles_scalar },
        { "RVV", unpack_nibbles_rvv },
    };

    for (size_t implementation = 0;
         implementation < sizeof(implementations) / sizeof(implementations[0]);
         implementation++) {
        for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
            if (check_case(&implementations[implementation], sizes[test]) != 0) {
                return 1;
            }
        }
    }

    puts("All scalar and RVV nibble-extraction checks passed");
    return 0;
}
