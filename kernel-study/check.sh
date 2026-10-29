#!/bin/sh
set -eu
cd "$(dirname "$0")"
emulator=${QEMU:-qemu-riscv64}
mkdir -p results
"$emulator" --version > results/qemu-version.txt
for optimization in O2 O3; do
    OPT=$optimization sh build.sh
    for vlen in 128 256 512; do
        log="results/check-$optimization-vlen$vlen.log"
        "$emulator" -L /usr/riscv64-linux-gnu \
            -cpu "max,vlen=$vlen,elen=64,vext_spec=v1.0" \
            "./results/study-$optimization" > "$log" 2>&1
        cat "$log"
    done
done
python3 verify_artifacts.py
# These samples test CSV and timing plumbing only. They are not performance evidence.
"$emulator" -L /usr/riscv64-linux-gnu \
    -cpu max,vlen=128,elen=64,vext_spec=v1.0 \
    ./results/study-O2 --bench 3 2 > results/emulated-benchmark-SMOKE-ONLY.csv \
    2> results/emulated-benchmark-SMOKE-ONLY.log
python3 summarize.py results/emulated-benchmark-SMOKE-ONLY.csv --smoke
