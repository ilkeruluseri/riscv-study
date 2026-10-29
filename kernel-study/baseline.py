"""Prepare and measure a pinned, unchanged full llama.cpp CPU baseline."""

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import statistics
import subprocess
import sys
import tarfile
import tempfile

import measure


HERE = Path(__file__).resolve().parent
DEFAULT_REVISION = "31385c9cebf9e5271a38e14c26e5df6dd93718b1"
DEFAULT_WORKSPACE = HERE / "workspace" / "operation-baseline"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_hashes(root):
    return {str(path.relative_to(root)): digest(path)
            for path in sorted(root.rglob("*")) if path.is_file()}


def verify_snapshot(workspace):
    manifest = json.loads((workspace / "source.json").read_text())
    if source_hashes(workspace / "source") != manifest["files"]:
        raise ValueError("Exported baseline source changed; use a fresh workspace")
    return manifest


def logged(argv, destination):
    measure.write_json(destination.with_suffix(".command.json"), argv)
    with destination.open("wb") as log:
        # An archive has no .git: prevent discovery of this workspace's unrelated repo.
        environment = dict(os.environ, GIT_CEILING_DIRECTORIES=str(destination.parent))
        result = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT, env=environment)
    if result.returncode:
        raise ValueError(f"Command failed ({result.returncode}); inspect {destination}")


def prepare(args):
    workspace = args.workspace.resolve()
    workspace.mkdir(parents=True, exist_ok=args.resume)
    revision = subprocess.check_output(
        ["git", "-C", str(args.source_repo), "rev-parse", args.revision + "^{commit}"], text=True).strip()
    if not re.fullmatch("[0-9a-f]{40}", revision):
        raise ValueError("Expected a full SHA-1 commit")
    source = workspace / "source"
    if args.resume:
        if verify_snapshot(workspace)["revision"] != revision:
            raise ValueError("Cannot resume a different source revision")
    else:
        archive = workspace / "source.tar"
        with archive.open("wb") as output:
            subprocess.run(["git", "-C", str(args.source_repo), "archive", revision], stdout=output, check=True)
        source.mkdir()
        with tarfile.open(archive) as exported:
            exported.extractall(source, filter="data")
        measure.write_json(workspace / "source.json", {
            "revision": revision, "origin": str(args.source_repo.resolve()),
            "archive_sha256": digest(archive), "files": source_hashes(source),
            "export_method": "git archive of explicit commit; excludes uncommitted/untracked files",
        })
    build = workspace / "build"
    configure = ["cmake", "-S", str(HERE / "operation-baseline"), "-B", str(build), "-G", "Ninja",
                 "-DLLAMA_SOURCE_DIR=" + str(source), "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
                 "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON", "-DBUILD_SHARED_LIBS=OFF",
                 "-DLLAMA_BUILD_COMMON=ON", "-DLLAMA_BUILD_TESTS=ON", "-DLLAMA_BUILD_TOOLS=ON",
                 "-DLLAMA_BUILD_EXAMPLES=OFF", "-DLLAMA_BUILD_SERVER=OFF", "-DLLAMA_BUILD_MTMD=OFF",
                 "-DLLAMA_OPENSSL=OFF", "-DGGML_BACKEND_DL=OFF", "-DGGML_NATIVE=ON",
                 "-DGGML_CPU_REPACK=OFF", "-DGGML_BLAS=OFF", "-DGGML_CCACHE=OFF"]
    logged(configure, workspace / "configure.log")
    logged(["cmake", "--build", str(build), "--parallel", str(args.jobs), "--target",
            "test-backend-ops", "llama-bench", "export-cases"], workspace / "build.log")
    generated = subprocess.check_output([str(build / "export-cases")], text=True)
    cases = []
    case_root = workspace / "cases"
    case_root.mkdir(exist_ok=args.resume)
    for line in generated.splitlines():
        name, op, definition = line.split("\t")
        path = case_root / (name + ".txt")
        path.write_text(definition + "\n")
        cases.append({"id": name, "operation": op, "file": str(path.relative_to(workspace)),
                      "sha256": digest(path)})
    if not cases or len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Empty or duplicate generated case definitions")
    measure.write_json(workspace / "cases.json", {"schema_version": 1, "cases": cases})
    executable = build / "bin/test-backend-ops"
    measure.write_json(workspace / "build.json", {
        "schema_version": 1, "source_revision": revision,
        "executable": str(executable), "sha256": digest(executable),
        "case_generator_sha256": digest(build / "export-cases"),
        "harness_files": {name: digest(HERE / "operation-baseline" / name)
                          for name in ("CMakeLists.txt", "export-cases.cpp")},
        "classification": "host-specific optimized build; no optimization patch applied",
        "cpu_repack": False, "native_tuning": True,
        "thread_policy": "unchanged upstream tester: max(1, hardware_concurrency()/2) for tested backend",
        "input_policy": "upstream randomized tensor initialization; shapes fixed, values not seeded",
    })
    verify_snapshot(workspace)
    print(f"Prepared {revision}: {len(cases)} cases in {workspace}")


def read_result(path, case, mode):
    # Only SQL emitted by our pinned upstream tester is accepted, in memory.
    with sqlite3.connect(":memory:") as database:
        database.row_factory = sqlite3.Row
        database.executescript(path.read_text())
        rows = [dict(row) for row in database.execute("SELECT * FROM test_backend_ops")]
    if len(rows) != 1:
        raise ValueError(f"{case['id']}: expected one result, got {len(rows)}")
    row = rows[0]
    if (row["backend_name"] != "CPU" or row["op_name"] != case["operation"] or
            not re.search(r"(?:^|,)name=" + re.escape(case["id"]) + r"(?:,|$)", row["op_params"]) or
            row["test_mode"] != mode):
        raise ValueError(f"{case['id']}: result does not match requested case/backend/mode")
    if not row["supported"] or not row["passed"] or row["error_message"]:
        raise ValueError(f"{case['id']}: failed or unsupported: {row['error_message']}")
    if mode == "perf" and (not isinstance(row["time_us"], (int, float)) or
                           not math.isfinite(row["time_us"]) or row["time_us"] <= 0 or row["n_runs"] <= 0):
        raise ValueError(f"{case['id']}: missing positive finite operation timing")
    return row


def run_suite(args):
    workspace = args.workspace.resolve()
    source = verify_snapshot(workspace)
    build = json.loads((workspace / "build.json").read_text())
    executable = Path(build["executable"])
    if digest(executable) != build["sha256"]:
        raise ValueError("Baseline executable changed; rebuild in a fresh workspace")
    cases = json.loads((workspace / "cases.json").read_text())["cases"]
    cases = [case for case in cases if not args.case or case["id"] in args.case]
    if not cases or (args.case and set(args.case) != {case["id"] for case in cases}):
        raise ValueError("Unknown or empty case selection; inspect cases.json")
    measure.validate(args.kind, "none", [str(executable)])
    root = HERE / "results" / "operations"
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-"), dir=root))
    report = {"schema_version": 1, "status": "running", "kind": args.kind,
              "started_utc": datetime.now(timezone.utc).isoformat(),
              "source_revision": source["revision"], "build_sha256": build["sha256"],
              "mode": args.mode, "repetitions": args.repetitions, "cases": cases,
              "thread_policy": build["thread_policy"], "input_policy": build["input_policy"],
              "results": []}
    measure.write_json(directory / "suite.json", report)
    print(directory, flush=True)
    try:
        for case in cases:
            case_file = workspace / case["file"]
            if digest(case_file) != case["sha256"]:
                raise ValueError(f"Case file changed: {case_file}")
            modes = ["test"] if args.mode == "test" else ["test", "perf"]
            for mode in modes:
                output = directory / case["id"] / mode
                command = [sys.executable, str(HERE / "measure.py"), "run", "--kind", args.kind,
                           "--output-dir", str(output), "--timeout", str(args.timeout),
                           "--repetitions", str(args.repetitions if mode == "perf" else 1)]
                for path in (workspace / "source.json", workspace / "build.json", workspace / "cases.json",
                             workspace / "build/CMakeCache.txt", workspace / "build/compile_commands.json",
                             HERE / "baseline.py", HERE / "measure.py", case_file):
                    command.extend(["--artifact", str(path)])
                command.extend(["--", str(executable), mode, "-b", "CPU", "--test-file", str(case_file), "--output", "sql"])
                subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
                capture = json.loads((output / "run.json").read_text())
                for sample in capture["samples"]:
                    row = read_result(output / sample["stdout"], case, mode)
                    report["results"].append({
                        "case_id": case["id"], "operation": case["operation"], "mode": mode,
                        "repetition": sample["repetition"], "time_us": row["time_us"],
                        "n_runs": row["n_runs"], "kind": args.kind,
                        "raw_capture": str(output.relative_to(directory) / "run.json"),
                        "raw_stdout": str((output / sample["stdout"]).relative_to(directory)),
                    })
                measure.write_json(directory / "suite.json", report)
                print(f"PASS {case['id']} {mode}", flush=True)
        report["status"] = "complete"
        with (directory / "operations.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(report["results"][0]))
            writer.writeheader()
            writer.writerows(report["results"])
        summary = {}
        for case in cases:
            timings = [row["time_us"] for row in report["results"]
                       if row["case_id"] == case["id"] and row["mode"] == "perf"]
            if timings:
                summary[case["id"]] = {"repetitions": len(timings),
                                       "median_us": statistics.median(timings),
                                       "min_us": min(timings), "max_us": max(timings)}
        measure.write_json(directory / "summary.json", {
            "schema_version": 1, "kind": args.kind, "cases": summary,
            "interpretation": "descriptive within-suite spread only; no native RVV or significance claim from host practice",
        })
    except (Exception, KeyboardInterrupt) as error:
        report["status"], report["error"] = "failed", str(error)
        raise
    finally:
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        measure.write_json(directory / "suite.json", report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE)
    commands = parser.add_subparsers(dest="action", required=True)
    setup = commands.add_parser("prepare")
    setup.add_argument("--source-repo", type=Path, required=True)
    setup.add_argument("--revision", default=DEFAULT_REVISION)
    setup.add_argument("--jobs", type=measure.positive_int, default=4)
    setup.add_argument("--resume", action="store_true", help="verify existing source and retry/reconfigure the build")
    run = commands.add_parser("run")
    run.add_argument("--kind", choices=("host-practice", "native"), default="host-practice")
    run.add_argument("--mode", choices=("test", "perf", "both"), default="both")
    run.add_argument("--repetitions", type=measure.positive_int, default=3)
    run.add_argument("--timeout", type=measure.positive_int, default=120)
    run.add_argument("--case", action="append")
    args = parser.parse_args()
    try:
        prepare(args) if args.action == "prepare" else run_suite(args)
    except (ValueError, OSError, subprocess.CalledProcessError, sqlite3.Error) as error:
        print(f"Baseline setup/run failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
