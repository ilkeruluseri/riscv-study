#!/bin/sh

set -eu

compiler=${CC:-riscv64-linux-gnu-gcc}
emulator=${QEMU:-qemu-riscv64}
binary=exercise9
assembly=exercise9.s
function_assembly=$(mktemp)
trap 'rm -f "$function_assembly"' EXIT HUP INT TERM

common_flags="-O2 -fno-tree-vectorize -Wall -Wextra -Wpedantic -Werror -march=rv64gcv -mabi=lp64d"

echo "Compiling exercise 9"
# Word splitting is intentional: CC and the flags may contain multiple arguments.
# shellcheck disable=SC2086
$compiler $common_flags exercise9.c -o "$binary"

for vlen in 128 256; do
    echo "Running with VLEN=$vlen"
    "$emulator" \
        -L /usr/riscv64-linux-gnu \
        -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" \
        "./$binary"
done

echo "Inspecting multiply_scalar_i32 assembly"
# shellcheck disable=SC2086
$compiler $common_flags -fno-inline -S exercise9.c -o "$assembly"
sed -n \
    '/^multiply_scalar_i32:/,/^[[:space:]]*\.size[[:space:]]*multiply_scalar_i32/p' \
    "$assembly" > "$function_assembly"

check_instruction() {
    description=$1
    pattern=$2

    if ! grep -Eq "$pattern" "$function_assembly"; then
        echo "Missing $description in multiply_scalar_i32 assembly" >&2
        return 1
    fi
}

check_instruction "vector-length configuration" 'vset(i)?vli.*e32,m1'
check_instruction "32-bit vector load" 'vle32\.v'
check_instruction "vector-scalar multiplication" 'vmul\.vx'
check_instruction "32-bit vector store" 'vse32\.v'

echo "Exercise 9 runtime and assembly checks passed"
