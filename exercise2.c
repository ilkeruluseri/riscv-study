#include <stdint.h>
#include <stdio.h>

uint8_t pack_nibbles(uint8_t low, uint8_t high) {
    return (high << 4) | low;
}

uint8_t unpack_low(uint8_t packed) {
    return packed & 0x0f;
}

uint8_t unpack_high(uint8_t packed) {
    return packed >> 4;
}

int main(void) {
    int failures = 0;

    for (uint8_t high = 0; high < 16; high++) {
        for (uint8_t low = 0; low < 16; low++) {
            const uint8_t packed = pack_nibbles(low, high);
            const uint8_t expected_packed = (uint8_t) (high * 16 + low);

            if (packed != expected_packed) {
                printf("pack failed: low=%u high=%u expected=0x%02x got=0x%02x\n",
                       low, high, expected_packed, packed);
                failures++;
            }

            if (unpack_low(packed) != low) {
                printf("unpack_low failed: packed=0x%02x expected=%u got=%u\n",
                       packed, low, unpack_low(packed));
                failures++;
            }

            if (unpack_high(packed) != high) {
                printf("unpack_high failed: packed=0x%02x expected=%u got=%u\n",
                       packed, high, unpack_high(packed));
                failures++;
            }
        }
    }

    if (failures != 0) {
        printf("%d check(s) failed\n", failures);
        return 1;
    }

    puts("All nibble checks passed");
    return 0;
}
