#!/bin/sh
set -eu
cd "$(dirname "$0")"
llama_source=${LLAMA_SOURCE:-/home/ilker-pc/llama.cpp}
python3 extract.py "$llama_source"
riscv64-linux-gnu-gcc -O2 -Wall -Wextra -Wno-unused-function -Werror \
    -march=rv64gcv -mabi=lp64d \
    -I "$llama_source/ggml/src" -I "$llama_source/ggml/include" \
    repro.c -o repro
status=0
for vlen in 128 256; do
    if qemu-riscv64 -L /usr/riscv64-linux-gnu \
        -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" ./repro; then
        :
    else
        result=$?
        status=$result
        if [ "$result" -ne 1 ]; then
            exit "$result"
        fi
    fi
done
exit "$status"
