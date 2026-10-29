"""Capture benchmark evidence; smoke/host timings are not native RVV evidence."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time


HERE = Path(__file__).resolve().parent
TOOLS = ("gcc", "riscv64-linux-gnu-gcc", "riscv64-linux-gnu-objdump",
         "qemu-riscv64", "perf", "llvm-mca", "llvm-mca-18", "llvm-mca-19",
         "llvm-mca-20", "llvm-mca-21", "cmake", "ninja", "taskset",
         "gem5", "verilator")
RUN_ENV = ("CC", "CXX", "OBJDUMP", "OPT", "CPU", "ITERATIONS", "SAMPLES",
           "OMP_NUM_THREADS", "OMP_PROC_BIND", "OMP_PLACES", "PERF")


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def read_optional(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def tool_info(name):
    path = shutil.which(name)
    if path is None:
        return {"available": False}
    try:
        result = subprocess.run([path, "--version"], capture_output=True,
                                text=True, errors="replace", timeout=5)
        return {"available": True, "path": path, "exit_code": result.returncode,
                "version": (result.stdout + result.stderr).strip()[:4000]}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"available": True, "path": path, "version_error": str(error)}


def environment():
    metadata = {
        "machine": platform.machine(), "platform": platform.platform(),
        "python": sys.version, "cpu_count": os.cpu_count(),
        "affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
        "os_release": read_optional("/etc/os-release"),
        "cpuinfo": read_optional("/proc/cpuinfo"),
        "perf_event_paranoid": read_optional("/proc/sys/kernel/perf_event_paranoid"),
        "selected_environment": {key: os.environ[key] for key in RUN_ENV if key in os.environ},
        "tools": {name: tool_info(os.environ.get("PERF", name) if name == "perf" else name)
                  for name in TOOLS},
    }
    metadata["cpu_sysfs"] = {}
    cpu_root = Path("/sys/devices/system/cpu")
    for pattern in ("cpu[0-9]*/cpufreq/scaling_governor",
                    "cpu[0-9]*/cpufreq/scaling_cur_freq",
                    "cpu[0-9]*/cache/index*/level", "cpu[0-9]*/cache/index*/type",
                    "cpu[0-9]*/cache/index*/size"):
        for path in sorted(cpu_root.glob(pattern)):
            metadata["cpu_sysfs"][str(path)] = read_optional(path)
    return metadata


def positive_int(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def validate(kind, profile, command):
    if not command:
        raise ValueError("a command is required after --")
    if kind == "native":
        if platform.machine() != "riscv64":
            raise ValueError("native mode requires a riscv64 host; use smoke or host-practice here")
        if Path(command[0]).name.startswith("qemu-"):
            raise ValueError("native mode cannot directly invoke QEMU")
    if profile != "none":
        if kind == "smoke":
            raise ValueError("perf collection requires native mode or explicit host-practice")
        if Path(command[0]).name.startswith("qemu-"):
            raise ValueError("profile the native workload, not direct QEMU execution")
        if shutil.which(os.environ.get("PERF", "perf")) is None:
            raise ValueError("perf is unavailable; install the target kernel's perf tools first")


def invocation(command, profile, directory, index, events):
    stem = directory / f"rep-{index:03d}"
    if profile == "stat":
        return [os.environ.get("PERF", "perf"), "stat", "-x", ",", "-o", str(stem) + ".stat.csv",
                "-e", events or "task-clock,cycles,instructions", "--", *command]
    if profile == "record":
        return [os.environ.get("PERF", "perf"), "record", "-o", str(stem) + ".perf.data", "-e",
                events or "cpu-clock:u", "-F", "99", "--", *command]
    return command


def run(args):
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    validate(args.kind, args.profile, command)
    artifacts = [Path(value).resolve(strict=True) for value in args.artifact]
    if any(not path.is_file() for path in artifacts):
        raise ValueError("artifacts must be regular files")
    executable = shutil.which(command[0])
    if executable:
        artifacts.insert(0, Path(executable).resolve())
    if args.output_dir:
        directory = Path(args.output_dir).resolve()
        directory.mkdir(parents=True, exist_ok=False)
    else:
        root = HERE / "results" / "runs"
        root.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        directory = Path(tempfile.mkdtemp(prefix=stamp + "-", dir=root))
    print(directory, flush=True)
    manifest = {
        "schema_version": 1, "kind": args.kind, "profile": args.profile,
        "native_rvv_timing_eligible": args.kind == "native",
        "classification_basis": "user-selected kind plus host-architecture guard; VM/wrapper detection is not guaranteed",
        "timing_scope": "whole subprocess including startup, teardown, and profiler overhead if enabled",
        "command": command, "cwd": str(Path.cwd()),
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "requested_repetitions": args.repetitions, "timeout_seconds": args.timeout,
        "artifacts": [], "samples": [], "status": "preparing",
    }
    write_json(directory / "run.json", manifest)
    try:
        write_json(directory / "environment.json", environment())
        archive = directory / "artifacts"
        archive.mkdir()
        for index, path in enumerate(dict.fromkeys(artifacts), 1):
            destination = archive / f"{index:03d}-{path.name}"
            shutil.copy2(path, destination)
            manifest["artifacts"].append({
                "source": str(path), "copy": str(destination.relative_to(directory)),
                "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
            })
        manifest["status"] = "running"
        write_json(directory / "run.json", manifest)
        for index in range(1, args.repetitions + 1):
            argv = invocation(command, args.profile, directory, index, args.events)
            stem = directory / f"rep-{index:03d}"
            start = time.perf_counter_ns()
            error = None
            with Path(str(stem) + ".stdout").open("wb") as stdout, \
                    Path(str(stem) + ".stderr").open("wb") as stderr:
                try:
                    result = subprocess.run(argv, stdout=stdout, stderr=stderr, timeout=args.timeout)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code, error = 124, "command timed out"
                except OSError as exception:
                    code, error = 127, str(exception)
                except KeyboardInterrupt:
                    code, error = 130, "interrupted"
            if not code and args.profile == "stat":
                counters = read_optional(str(stem) + ".stat.csv")
                if not counters or "<not supported>" in counters or "<not counted>" in counters:
                    code, error = 3, "perf did not count every requested event; inspect stat CSV"
            if not code and args.profile == "record":
                profile = Path(str(stem) + ".perf.data")
                if not profile.is_file() or profile.stat().st_size == 0:
                    code, error = 3, "perf produced no profile data"
            manifest["samples"].append({
                "repetition": index, "executed_argv": argv, "exit_code": code,
                "elapsed_ns": time.perf_counter_ns() - start, "error": error,
                "stdout": stem.name + ".stdout", "stderr": stem.name + ".stderr",
            })
            manifest["status"] = "failed" if code else "running"
            write_json(directory / "run.json", manifest)
            if code:
                return code if 0 < code < 256 else 1
        manifest["status"] = "complete"
        return 0
    except (OSError, KeyboardInterrupt) as error:
        manifest["status"] = "failed"
        manifest["capture_error"] = str(error) or "interrupted"
        raise
    finally:
        manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
        write_json(directory / "run.json", manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    doctor = commands.add_parser("doctor", help="report availability; does not install or probe counters")
    doctor.add_argument("--output", type=Path)
    capture = commands.add_parser("run", help="capture an argv command after --")
    capture.add_argument("--kind", choices=("smoke", "host-practice", "native"), default="smoke")
    capture.add_argument("--profile", choices=("none", "stat", "record"), default="none")
    capture.add_argument("--events", help="explicit perf events; unsupported events cause failure")
    capture.add_argument("--repetitions", type=positive_int, default=1)
    capture.add_argument("--timeout", type=positive_int, help="per subprocess, seconds")
    capture.add_argument("--output-dir", help="new directory; existing paths are rejected")
    capture.add_argument("--artifact", action="append", default=[], help="input file to copy/hash; repeatable")
    capture.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action == "doctor":
        report = environment()
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            write_json(args.output, report)
        else:
            print(json.dumps(report, indent=2))
        return 0
    if args.events and args.profile == "none":
        parser.error("--events requires --profile stat or record")
    try:
        return run(args)
    except (ValueError, OSError) as error:
        print(f"measurement failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
