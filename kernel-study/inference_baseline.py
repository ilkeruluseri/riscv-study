"""Capture verified real-model timings and separate single-thread CPU profiles."""

import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import tempfile

import baseline
import measure
import profile_operations


MODELS = {
    "q4_0": "7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed",
    "q8_0": "ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e",
}
REVISION = "9217f5db79a29953eb74d5343926648285ec7e67"
PHASES = {"pp128": (128, 0), "pp512": (512, 0), "tg128": (0, 128)}


def validate_benchmark(path, model, phase, repetitions):
    rows = json.loads(path.read_text())
    if not isinstance(rows, list) or len(rows) != 1:
        raise ValueError("Expected exactly one inference benchmark result")
    row = rows[0]
    prompt, generation = PHASES[phase]
    expected = {"n_prompt": prompt, "n_gen": generation, "n_threads": 1,
                "n_gpu_layers": 0, "backends": "CPU", "n_batch": 128,
                "n_ubatch": 128, "n_depth": 0, "poll": 0, "repack": False,
                "no_kv_offload": True, "no_op_offload": 1, "flash_attn": 0,
                "type_k": "f16", "type_v": "f16"}
    if any(row.get(key) != value for key, value in expected.items()):
        raise ValueError("Inference phase/backend/thread/settings do not match the request")
    if Path(row.get("model_filename", "")).resolve() != model.resolve():
        raise ValueError("Inference result names another model")
    samples = row.get("samples_ns", [])
    if len(samples) != repetitions or any(not isinstance(value, (int, float)) or
                                         not math.isfinite(value) or value <= 0 for value in samples):
        raise ValueError("Missing or invalid inference timing repetitions")
    return row


def model_inventory(model, workspace, expected_hash):
    if baseline.digest(model) != expected_hash:
        raise ValueError(f"Downloaded model hash mismatch: {model}")
    # Avoid adding __pycache__ files to the exact exported source snapshot.
    sys.dont_write_bytecode = True
    original_path = sys.path[:]
    # This directory's assembly tool is named inspect.py; NumPy needs stdlib inspect.
    sys.path[:] = [str(workspace / "source/gguf-py")] + [
        entry for entry in original_path if Path(entry or ".").resolve() != baseline.HERE]
    try:
        from gguf import GGUFReader
    finally:
        sys.path[:] = original_path
    reader = GGUFReader(model)
    tensors = [{"name": tensor.name, "shape": tensor.shape.tolist(),
                "type": tensor.tensor_type.name, "elements": int(tensor.n_elements)}
               for tensor in reader.tensors]
    return {"schema_version": 1, "path": str(model), "sha256": expected_hash,
            "file_bytes": model.stat().st_size,
            "repository": "Qwen/Qwen2.5-0.5B-Instruct-GGUF", "revision": REVISION,
            "architecture": reader.fields["general.architecture"].contents(),
            "tensor_types": dict(Counter(tensor["type"] for tensor in tensors)), "tensors": tensors}


def run(args):
    workspace = args.workspace.resolve()
    source = baseline.verify_snapshot(workspace)
    executable = workspace / "build/bin/llama-bench"
    cpu = args.cpu if args.cpu is not None else min(os.sched_getaffinity(0))
    if cpu not in os.sched_getaffinity(0):
        raise ValueError("Selected CPU is outside allowed affinity")
    measure.validate(args.kind, "record", [str(executable)])
    perf = shutil.which(os.environ.get("PERF", "perf"))
    if not perf:
        raise ValueError("Set PERF to the actual installed perf binary")
    subprocess.run([perf, "--version"], check=True)
    root = baseline.HERE / "results/inference"
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-"), dir=root))
    print(directory, flush=True)
    build = {"source_revision": source["revision"], "executable": str(executable),
             "sha256": baseline.digest(executable), "cmake_cache_sha256": baseline.digest(workspace / "build/CMakeCache.txt")}
    measure.write_json(directory / "inference-build.json", build)
    manifest = {"schema_version": 1, "status": "running", "kind": args.kind, "cpu": cpu,
                "started_utc": datetime.now(timezone.utc).isoformat(), "build": build,
                "benchmark_repetitions": args.repetitions, "profile_repetitions": args.profile_repetitions,
                "input_policy": "upstream synthetic token streams; real model weights; no tokenizer/sampler/quality evaluation",
                "profile_scope": "whole process including loading and warmup; all inherited threads",
                "benchmarks": [], "profiles": []}
    measure.write_json(directory / "inference.json", manifest)
    models = {}
    timings = []
    try:
        for quant, expected_hash in MODELS.items():
            model = args.models.resolve() / f"qwen2.5-0.5b-instruct-{quant}.gguf"
            inventory = model_inventory(model, workspace, expected_hash)
            inventory_file = directory / f"model-{quant}.json"
            measure.write_json(inventory_file, inventory)
            models[quant] = (model, inventory_file)
        for collection in ("benchmark", "profile"):
            for phase, (prompt, generation) in PHASES.items():
                if collection == "profile" and phase == "pp128":
                    continue
                repetitions = args.repetitions if collection == "benchmark" else args.profile_repetitions
                for quant, (model, inventory_file) in models.items():
                    output = directory / quant / phase / collection
                    command = [sys.executable, str(baseline.HERE / "measure.py"), "run", "--kind", args.kind,
                               "--profile", "none" if collection == "benchmark" else "record",
                               "--timeout", "900", "--output-dir", str(output)]
                    for path in (executable, Path(perf), inventory_file, directory / "inference-build.json",
                                 workspace / "source.json", workspace / "build/CMakeCache.txt",
                                 workspace / "build/compile_commands.json", Path(__file__), baseline.HERE / "measure.py"):
                        command.extend(["--artifact", str(path)])
                    command.extend(["--", "taskset", "-c", str(cpu), str(executable), "--offline", "-m", str(model),
                                    "-p", str(prompt), "-n", str(generation), "-ngl", "0", "-t", "1",
                                    "-b", "128", "-ub", "128", "-fa", "off", "-nkvo", "1", "-nopo", "1",
                                    "--repack", "0", "-lm", "mmap", "-lzm", "off", "--poll", "0",
                                    "-r", str(repetitions), "-o", "json"])
                    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
                    result = validate_benchmark(output / "rep-001.stdout", model, phase, repetitions)
                    if collection == "benchmark":
                        rates = [(prompt + generation) * 1e9 / duration for duration in result["samples_ns"]]
                        manifest["benchmarks"].append({"quant": quant, "phase": phase,
                            "median_tokens_per_second": statistics.median(rates), "min_tokens_per_second": min(rates),
                            "max_tokens_per_second": max(rates), "raw_capture": str((output / "run.json").relative_to(directory))})
                        for index, (duration, rate) in enumerate(zip(result["samples_ns"], rates), 1):
                            timings.append({"quant": quant, "phase": phase, "repetition": index,
                                            "duration_ns": duration, "tokens_per_second": rate, "kind": args.kind})
                    else:
                        data = output / "rep-001.perf.data"
                        profile_operations.checked_report(perf, ["report", "--stdio", "--no-children", "--sort",
                            "dso,symbol", "--percent-limit", "0.5", "-i", str(data)], output / "report.txt")
                        profile_operations.checked_report(perf, ["script", "-i", str(data), "-F",
                            "period,event,ip,sym,dso"], output / "samples.txt")
                        counts, periods = profile_operations.sample_totals((output / "samples.txt").read_text())
                        manifest["profiles"].append({"quant": quant, "phase": phase, "samples": sum(counts.values()),
                            "samples_by_dso": dict(counts), "period_by_dso": dict(periods),
                            "raw_capture": str((output / "run.json").relative_to(directory)),
                            "report": str((output / "report.txt").relative_to(directory))})
                    measure.write_json(directory / "inference.json", manifest)
                    print(f"PASS {quant} {phase} {collection}", flush=True)
        baseline.verify_snapshot(workspace)
        if baseline.digest(executable) != build["sha256"]:
            raise ValueError("Inference binary changed during measurement")
        for quant, (model, _) in models.items():
            if baseline.digest(model) != MODELS[quant]:
                raise ValueError("Model changed during measurement")
        with (directory / "timings.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(timings[0]))
            writer.writeheader()
            writer.writerows(timings)
        manifest["status"] = "complete"
    except (Exception, KeyboardInterrupt) as error:
        manifest["status"], manifest["error"] = "failed", str(error)
        raise
    finally:
        manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
        measure.write_json(directory / "inference.json", manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=baseline.DEFAULT_WORKSPACE)
    parser.add_argument("--models", type=Path, default=baseline.HERE / "workspace/models/qwen2.5-0.5b-instruct")
    parser.add_argument("--kind", choices=("host-practice", "native"), default="host-practice")
    parser.add_argument("--cpu", type=int)
    parser.add_argument("--repetitions", type=measure.positive_int, default=21)
    parser.add_argument("--profile-repetitions", type=measure.positive_int, default=5)
    args = parser.parse_args()
    try:
        run(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Inference run failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
