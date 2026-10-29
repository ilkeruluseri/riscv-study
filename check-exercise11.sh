#!/bin/sh

set -eu

compiler=${CC:-riscv64-linux-gnu-gcc}
emulator=${QEMU:-qemu-riscv64}
binary=exercise11
assembly=exercise11.s
function_assembly=$(mktemp)
trap 'rm -f "$function_assembly"' EXIT HUP INT TERM

common_flags="-O2 -fno-tree-vectorize -Wall -Wextra -Wpedantic -Werror -march=rv64gcv -mabi=lp64d"

echo "Compiling exercise 11"
# Word splitting is intentional: CC and the flags may contain multiple arguments.
# shellcheck disable=SC2086
$compiler $common_flags exercise11.c -o "$binary"

for vlen in 128 256; do
    echo "Running with VLEN=$vlen"
    "$emulator" \
        -L /usr/riscv64-linux-gnu \
        -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" \
        "./$binary"
done

echo "Inspecting dot_i8_rvv assembly"
# shellcheck disable=SC2086
$compiler $common_flags -fno-inline -S exercise11.c -o "$assembly"
sed -n \
    '/^dot_i8_rvv:/,/^[[:space:]]*\.size[[:space:]]*dot_i8_rvv/p' \
    "$assembly" > "$function_assembly"

check_instruction() {
    description=$1
    pattern=$2

    if ! grep -Eq "$pattern" "$function_assembly"; then
        echo "Missing $description in dot_i8_rvv assembly" >&2
        return 1
    fi
}

check_instruction "vector-length configuration" 'vset(i)?vli.*e8,m1'
check_instruction "8-bit vector loads" 'vle8\.v'
check_instruction "signed widening multiplication" 'vwmul\.vv'
check_instruction "widening reduction sum" 'vwredsum\.vs'
check_instruction "scalar extraction" 'vmv\.x\.s'

echo "Exercise 11 runtime and assembly checks passed"
