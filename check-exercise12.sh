#!/bin/sh

set -eu

compiler=${CC:-riscv64-linux-gnu-gcc}
emulator=${QEMU:-qemu-riscv64}
binary=exercise12
assembly=exercise12.s
function_assembly=$(mktemp)
trap 'rm -f "$function_assembly"' EXIT HUP INT TERM

common_flags="-O2 -fno-tree-vectorize -Wall -Wextra -Wpedantic -Werror -march=rv64gcv -mabi=lp64d"

echo "Compiling exercise 12"
# Word splitting is intentional: CC and the flags may contain multiple arguments.
# shellcheck disable=SC2086
$compiler $common_flags exercise12.c -o "$binary"

for vlen in 128 256; do
    echo "Running with VLEN=$vlen"
    "$emulator" \
        -L /usr/riscv64-linux-gnu \
        -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" \
        "./$binary"
done

echo "Inspecting unpack_nibbles_rvv assembly"
# shellcheck disable=SC2086
$compiler $common_flags -fno-inline -S exercise12.c -o "$assembly"
sed -n \
    '/^unpack_nibbles_rvv:/,/^[[:space:]]*\.size[[:space:]]*unpack_nibbles_rvv/p' \
    "$assembly" > "$function_assembly"

check_instruction() {
    description=$1
    pattern=$2

    if ! grep -Eq "$pattern" "$function_assembly"; then
        echo "Missing $description in unpack_nibbles_rvv assembly" >&2
        return 1
    fi
}

check_count() {
    description=$1
    pattern=$2
    minimum=$3
    count=$(grep -Ec "$pattern" "$function_assembly" || true)

    if [ "$count" -lt "$minimum" ]; then
        echo "Expected at least $minimum $description in unpack_nibbles_rvv assembly, found $count" >&2
        return 1
    fi
}

check_instruction "vector-length configuration" 'vset(i)?vli.*e8,m1'
check_instruction "8-bit vector load" 'vle8\.v'
check_instruction "vector AND" 'vand\.v(x|i)'
check_instruction "logical vector shift" 'vsrl\.v(x|i)'
check_count "8-bit vector stores" 'vse8\.v' 2

echo "Exercise 12 runtime and assembly checks passed"
