#!/bin/sh

set -eu

compiler=${CC:-riscv64-linux-gnu-gcc}
emulator=${QEMU:-qemu-riscv64}
binary=exercise7
assembly=exercise7.s
function_assembly=$(mktemp)
trap 'rm -f "$function_assembly"' EXIT HUP INT TERM

common_flags="-O2 -fno-tree-vectorize -Wall -Wextra -Wpedantic -Werror -march=rv64gcv -mabi=lp64d"

echo "Compiling exercise 7"
# Word splitting is intentional: CC and the flags may contain multiple arguments.
# shellcheck disable=SC2086
$compiler $common_flags exercise7.c -o "$binary"

for vlen in 128 256; do
    echo "Running with VLEN=$vlen"
    "$emulator" \
        -L /usr/riscv64-linux-gnu \
        -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" \
        "./$binary"
done

echo "Inspecting add_i32_rvv assembly"
# shellcheck disable=SC2086
$compiler $common_flags -fno-inline -S exercise7.c -o "$assembly"
sed -n '/^add_i32_rvv:/,/^[[:space:]]*\.size[[:space:]]*add_i32_rvv/p' \
    "$assembly" > "$function_assembly"

check_instruction() {
    description=$1
    pattern=$2

    if ! grep -Eq "$pattern" "$function_assembly"; then
        echo "Missing $description in add_i32_rvv assembly" >&2
        return 1
    fi
}

check_instruction "vector-length configuration" 'vset(i)?vli'
check_instruction "32-bit vector load" 'vle32\.v'
check_instruction "vector-vector addition" 'vadd\.vv'
check_instruction "32-bit vector store" 'vse32\.v'

echo "Exercise 7 runtime and assembly checks passed"
