#!/bin/sh

set -eu

compiler=${CC:-riscv64-linux-gnu-gcc}
emulator=${QEMU:-qemu-riscv64}
binary=exercise8
assembly=exercise8.s
function_assembly=$(mktemp)
trap 'rm -f "$function_assembly"' EXIT HUP INT TERM

common_flags="-O2 -fno-tree-vectorize -Wall -Wextra -Wpedantic -Werror -march=rv64gcv -mabi=lp64d"

echo "Compiling exercise 8"
# Word splitting is intentional: CC and the flags may contain multiple arguments.
# shellcheck disable=SC2086
$compiler $common_flags exercise8.c -o "$binary"

for vlen in 128 256; do
    echo "Running with VLEN=$vlen"
    "$emulator" \
        -L /usr/riscv64-linux-gnu \
        -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" \
        "./$binary"
done

echo "Inspecting VL-selector assembly"
# shellcheck disable=SC2086
$compiler $common_flags -fno-inline -S exercise8.c -o "$assembly"

check_selector() {
    function_name=$1
    configuration=$2

    sed -n \
        "/^${function_name}:/,/^[[:space:]]*\\.size[[:space:]]*${function_name}/p" \
        "$assembly" > "$function_assembly"

    if ! grep -Eq "vset(i)?vli.*${configuration}" "$function_assembly"; then
        echo "Missing ${configuration} VL configuration in ${function_name}" >&2
        return 1
    fi
}

check_selector select_vl_e32m1 'e32,m1'
check_selector select_vl_e8m1 'e8,m1'

echo "Exercise 8 runtime and assembly checks passed"
