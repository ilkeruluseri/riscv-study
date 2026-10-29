#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

struct vec4_i32 {
    int32_t lane[4];
};

struct vec4_i32 vec4_load(const int32_t *source) {
    struct vec4_i32 result = { { 0, 0, 0, 0 } };
    for (int i = 0; i < 4; i++) {
        result.lane[i] = source[i];
    }
    return result;
}

struct vec4_i32 vec4_add(struct vec4_i32 left, struct vec4_i32 right) {
    struct vec4_i32 result = { { 0, 0, 0, 0 } };
    for (int i = 0; i < 4; i++) {
        result.lane[i] = left.lane[i] + right.lane[i];
    }
    return result;
}

void vec4_store(int32_t *destination, struct vec4_i32 value) {
    for (int i = 0; i < 4; i++) {
        destination[i] = value.lane[i];
    }
}

void add_i32_vec4(const int32_t *a,
                  const int32_t *b,
                  int32_t *result,
                  size_t n) {
    struct vec4_i32 vec_result;
    for (size_t i = 0; i + 3 < n; i += 4) {
        struct vec4_i32 vec1 = vec4_load(a + i);
        struct vec4_i32 vec2 = vec4_load(b + i);

        vec_result = vec4_add(vec1, vec2);
        vec4_store(result+i, vec_result);
    }
    switch (n % 4) {
        case 0:
            break;
        case 1:
            result[n - 1] = a[n - 1] + b[n - 1];
            break;
        case 2:
            result[n - 1] = a[n - 1] + b[n - 1];
            result[n - 2] = a[n - 2] + b[n - 2];
            break;
        case 3:
            result[n - 1] = a[n - 1] + b[n - 1];
            result[n - 2] = a[n - 2] + b[n - 2];
            result[n - 3] = a[n - 3] + b[n - 3];
            break;

    }
}

static int check_vector_primitives(void) {
    static const int32_t left_values[4] = { -20, 30, 0, 1000 };
    static const int32_t right_values[4] = { 7, -50, 12, 234 };
    static const int32_t expected[4] = { -13, -20, 12, 1234 };
    int32_t actual[4] = { 0, 0, 0, 0 };
    const struct vec4_i32 left = vec4_load(left_values);
    const struct vec4_i32 right = vec4_load(right_values);
    const struct vec4_i32 sum = vec4_add(left, right);
    int failures = 0;

    vec4_store(actual, sum);

    for (size_t lane = 0; lane < 4; lane++) {
        if (actual[lane] != expected[lane]) {
            fprintf(stderr,
                    "primitive lane %zu: expected %" PRId32 ", got %" PRId32 "\n",
                    lane,
                    expected[lane],
                    actual[lane]);
            failures++;
        }
    }

    return failures;
}

static int check_array_addition(void) {
    static const size_t sizes[] = {
        0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33,
    };
    static const int32_t untouched = INT32_C(0x55555555);
    int failures = 0;

    for (size_t test = 0; test < sizeof(sizes) / sizeof(sizes[0]); test++) {
        const size_t n = sizes[test];
        int32_t a[33];
        int32_t b[33];
        int32_t result[33];

        for (size_t i = 0; i < 33; i++) {
            a[i] = (int32_t) (3 * i) - 50;
            b[i] = 80 - (int32_t) (2 * i);
            result[i] = untouched;
        }

        add_i32_vec4(a, b, result, n);

        for (size_t i = 0; i < n; i++) {
            const int32_t expected = a[i] + b[i];

            if (result[i] != expected) {
                fprintf(stderr,
                        "n=%zu, index=%zu: expected %" PRId32 ", got %" PRId32 "\n",
                        n,
                        i,
                        expected,
                        result[i]);
                failures++;
            }
        }

        for (size_t i = n; i < 33; i++) {
            if (result[i] != untouched) {
                fprintf(stderr,
                        "n=%zu: result[%zu] was modified past the requested length\n",
                        n,
                        i);
                failures++;
            }
        }
    }

    return failures;
}

int main(void) {
    const int failures = check_vector_primitives() + check_array_addition();

    if (failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }

    puts("All fake-vector checks passed");
    return 0;
}
