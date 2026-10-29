#ifndef RVV_INTRINSICS_INTELLISENSE_H
#define RVV_INTRINSICS_INTELLISENSE_H

/*
 * VS Code's C/C++ parser does not expand GCC's
 *   #pragma riscv intrinsic "vector"
 * so provide editor-only declarations for the intrinsics used here.
 * This file is forced into IntelliSense by c_cpp_properties.json; the real
 * compiler continues to get its declarations from <riscv_vector.h>.
 */
#include <riscv_vector.h>

size_t __riscv_vsetvl_e8m1(size_t avl);
size_t __riscv_vsetvl_e32m1(size_t avl);
size_t __riscv_vsetvlmax_e8m1(void);
size_t __riscv_vsetvlmax_e32m1(void);

vint8m1_t __riscv_vle8_v_i8m1(const int8_t *base, size_t vl);
vuint8m1_t __riscv_vle8_v_u8m1(const uint8_t *base, size_t vl);
vint32m1_t __riscv_vle32_v_i32m1(const int32_t *base, size_t vl);
void __riscv_vse8_v_i8m1(int8_t *base, vint8m1_t value, size_t vl);
void __riscv_vse8_v_u8m1(uint8_t *base, vuint8m1_t value, size_t vl);
void __riscv_vse32_v_i32m1(int32_t *base, vint32m1_t value, size_t vl);

vint32m1_t __riscv_vadd_vv_i32m1(
    vint32m1_t left, vint32m1_t right, size_t vl);
vint32m1_t __riscv_vmul_vx_i32m1(
    vint32m1_t vector, int32_t scalar, size_t vl);
vint16m2_t __riscv_vwmul_vv_i16m2(
    vint8m1_t left, vint8m1_t right, size_t vl);
vuint8m1_t __riscv_vand_vx_u8m1(
    vuint8m1_t vector, uint8_t scalar, size_t vl);
vuint8m1_t __riscv_vsrl_vx_u8m1(
    vuint8m1_t vector, size_t shift, size_t vl);
vint8m1_t __riscv_vrgather_vv_i8m1(
    vint8m1_t values, vuint8m1_t indices, size_t vl);

vint32m1_t __riscv_vmv_v_x_i32m1(int32_t scalar, size_t vl);
vint32m1_t __riscv_vredsum_vs_i32m1_i32m1(
    vint32m1_t values, vint32m1_t seed, size_t vl);
vint32m1_t __riscv_vwredsum_vs_i16m2_i32m1(
    vint16m2_t values, vint32m1_t seed, size_t vl);
int32_t __riscv_vmv_x_s_i32m1_i32(vint32m1_t value);

#endif
