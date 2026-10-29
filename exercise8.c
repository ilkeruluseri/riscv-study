#include <stddef.h>
#include <stdio.h>

#include <riscv_vector.h>

typedef size_t (*vl_selector)(size_t remaining);

size_t select_vl_e32m1(size_t remaining) {
    /* TODO: select VL for 32-bit elements with LMUL=1. */
    return __riscv_vsetvl_e32m1(remaining);
}

size_t select_vl_e8m1(size_t remaining) {
    return __riscv_vsetvl_e8m1(remaining);
}

static int validate_trace(const char *name,
                          size_t n,
                          size_t vlmax,
                          vl_selector select_vl,
                          int print_values) {
    size_t remaining = n;
    size_t iterations = 0;

    if (print_values) {
        printf("%s (n=%zu, VLMAX=%zu):", name, n, vlmax);
    }

    while (remaining != 0) {
        const size_t vl = select_vl(remaining);

        if (vl == 0 || vl > remaining || vl > vlmax) {
            fprintf(stderr,
                    "%s: invalid vl=%zu with remaining=%zu and VLMAX=%zu\n",
                    name,
                    vl,
                    remaining,
                    vlmax);
            return 1;
        }

        if (print_values) {
            printf(" %zu", vl);
        }

        remaining -= vl;
        iterations++;

        if (iterations > n) {
            fprintf(stderr, "%s: trace did not make progress\n", name);
            return 1;
        }
    }

    if (print_values) {
        putchar('\n');
    }

    return 0;
}

static int validate_awkward_sizes(const char *name,
                                  size_t vlmax,
                                  vl_selector select_vl) {
    static const size_t sizes[] = {
        0, 1, 2, 3, 7, 15, 16, 17, 31, 32, 33, 37,
    };
    int failures = 0;

    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        const int failed = validate_trace(
            name, sizes[i], vlmax, select_vl, 0);

        failures += failed;
        if (failed) {
            break;
        }
    }

    return failures;
}

int main(void) {
    const size_t e32m1_vlmax = __riscv_vsetvlmax_e32m1();
    const size_t e8m1_vlmax = __riscv_vsetvlmax_e8m1();
    int failures = 0;

    failures += validate_awkward_sizes(
        "SEW=32, LMUL=1", e32m1_vlmax, select_vl_e32m1);
    failures += validate_awkward_sizes(
        "SEW=8, LMUL=1", e8m1_vlmax, select_vl_e8m1);

    if (failures != 0) {
        fprintf(stderr, "%d VL trace check(s) failed\n", failures);
        return 1;
    }

    failures += validate_trace(
        "SEW=32, LMUL=1", 37, e32m1_vlmax, select_vl_e32m1, 1);
    failures += validate_trace(
        "SEW=8, LMUL=1", 37, e8m1_vlmax, select_vl_e8m1, 1);

    if (failures != 0) {
        fprintf(stderr, "%d VL trace check(s) failed\n", failures);
        return 1;
    }

    return 0;
}
