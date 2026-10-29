#!/bin/sh
set -eu
cd "$(dirname "$0")"
compiler=${CC:-riscv64-linux-gnu-gcc}
optimization=${OPT:-O2}
case "$optimization" in O2|O3) ;; *) echo "OPT must be O2 or O3" >&2; exit 2 ;; esac
mkdir -p results
python3 prepare.py --generate
{
    "$compiler" --version
    printf '%s\n' "-$optimization -g -Wall -Wextra -Wpedantic -Werror -Wno-unused-function -march=rv64gcv -mabi=lp64d"
} > "results/build-$optimization.txt"
"$compiler" "-$optimization" -g -Wall -Wextra -Wpedantic -Werror -Wno-unused-function \
    -march=rv64gcv -mabi=lp64d -Isource/ggml/src -Isource/ggml/include \
    study.c -o "results/study-$optimization" -lm
python3 inspect.py "results/study-$optimization" > "results/assembly-$optimization.log"
sha256sum "results/study-$optimization" >> "results/build-$optimization.txt"
