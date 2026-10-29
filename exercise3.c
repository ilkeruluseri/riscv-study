#include <assert.h>
#include <stdint.h>
#include <stdio.h>

int8_t decode_i4_arithmetic(uint8_t nibble) {
    assert(nibble < 16);

    if (nibble < 8) {
        return (int8_t) nibble;
    }

    int8_t result = -16 + nibble;
    return result;
}

int8_t decode_i4_table(uint8_t nibble) {
    static const int8_t values[16] = {
         0,  1,  2,  3,  4,  5,  6,  7,
        -8, -7, -6, -5, -4, -3, -2, -1,
    };

    assert(nibble < 16);
    return values[nibble];
}

int main(void) {
    static const int8_t expected[16] = {
         0,  1,  2,  3,  4,  5,  6,  7,
        -8, -7, -6, -5, -4, -3, -2, -1,
    };
    int failures = 0;

    for (uint8_t nibble = 0; nibble < 16; nibble++) {
        const int8_t arithmetic = decode_i4_arithmetic(nibble);
        const int8_t table = decode_i4_table(nibble);

        if (arithmetic != expected[nibble]) {
            printf("arithmetic failed: nibble=0x%x expected=%d got=%d\n",
                   nibble, expected[nibble], arithmetic);
            failures++;
        }

        if (table != expected[nibble]) {
            printf("table failed: nibble=0x%x expected=%d got=%d\n",
                   nibble, expected[nibble], table);
            failures++;
        }

        if (arithmetic != table) {
            printf("implementations disagree: nibble=0x%x arithmetic=%d table=%d\n",
                   nibble, arithmetic, table);
            failures++;
        }
    }

    if (failures != 0) {
        printf("%d check(s) failed\n", failures);
        return 1;
    }

    puts("All i4 decoding checks passed");
    return 0;
}
