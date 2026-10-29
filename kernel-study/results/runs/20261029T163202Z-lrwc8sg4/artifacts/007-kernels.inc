void ggml_vec_dot_iq4_nl_q8_0_generic(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    for (; ib < nb; ++ib) {
        const float d = GGML_CPU_FP16_TO_FP32(y[ib].d)*GGML_CPU_FP16_TO_FP32(x[ib].d);
        int sumi1 = 0, sumi2 = 0;
        for (int j = 0; j < QK4_NL/2; ++j) {
            sumi1 += y[ib].qs[j+       0] * kvalues_iq4nl[x[ib].qs[j] & 0xf];
            sumi2 += y[ib].qs[j+QK4_NL/2] * kvalues_iq4nl[x[ib].qs[j] >>  4];
        }
        sumf += d * (sumi1 + sumi2);
    }
    *s = sumf;
}

static NOINLINE void original_vl128(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    // Load the lookup table once.
    const vint8m2_t values = __riscv_vle8_v_i8m2(kvalues_iq4nl, 16);
    int acc1, acc2;

    // We process 2 blocks at once.
    for (; ib + 1 < nb; ib += 2) {
        // Weights and activations.
        vuint8m1_t iq4_packed1 = __riscv_vle8_v_u8m1(x[ib + 0].qs, 16);
        vint8m2_t q8b1 = __riscv_vle8_v_i8m2(y[ib + 0].qs, 32);
        vuint8m1_t iq4_packed2 = __riscv_vle8_v_u8m1(x[ib + 1].qs, 16);
        vint8m2_t q8b2 = __riscv_vle8_v_i8m2(y[ib + 1].qs, 32);

        // Unpack the weight blocks.
        vuint8m2_t iq4bits1 = __riscv_vcreate_v_u8m1_u8m2(
            __riscv_vand_vx_u8m1(iq4_packed1, 0xf, 16),
            __riscv_vsrl_vx_u8m1(iq4_packed1, 4, 16)
        );
        vuint8m2_t iq4bits2 = __riscv_vcreate_v_u8m1_u8m2(
            __riscv_vand_vx_u8m1(iq4_packed2, 0xf, 16),
            __riscv_vsrl_vx_u8m1(iq4_packed2, 4, 16)
        );

        // Gather values from the lookup table.
        vint8m2_t iq4b1 = __riscv_vrgather_vv_i8m2(values, iq4bits1, 32);
        vint8m2_t iq4b2 = __riscv_vrgather_vv_i8m2(values, iq4bits2, 32);

        // Accumulation.
        vint16m4_t sum1 = __riscv_vwmul_vv_i16m4(q8b1, iq4b1, 32);
        vint16m4_t sum2 = __riscv_vwmul_vv_i16m4(q8b2, iq4b2, 32);
        __riscv_vse32_v_i32m1(&acc1,__riscv_vwredsum_vs_i16m4_i32m1(sum1, __riscv_vmv_v_x_i32m1(0, 1), 32), 1);
        __riscv_vse32_v_i32m1(&acc2,__riscv_vwredsum_vs_i16m4_i32m1(sum2, __riscv_vmv_v_x_i32m1(0, 1), 32), 1);
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 0].d) * GGML_CPU_FP16_TO_FP32(y[ib + 0].d) * acc1));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 1].d) * GGML_CPU_FP16_TO_FP32(y[ib + 1].d) * acc2));
    }

    *s = sumf;
}

static NOINLINE void original_vl256(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    // Load the lookup table once.
    const vint8mf2_t values = __riscv_vle8_v_i8mf2(kvalues_iq4nl, 16);
    int acc1, acc2;

    // We process 2 blocks at once.
    for (; ib + 1 < nb; ib += 2) {
        // Weights and activations.
        vuint8mf2_t iq4_packed1 = __riscv_vle8_v_u8mf2(x[ib + 0].qs, 16);
        vint8mf2_t q8b_lo1 = __riscv_vle8_v_i8mf2(y[ib + 0].qs, 16);
        vint8mf2_t q8b_hi1 = __riscv_vle8_v_i8mf2(y[ib + 0].qs + 16, 16);
        vuint8mf2_t iq4_packed2 = __riscv_vle8_v_u8mf2(x[ib + 1].qs, 16);
        vint8mf2_t q8b_lo2 = __riscv_vle8_v_i8mf2(y[ib + 1].qs, 16);
        vint8mf2_t q8b_hi2 = __riscv_vle8_v_i8mf2(y[ib + 1].qs + 16, 16);

        // Unpack the weight blocks.
        vuint8mf2_t iq4bits_lo1 = __riscv_vand_vx_u8mf2(iq4_packed1, 0xf, 16);
        vuint8mf2_t iq4bits_hi1 = __riscv_vsrl_vx_u8mf2(iq4_packed1, 4, 16);
        vuint8mf2_t iq4bits_lo2 = __riscv_vand_vx_u8mf2(iq4_packed2, 0xf, 16);
        vuint8mf2_t iq4bits_hi2 = __riscv_vsrl_vx_u8mf2(iq4_packed2, 4, 16);

        // Gather values from the lookup table.
        vint8mf2_t iq4b_lo1 = __riscv_vrgather_vv_i8mf2(values, iq4bits_lo1, 16);
        vint8mf2_t iq4b_hi1 = __riscv_vrgather_vv_i8mf2(values, iq4bits_hi1, 16);
        vint8mf2_t iq4b_lo2 = __riscv_vrgather_vv_i8mf2(values, iq4bits_lo2, 16);
        vint8mf2_t iq4b_hi2 = __riscv_vrgather_vv_i8mf2(values, iq4bits_hi2, 16);

        // Accumulation.
        vint16m1_t sum1 = __riscv_vwmul_vv_i16m1(q8b_lo1, iq4b_lo1, 16);
        sum1 = __riscv_vwmacc_vv_i16m1(sum1, q8b_hi1, iq4b_hi1, 16);
        vint16m1_t sum2 = __riscv_vwmul_vv_i16m1(q8b_lo2, iq4b_lo2, 16);
        sum2 = __riscv_vwmacc_vv_i16m1(sum2, q8b_hi2, iq4b_hi2, 16);
        __riscv_vse32_v_i32m1(&acc1,__riscv_vwredsum_vs_i16m1_i32m1(sum1, __riscv_vmv_v_x_i32m1(0, 1), 16), 1);
        __riscv_vse32_v_i32m1(&acc2,__riscv_vwredsum_vs_i16m1_i32m1(sum2, __riscv_vmv_v_x_i32m1(0, 1), 16), 1);
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 0].d) * GGML_CPU_FP16_TO_FP32(y[ib + 0].d) * acc1));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 1].d) * GGML_CPU_FP16_TO_FP32(y[ib + 1].d) * acc2));
    }

    *s = sumf;
}

__attribute__((noinline)) void original(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
#if defined __riscv_v
    switch (__riscv_vlenb() * 8) {
        case 128:
            original_vl128(n, s, bs, vx, bx, vy, by, nrc);
            break;
        default: // 256 and above
            original_vl256(n, s, bs, vx, bx, vy, by, nrc);
            break;
    }
#else
    ggml_vec_dot_iq4_nl_q8_0_generic(n, s, bs, vx, bx, vy, by, nrc);
#endif
}

static NOINLINE void baseline_vl128(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    // Load the lookup table once.
    const vint8m2_t values = __riscv_vle8_v_i8m2(kvalues_iq4nl, 16);
    int acc1, acc2;

    // We process 2 blocks at once.
    for (; ib + 1 < nb; ib += 2) {
        // Weights and activations.
        vuint8m1_t iq4_packed1 = __riscv_vle8_v_u8m1(x[ib + 0].qs, 16);
        vint8m2_t q8b1 = __riscv_vle8_v_i8m2(y[ib + 0].qs, 32);
        vuint8m1_t iq4_packed2 = __riscv_vle8_v_u8m1(x[ib + 1].qs, 16);
        vint8m2_t q8b2 = __riscv_vle8_v_i8m2(y[ib + 1].qs, 32);

        // Unpack the weight blocks.
        vuint8m2_t iq4bits1 = __riscv_vcreate_v_u8m1_u8m2(
            __riscv_vand_vx_u8m1(iq4_packed1, 0xf, 16),
            __riscv_vsrl_vx_u8m1(iq4_packed1, 4, 16)
        );
        vuint8m2_t iq4bits2 = __riscv_vcreate_v_u8m1_u8m2(
            __riscv_vand_vx_u8m1(iq4_packed2, 0xf, 16),
            __riscv_vsrl_vx_u8m1(iq4_packed2, 4, 16)
        );

        // Gather values from the lookup table.
        vint8m2_t iq4b1 = __riscv_vrgather_vv_i8m2(values, iq4bits1, 32);
        vint8m2_t iq4b2 = __riscv_vrgather_vv_i8m2(values, iq4bits2, 32);

        // Accumulation.
        vint16m4_t sum1 = __riscv_vwmul_vv_i16m4(q8b1, iq4b1, 32);
        vint16m4_t sum2 = __riscv_vwmul_vv_i16m4(q8b2, iq4b2, 32);
        __riscv_vse32_v_i32m1(&acc1,__riscv_vwredsum_vs_i16m4_i32m1(sum1, __riscv_vmv_v_x_i32m1(0, 1), 32), 1);
        __riscv_vse32_v_i32m1(&acc2,__riscv_vwredsum_vs_i16m4_i32m1(sum2, __riscv_vmv_v_x_i32m1(0, 1), 32), 1);
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 0].d) * GGML_CPU_FP16_TO_FP32(y[ib + 0].d) * acc1));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 1].d) * GGML_CPU_FP16_TO_FP32(y[ib + 1].d) * acc2));
    }

    if (ib < nb) {
        const float d = GGML_CPU_FP16_TO_FP32(y[ib].d) * GGML_CPU_FP16_TO_FP32(x[ib].d);
        int sumi1 = 0, sumi2 = 0;
        for (int j = 0; j < QK4_NL/2; ++j) {
            sumi1 += y[ib].qs[j] * kvalues_iq4nl[x[ib].qs[j] & 0xf];
            sumi2 += y[ib].qs[j + QK4_NL/2] * kvalues_iq4nl[x[ib].qs[j] >> 4];
        }
        sumf += d * (sumi1 + sumi2);
    }

    *s = sumf;
}

static NOINLINE void baseline_vl256(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    // Load the lookup table once.
    const vint8mf2_t values = __riscv_vle8_v_i8mf2(kvalues_iq4nl, 16);
    int acc1, acc2;

    // We process 2 blocks at once.
    for (; ib + 1 < nb; ib += 2) {
        // Weights and activations.
        vuint8mf2_t iq4_packed1 = __riscv_vle8_v_u8mf2(x[ib + 0].qs, 16);
        vint8mf2_t q8b_lo1 = __riscv_vle8_v_i8mf2(y[ib + 0].qs, 16);
        vint8mf2_t q8b_hi1 = __riscv_vle8_v_i8mf2(y[ib + 0].qs + 16, 16);
        vuint8mf2_t iq4_packed2 = __riscv_vle8_v_u8mf2(x[ib + 1].qs, 16);
        vint8mf2_t q8b_lo2 = __riscv_vle8_v_i8mf2(y[ib + 1].qs, 16);
        vint8mf2_t q8b_hi2 = __riscv_vle8_v_i8mf2(y[ib + 1].qs + 16, 16);

        // Unpack the weight blocks.
        vuint8mf2_t iq4bits_lo1 = __riscv_vand_vx_u8mf2(iq4_packed1, 0xf, 16);
        vuint8mf2_t iq4bits_hi1 = __riscv_vsrl_vx_u8mf2(iq4_packed1, 4, 16);
        vuint8mf2_t iq4bits_lo2 = __riscv_vand_vx_u8mf2(iq4_packed2, 0xf, 16);
        vuint8mf2_t iq4bits_hi2 = __riscv_vsrl_vx_u8mf2(iq4_packed2, 4, 16);

        // Gather values from the lookup table.
        vint8mf2_t iq4b_lo1 = __riscv_vrgather_vv_i8mf2(values, iq4bits_lo1, 16);
        vint8mf2_t iq4b_hi1 = __riscv_vrgather_vv_i8mf2(values, iq4bits_hi1, 16);
        vint8mf2_t iq4b_lo2 = __riscv_vrgather_vv_i8mf2(values, iq4bits_lo2, 16);
        vint8mf2_t iq4b_hi2 = __riscv_vrgather_vv_i8mf2(values, iq4bits_hi2, 16);

        // Accumulation.
        vint16m1_t sum1 = __riscv_vwmul_vv_i16m1(q8b_lo1, iq4b_lo1, 16);
        sum1 = __riscv_vwmacc_vv_i16m1(sum1, q8b_hi1, iq4b_hi1, 16);
        vint16m1_t sum2 = __riscv_vwmul_vv_i16m1(q8b_lo2, iq4b_lo2, 16);
        sum2 = __riscv_vwmacc_vv_i16m1(sum2, q8b_hi2, iq4b_hi2, 16);
        __riscv_vse32_v_i32m1(&acc1,__riscv_vwredsum_vs_i16m1_i32m1(sum1, __riscv_vmv_v_x_i32m1(0, 1), 16), 1);
        __riscv_vse32_v_i32m1(&acc2,__riscv_vwredsum_vs_i16m1_i32m1(sum2, __riscv_vmv_v_x_i32m1(0, 1), 16), 1);
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 0].d) * GGML_CPU_FP16_TO_FP32(y[ib + 0].d) * acc1));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 1].d) * GGML_CPU_FP16_TO_FP32(y[ib + 1].d) * acc2));
    }

    if (ib < nb) {
        const float d = GGML_CPU_FP16_TO_FP32(y[ib].d) * GGML_CPU_FP16_TO_FP32(x[ib].d);
        int sumi1 = 0, sumi2 = 0;
        for (int j = 0; j < QK4_NL/2; ++j) {
            sumi1 += y[ib].qs[j] * kvalues_iq4nl[x[ib].qs[j] & 0xf];
            sumi2 += y[ib].qs[j + QK4_NL/2] * kvalues_iq4nl[x[ib].qs[j] >> 4];
        }
        sumf += d * (sumi1 + sumi2);
    }

    *s = sumf;
}

__attribute__((noinline)) void baseline(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
#if defined __riscv_v
    switch (__riscv_vlenb() * 8) {
        case 128:
            baseline_vl128(n, s, bs, vx, bx, vy, by, nrc);
            break;
        default: // 256 and above
            baseline_vl256(n, s, bs, vx, bx, vy, by, nrc);
            break;
    }
#else
    ggml_vec_dot_iq4_nl_q8_0_generic(n, s, bs, vx, bx, vy, by, nrc);
#endif
}

static NOINLINE void candidate_vl128(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    // Load the lookup table once.
    const vint8m2_t values = __riscv_vle8_v_i8m2(kvalues_iq4nl, 16);
    int acc1, acc2;

    // We process 2 blocks at once.
    for (; ib + 1 < nb; ib += 2) {
        // Weights and activations.
        vuint8m1_t iq4_packed1 = __riscv_vle8_v_u8m1(x[ib + 0].qs, 16);
        vint8m2_t q8b1 = __riscv_vle8_v_i8m2(y[ib + 0].qs, 32);
        vuint8m1_t iq4_packed2 = __riscv_vle8_v_u8m1(x[ib + 1].qs, 16);
        vint8m2_t q8b2 = __riscv_vle8_v_i8m2(y[ib + 1].qs, 32);

        // Unpack the weight blocks.
        vuint8m2_t iq4bits1 = __riscv_vcreate_v_u8m1_u8m2(
            __riscv_vand_vx_u8m1(iq4_packed1, 0xf, 16),
            __riscv_vsrl_vx_u8m1(iq4_packed1, 4, 16)
        );
        vuint8m2_t iq4bits2 = __riscv_vcreate_v_u8m1_u8m2(
            __riscv_vand_vx_u8m1(iq4_packed2, 0xf, 16),
            __riscv_vsrl_vx_u8m1(iq4_packed2, 4, 16)
        );

        // Gather values from the lookup table.
        vint8m2_t iq4b1 = __riscv_vrgather_vv_i8m2(values, iq4bits1, 32);
        vint8m2_t iq4b2 = __riscv_vrgather_vv_i8m2(values, iq4bits2, 32);

        // Accumulation.
        vint16m4_t sum1 = __riscv_vwmul_vv_i16m4(q8b1, iq4b1, 32);
        vint16m4_t sum2 = __riscv_vwmul_vv_i16m4(q8b2, iq4b2, 32);
        acc1 = __riscv_vmv_x_s_i32m1_i32(__riscv_vwredsum_vs_i16m4_i32m1(sum1, __riscv_vmv_v_x_i32m1(0, 1), 32));
        acc2 = __riscv_vmv_x_s_i32m1_i32(__riscv_vwredsum_vs_i16m4_i32m1(sum2, __riscv_vmv_v_x_i32m1(0, 1), 32));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 0].d) * GGML_CPU_FP16_TO_FP32(y[ib + 0].d) * acc1));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 1].d) * GGML_CPU_FP16_TO_FP32(y[ib + 1].d) * acc2));
    }

    if (ib < nb) {
        const float d = GGML_CPU_FP16_TO_FP32(y[ib].d) * GGML_CPU_FP16_TO_FP32(x[ib].d);
        int sumi1 = 0, sumi2 = 0;
        for (int j = 0; j < QK4_NL/2; ++j) {
            sumi1 += y[ib].qs[j] * kvalues_iq4nl[x[ib].qs[j] & 0xf];
            sumi2 += y[ib].qs[j + QK4_NL/2] * kvalues_iq4nl[x[ib].qs[j] >> 4];
        }
        sumf += d * (sumi1 + sumi2);
    }

    *s = sumf;
}

static NOINLINE void candidate_vl256(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
    assert(nrc == 1);
    UNUSED(nrc);
    UNUSED(bx);
    UNUSED(by);
    UNUSED(bs);
    assert(n % QK4_NL == 0);
    static_assert(QK4_NL == QK8_0, "QK4_NL and QK8_0 must be the same");

    const block_iq4_nl * GGML_RESTRICT x = vx;
    const block_q8_0   * GGML_RESTRICT y = vy;

    const int nb = n / QK4_NL;

    int ib = 0;
    float sumf = 0;

    // Load the lookup table once.
    const vint8mf2_t values = __riscv_vle8_v_i8mf2(kvalues_iq4nl, 16);
    int acc1, acc2;

    // We process 2 blocks at once.
    for (; ib + 1 < nb; ib += 2) {
        // Weights and activations.
        vuint8mf2_t iq4_packed1 = __riscv_vle8_v_u8mf2(x[ib + 0].qs, 16);
        vint8mf2_t q8b_lo1 = __riscv_vle8_v_i8mf2(y[ib + 0].qs, 16);
        vint8mf2_t q8b_hi1 = __riscv_vle8_v_i8mf2(y[ib + 0].qs + 16, 16);
        vuint8mf2_t iq4_packed2 = __riscv_vle8_v_u8mf2(x[ib + 1].qs, 16);
        vint8mf2_t q8b_lo2 = __riscv_vle8_v_i8mf2(y[ib + 1].qs, 16);
        vint8mf2_t q8b_hi2 = __riscv_vle8_v_i8mf2(y[ib + 1].qs + 16, 16);

        // Unpack the weight blocks.
        vuint8mf2_t iq4bits_lo1 = __riscv_vand_vx_u8mf2(iq4_packed1, 0xf, 16);
        vuint8mf2_t iq4bits_hi1 = __riscv_vsrl_vx_u8mf2(iq4_packed1, 4, 16);
        vuint8mf2_t iq4bits_lo2 = __riscv_vand_vx_u8mf2(iq4_packed2, 0xf, 16);
        vuint8mf2_t iq4bits_hi2 = __riscv_vsrl_vx_u8mf2(iq4_packed2, 4, 16);

        // Gather values from the lookup table.
        vint8mf2_t iq4b_lo1 = __riscv_vrgather_vv_i8mf2(values, iq4bits_lo1, 16);
        vint8mf2_t iq4b_hi1 = __riscv_vrgather_vv_i8mf2(values, iq4bits_hi1, 16);
        vint8mf2_t iq4b_lo2 = __riscv_vrgather_vv_i8mf2(values, iq4bits_lo2, 16);
        vint8mf2_t iq4b_hi2 = __riscv_vrgather_vv_i8mf2(values, iq4bits_hi2, 16);

        // Accumulation.
        vint16m1_t sum1 = __riscv_vwmul_vv_i16m1(q8b_lo1, iq4b_lo1, 16);
        sum1 = __riscv_vwmacc_vv_i16m1(sum1, q8b_hi1, iq4b_hi1, 16);
        vint16m1_t sum2 = __riscv_vwmul_vv_i16m1(q8b_lo2, iq4b_lo2, 16);
        sum2 = __riscv_vwmacc_vv_i16m1(sum2, q8b_hi2, iq4b_hi2, 16);
        acc1 = __riscv_vmv_x_s_i32m1_i32(__riscv_vwredsum_vs_i16m1_i32m1(sum1, __riscv_vmv_v_x_i32m1(0, 1), 16));
        acc2 = __riscv_vmv_x_s_i32m1_i32(__riscv_vwredsum_vs_i16m1_i32m1(sum2, __riscv_vmv_v_x_i32m1(0, 1), 16));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 0].d) * GGML_CPU_FP16_TO_FP32(y[ib + 0].d) * acc1));
        sumf += ((GGML_CPU_FP16_TO_FP32(x[ib + 1].d) * GGML_CPU_FP16_TO_FP32(y[ib + 1].d) * acc2));
    }

    if (ib < nb) {
        const float d = GGML_CPU_FP16_TO_FP32(y[ib].d) * GGML_CPU_FP16_TO_FP32(x[ib].d);
        int sumi1 = 0, sumi2 = 0;
        for (int j = 0; j < QK4_NL/2; ++j) {
            sumi1 += y[ib].qs[j] * kvalues_iq4nl[x[ib].qs[j] & 0xf];
            sumi2 += y[ib].qs[j + QK4_NL/2] * kvalues_iq4nl[x[ib].qs[j] >> 4];
        }
        sumf += d * (sumi1 + sumi2);
    }

    *s = sumf;
}

__attribute__((noinline)) void candidate(int n, float * GGML_RESTRICT s, size_t bs, const void * GGML_RESTRICT vx, size_t bx, const void * GGML_RESTRICT vy, size_t by, int nrc) {
#if defined __riscv_v
    switch (__riscv_vlenb() * 8) {
        case 128:
            candidate_vl128(n, s, bs, vx, bx, vy, by, nrc);
            break;
        default: // 256 and above
            candidate_vl256(n, s, bs, vx, bx, vy, by, nrc);
            break;
    }
#else
    ggml_vec_dot_iq4_nl_q8_0_generic(n, s, bs, vx, bx, vy, by, nrc);
#endif
}
