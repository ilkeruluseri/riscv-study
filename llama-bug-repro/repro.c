#include <riscv_vector.h>

// GCC 13 lacks vcreate; insert the two register groups instead.
#if defined(__GNUC__) && !defined(__clang__) && __GNUC__ < 14
static inline vuint8m2_t concat_u8m1(vuint8m1_t lo, vuint8m1_t hi) {
    vuint8m2_t result = __riscv_vundefined_u8m2();
    result = __riscv_vset_v_u8m1_u8m2(result, 0, lo);
    return __riscv_vset_v_u8m1_u8m2(result, 1, hi);
}
#define __riscv_vcreate_v_u8m1_u8m2 concat_u8m1
#endif

#include "kernels.inc"

int main(void) {
    block_iq4_nl iq[5] = {0};
    block_mxfp4 mx[5] = {0};
    block_q8_0 q8[5] = {0};

    for (int b = 0; b < 5; ++b) {
        iq[b].d = GGML_FP32_TO_FP16(1.0f);
        memset(iq[b].qs, 0x88, sizeof(iq[b].qs));
        mx[b].e = 127;
        memset(mx[b].qs, 0x22, sizeof(mx[b].qs));
        q8[b].d = GGML_FP32_TO_FP16(1.0f);
        memset(q8[b].qs, 1, sizeof(q8[b].qs));
    }

    printf("VLEN=%zu bits; every block contributes exactly 32\n", (size_t)__riscv_vlenb() * 8);
    printf("format   blocks elements expected generic RVV missing\n");
    int mismatches = 0;
    for (int format = 0; format < 2; ++format) {
        for (int blocks = 0; blocks <= 5; ++blocks) {
            float reference = -1, actual = -1;
            const int n = blocks * 32;
            if (format == 0) {
                ggml_vec_dot_iq4_nl_q8_0_generic(n, &reference, 0, iq, 0, q8, 0, 1);
                ggml_vec_dot_iq4_nl_q8_0(n, &actual, 0, iq, 0, q8, 0, 1);
            } else {
                ggml_vec_dot_mxfp4_q8_0_generic(n, &reference, 0, mx, 0, q8, 0, 1);
                ggml_vec_dot_mxfp4_q8_0(n, &actual, 0, mx, 0, q8, 0, 1);
            }
            const float expected = (float)n;
            printf("%-8s %6d %8d %8.0f %7.0f %3.0f %7.0f\n",
                   format == 0 ? "IQ4_NL" : "MXFP4", blocks, n,
                   expected, reference, actual, reference - actual);
            if (reference != expected) {
                fprintf(stderr, "Reference disagrees with the hand calculation\n");
                return 2;
            }
            mismatches += actual != reference;
        }
    }
    printf("%d RVV/reference mismatches\n", mismatches);
    return mismatches ? 1 : 0;
}
