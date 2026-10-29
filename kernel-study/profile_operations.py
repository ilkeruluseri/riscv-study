"""Profile four unchanged CPU operations, retaining raw perf data and reports."""

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import baseline
import measure


CASES = ("rms-f32-k896-n1", "mat-q8_0-m64-k896-n1",
         "mat-q4_0-m64-k896-n1", "mat-iq4_nl-m64-k896-n1")


def sample_totals(text):
    """Read perf's fixed period/event/IP/symbol/DSO display order."""
    counts, periods = Counter(), Counter()
    for line in text.splitlines():
        fields = line.strip().split(None, 3)
        if len(fields) != 4:
            continue
        period, event, address, rest = fields
        if not event.startswith("cpu-clock:") or not period.isdigit() or " (" not in rest:
            continue
        symbol, dso = rest.rsplit(" (", 1)
        name = Path(dso.rstrip(")")).name
        counts[name] += 1
        periods[name] += int(period)
    if not sum(counts.values()):
        raise ValueError("No parsed CPU-clock samples")
    return counts, periods


def checked_report(perf, argv, path):
    with path.open("w") as output, path.with_suffix(path.suffix + ".stderr").open("w") as error:
        subprocess.run([perf, *argv], stdout=output, stderr=error, check=True)


def profile(args):
    workspace = args.workspace.resolve()
    source = baseline.verify_snapshot(workspace)
    build = json.loads((workspace / "build.json").read_text())
    executable = Path(build["executable"])
    if baseline.digest(executable) != build["sha256"]:
        raise ValueError("Baseline executable changed")
    perf = shutil.which(os.environ.get("PERF", "perf"))
    if not perf:
        raise ValueError("Set PERF to the installed perf binary")
    subprocess.run([perf, "--version"], check=True)
    requested = args.case or CASES
    definitions = json.loads((workspace / "cases.json").read_text())["cases"]
    cases = [case for case in definitions if case["id"] in requested]
    if {case["id"] for case in cases} != set(requested):
        raise ValueError("Unknown case selection")
    root = baseline.HERE / "results/profiles"
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-"), dir=root))
    print(directory, flush=True)
    report = {"schema_version": 1, "status": "running", "kind": args.kind,
              "source_revision": source["revision"], "binary_sha256": build["sha256"],
              "event": "cpu-clock:u", "sampling_frequency_hz": 99, "call_graphs": False,
              "scope": "whole subprocess; all inherited threads; setup included",
              "thread_policy": build["thread_policy"], "results": []}
    try:
        for case in cases:
            case_file = workspace / case["file"]
            if baseline.digest(case_file) != case["sha256"]:
                raise ValueError("Case definition changed")
            for phase in ("test", "stat", "record"):
                output = directory / case["id"] / phase
                command = [sys.executable, str(baseline.HERE / "measure.py"), "run", "--kind", args.kind,
                           "--output-dir", str(output), "--timeout", "120", "--profile",
                           "none" if phase == "test" else phase, "--repetitions",
                           str(args.repetitions if phase == "record" else 1)]
                if phase == "stat":
                    command.extend(["--events", "task-clock:u"])
                for path in (workspace / "source.json", workspace / "build.json", case_file,
                             Path(perf), Path(__file__), baseline.HERE / "measure.py"):
                    command.extend(["--artifact", str(path)])
                mode = "test" if phase == "test" else "perf"
                command.extend(["--", str(executable), mode, "-b", "CPU", "--output", "sql",
                                "--test-file", str(case_file)])
                subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
                capture = json.loads((output / "run.json").read_text())
                for sample in capture["samples"]:
                    baseline.read_result(output / sample["stdout"], case, mode)
                    if phase != "record":
                        continue
                    stem = output / f"rep-{sample['repetition']:03d}"
                    data = Path(str(stem) + ".perf.data")
                    checked_report(perf, ["report", "--stdio", "--no-children", "--sort", "dso,symbol",
                                         "--percent-limit", "0.5", "-i", str(data)], Path(str(stem) + ".report.txt"))
                    script = Path(str(stem) + ".samples.txt")
                    checked_report(perf, ["script", "-i", str(data), "-F", "period,event,ip,sym,dso"], script)
                    counts, periods = sample_totals(script.read_text())
                    report["results"].append({
                        "case_id": case["id"], "repetition": sample["repetition"],
                        "samples": sum(counts.values()), "samples_by_dso": dict(counts),
                        "period_by_dso": dict(periods),
                        "raw_capture": str((output / "run.json").relative_to(directory)),
                        "report": str(Path(str(stem) + ".report.txt").relative_to(directory)),
                    })
                measure.write_json(directory / "profiles.json", report)
                print(f"PASS {case['id']} {phase}", flush=True)
        report["status"] = "complete"
    except (Exception, KeyboardInterrupt) as error:
        report["status"], report["error"] = "failed", str(error)
        raise
    finally:
        measure.write_json(directory / "profiles.json", report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=baseline.DEFAULT_WORKSPACE)
    parser.add_argument("--kind", choices=("host-practice", "native"), default="host-practice")
    parser.add_argument("--case", action="append")
    parser.add_argument("--repetitions", type=measure.positive_int, default=3)
    args = parser.parse_args()
    try:
        profile(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Profiling failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
