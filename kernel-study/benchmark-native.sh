#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ "$(uname -m)" != riscv64 ]; then
    echo "Run this script on a real RV64 Linux machine with RVV 1.0." >&2
    exit 2
fi
export CC=${CC:-gcc}
export OBJDUMP=${OBJDUMP:-objdump}
export OPT=${OPT:-O2}
sh build.sh
run_dir="results/native-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$run_dir"
cp "results/study-$OPT" "results/build-$OPT.txt" \
    "results/study-$OPT-assembly.json" "$run_dir/"
python3 measure.py doctor --output "$run_dir/environment.json"
taskset -c "${CPU:-0}" "$run_dir/study-$OPT" > "$run_dir/correctness.log" 2>&1
python3 measure.py run --kind native --output-dir "$run_dir/capture" \
    --artifact "$run_dir/study-$OPT" --artifact "$run_dir/build-$OPT.txt" \
    --artifact "$run_dir/study-$OPT-assembly.json" --artifact "$run_dir/correctness.log" \
    --artifact source-manifest.json --artifact study.c --artifact kernels.inc \
    --artifact conversion.inc --artifact 01-common-tail.patch --artifact 02-scalar-extraction.patch \
    -- taskset -c "${CPU:-0}" "$run_dir/study-$OPT" --bench \
    "${ITERATIONS:-10000}" "${SAMPLES:-21}"
cp "$run_dir/capture/rep-001.stdout" "$run_dir/samples.csv"
cp "$run_dir/capture/rep-001.stderr" "$run_dir/benchmark.log"
python3 summarize.py "$run_dir/samples.csv" > "$run_dir/summary.txt"
cat "$run_dir/summary.txt"
printf 'Artifacts: %s\n' "$run_dir"
