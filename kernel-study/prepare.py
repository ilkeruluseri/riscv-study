"""Freeze the pinned inputs and generate narrowly transformed kernel variants."""

import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REVISION = "31385c9cebf9e5271a38e14c26e5df6dd93718b1"
RV = "ggml/src/ggml-cpu/arch/riscv/quants.c"
GENERIC = "ggml/src/ggml-cpu/quants.c"
NAME = "ggml_vec_dot_iq4_nl_q8_0"
HEADERS = ["ggml/src/ggml-common.h", "ggml/src/ggml-quants.h",
           "ggml/src/ggml-impl.h", "ggml/include/ggml.h", "ggml/include/gguf.h"]


def extract(source, name):
    match = re.search(r"^(?:static NOINLINE )?void " + re.escape(name) + r"\(",
                      source, re.MULTILINE)
    if match is None:
        raise ValueError(f"Function not found: {name}")
    brace = source.index("{", match.start())
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[match.start():end]


TAIL = """    if (ib < nb) {
        const float d = GGML_CPU_FP16_TO_FP32(y[ib].d) * GGML_CPU_FP16_TO_FP32(x[ib].d);
        int sumi1 = 0, sumi2 = 0;
        for (int j = 0; j < QK4_NL/2; ++j) {
            sumi1 += y[ib].qs[j] * kvalues_iq4nl[x[ib].qs[j] & 0xf];
            sumi2 += y[ib].qs[j + QK4_NL/2] * kvalues_iq4nl[x[ib].qs[j] >> 4];
        }
        sumf += d * (sumi1 + sumi2);
    }

"""


def variants(rv):
    corrected = rv
    for suffix in ("_vl128", "_vl256"):
        old = extract(rv, NAME + suffix)
        if old.count("    *s = sumf;") != 1:
            raise ValueError("Unexpected return structure")
        new = old.replace("    *s = sumf;", TAIL + "    *s = sumf;")
        corrected = corrected.replace(old, new, 1)
    candidate = corrected
    for suffix, group, lanes in (("_vl128", "m4", 32), ("_vl256", "m1", 16)):
        old = extract(corrected, NAME + suffix)
        new = old
        for number in (1, 2):
            reduction = (f"__riscv_vwredsum_vs_i16{group}_i32m1(sum{number}, "
                         f"__riscv_vmv_v_x_i32m1(0, 1), {lanes})")
            store = f"__riscv_vse32_v_i32m1(&acc{number},{reduction}, 1);"
            if new.count(store) != 1:
                raise ValueError(f"Unexpected extraction for {suffix}, accumulator {number}")
            new = new.replace(store,
                              f"acc{number} = __riscv_vmv_x_s_i32m1_i32({reduction});")
        candidate = candidate.replace(old, new, 1)
    return corrected, candidate


def patch(before, after, output):
    output.write_text("".join(difflib.unified_diff(
        before.splitlines(True), after.splitlines(True),
        fromfile="a/" + RV, tofile="b/" + RV)))


def generate():
    source = HERE / "source"
    manifest = json.loads((HERE / "source-manifest.json").read_text())
    for path, expected in manifest["sha256"].items():
        if hashlib.sha256((source / path).read_bytes()).hexdigest() != expected:
            raise ValueError("Frozen source checksum mismatch: " + path)
    rv = (source / RV).read_text()
    generic = extract((source / GENERIC).read_text(), NAME + "_generic")
    corrected, candidate = variants(rv)
    patch(rv, corrected, HERE / "01-common-tail.patch")
    patch(corrected, candidate, HERE / "02-scalar-extraction.patch")
    chunks = [generic]
    for label, text in (("original", rv), ("baseline", corrected), ("candidate", candidate)):
        for suffix in ("_vl128", "_vl256", ""):
            function = extract(text, NAME + suffix)
            function = function.replace(NAME, label)
            function = function.replace(label + "_generic", NAME + "_generic")
            if not suffix:
                function = "__attribute__((noinline)) " + function
            chunks.append(function)
    (HERE / "kernels.inc").write_text("\n\n".join(chunks) + "\n")
    mappings = (source / "ggml/src/ggml-cpu/simd-mappings.h").read_text()
    start = mappings.index("inline static float ggml_lookup_fp16_to_fp32(")
    end = mappings.index("\n#endif", start)
    (HERE / "conversion.inc").write_text(mappings[start:end] + "\n")


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--generate":
        generate()
        return
    if len(sys.argv) != 2:
        raise SystemExit("usage: python3 prepare.py LLAMA_SOURCE | --generate")
    root = Path(sys.argv[1]).resolve()
    if subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip() != REVISION:
        raise SystemExit("Source checkout must be at pinned revision " + REVISION)
    paths = [RV, GENERIC, *HEADERS, "LICENSE", "ggml/src/ggml-cpu/ggml-cpu.c",
             "ggml/src/ggml-cpu/simd-mappings.h",
             "tools/llama-bench/README.md"]
    hashes = {}
    for path in paths:
        data = (root / path).read_bytes()
        committed = subprocess.check_output(["git", "-C", str(root), "show", REVISION + ":" + path])
        if data != committed:
            raise SystemExit("Refusing modified source: " + path)
        destination = HERE / "source" / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        hashes[path] = hashlib.sha256(data).hexdigest()
    (HERE / "source-manifest.json").write_text(json.dumps(
        {"revision": REVISION, "source_root": str(root), "sha256": hashes}, indent=2) + "\n")
    generate()
    print("Frozen pinned sources; generated original, corrected baseline, and candidate")


if __name__ == "__main__":
    main()
