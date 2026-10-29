"""Check patch applicability and demonstrate that the harness rejects a bad candidate."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import prepare


def main():
    root = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="patch-check-", dir=root / "results") as directory:
        directory = Path(directory)
        destination = directory / prepare.RV
        destination.parent.mkdir(parents=True)
        shutil.copy2(root / "source" / prepare.RV, destination)
        logs = []
        for patch in ("01-common-tail.patch", "02-scalar-extraction.patch"):
            result = subprocess.run(
                ["patch", "--batch", "--fuzz=0", "-p1", "-d", str(directory),
                 "-i", str(root / patch)], check=True, capture_output=True, text=True)
            logs.append(result.stdout)
        _, expected = prepare.variants((root / "source" / prepare.RV).read_text())
        if destination.read_text() != expected:
            raise SystemExit("Applied patches do not reconstruct candidate")
        (root / "results/patch-check.log").write_text(
            "".join(logs) + "PASS: patches apply without fuzz and reconstruct candidate source\n")

    with tempfile.TemporaryDirectory(prefix="mutation-check-", dir=root / "results") as directory:
        directory = Path(directory)
        for filename in ("study.c", "conversion.inc"):
            shutil.copy2(root / filename, directory / filename)
        kernels = (root / "kernels.inc").read_text()
        start = kernels.index("static NOINLINE void candidate_vl128(")
        target = "acc1 = __riscv_vmv_x_s_i32m1_i32("
        body = kernels[start:]
        if body.count(target) != 2:
            raise SystemExit("Unexpected candidate shape for mutation check")
        body = body.replace(target, "acc1 = 1 + __riscv_vmv_x_s_i32m1_i32(", 1)
        (directory / "kernels.inc").write_text(kernels[:start] + body)
        subprocess.run(
            [os.environ.get("CC", "riscv64-linux-gnu-gcc"), "-O2", "-Wall", "-Wextra",
             "-Wpedantic", "-Werror", "-Wno-unused-function", "-march=rv64gcv", "-mabi=lp64d",
             "-I" + str(root / "source/ggml/src"), "-I" + str(root / "source/ggml/include"),
             str(directory / "study.c"), "-o", str(directory / "mutant"), "-lm"], check=True)
        result = subprocess.run(
            [os.environ.get("QEMU", "qemu-riscv64"), "-L", "/usr/riscv64-linux-gnu",
             "-cpu", "max,vlen=128,elen=64,vext_spec=v1.0", str(directory / "mutant")],
            capture_output=True, text=True)
        if result.returncode != 1 or "FAIL case=2 blocks=2" not in result.stderr:
            raise SystemExit("Harness did not reject mutated candidate as expected")
        (root / "results/mutation-check.log").write_text(
            "Deliberately added 1 to first candidate accumulator; expected rejection.\n" +
            result.stdout + result.stderr + "PASS: deliberately incorrect candidate rejected\n")
    print("PASS: patches reconstruct candidate; deliberately incorrect candidate rejected")


if __name__ == "__main__":
    main()
