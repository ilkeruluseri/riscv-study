// Serialize actual GGML operations for upstream test-backend-ops --test-file.
#include "ggml.h"

#include <cstdint>
#include <iostream>
#include <string>

static void emit(const std::string & id, ggml_tensor * output) {
    std::cout << id << '\t' << ggml_op_name(output->op) << '\t';
    std::cout << output->op << ' ' << output->type << ' ';
    for (auto dimension : output->ne) {
        std::cout << dimension << ' ';
    }
    constexpr size_t count = GGML_MAX_OP_PARAMS / sizeof(int32_t);
    std::cout << count << ' ';
    for (size_t i = 0; i < count; ++i) {
        std::cout << output->op_params[i] << ' ';
    }
    size_t sources = 0;
    while (sources < GGML_MAX_SRC && output->src[sources]) {
        ++sources;
    }
    std::cout << sources << ' ';
    for (size_t i = 0; i < sources; ++i) {
        auto * source = output->src[i];
        std::cout << source->type << ' ';
        for (auto dimension : source->ne) {
            std::cout << dimension << ' ';
        }
        for (auto stride : source->nb) {
            std::cout << stride << ' ';
        }
    }
    std::cout << id << '\n';
}

int main() {
    ggml_init_params params = {1024 * 1024, nullptr, true};
    auto * context = ggml_init(params);
    if (!context) {
        std::cerr << "Unable to allocate GGML metadata\n";
        return 1;
    }
    for (int width : {31, 32, 33, 896, 4096}) {
        for (int rows : {1, 8}) {
            if (rows == 8 && width < 896) {
                continue;
            }
            auto * input = ggml_new_tensor_2d(context, GGML_TYPE_F32, width, rows);
            emit("rms-f32-k" + std::to_string(width) + "-n" + std::to_string(rows),
                 ggml_rms_norm(context, input, 1e-6f));
        }
    }
    for (auto type : {GGML_TYPE_Q8_0, GGML_TYPE_Q4_0, GGML_TYPE_IQ4_NL}) {
        for (int width : {896, 4096}) {
            for (int tokens : {1, 8}) {
                if (width == 4096 && tokens == 8) {
                    continue;
                }
                auto * weights = ggml_new_tensor_2d(context, type, width, 64);
                auto * input = ggml_new_tensor_2d(context, GGML_TYPE_F32, width, tokens);
                emit("mat-" + std::string(ggml_type_name(type)) + "-m64-k" +
                     std::to_string(width) + "-n" + std::to_string(tokens),
                     ggml_mul_mat(context, weights, input));
            }
        }
    }
    ggml_free(context);
    return std::cout ? 0 : 1;
}
