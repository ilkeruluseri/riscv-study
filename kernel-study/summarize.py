"""Summarize paired samples without selecting only the fastest run."""

import csv
from pathlib import Path
import statistics
import sys


def main():
    rows = list(csv.DictReader(Path(sys.argv[1]).open()))
    groups = {}
    for row in rows:
        key = (int(row["blocks"]), int(row["sample"]))
        group = groups.setdefault(key, {})
        variant = row["variant"]
        if variant not in ("baseline", "candidate") or variant in group:
            raise SystemExit("Invalid variant or duplicate sample")
        if int(row["total_ns"]) <= 0 or int(row["iterations"]) <= 0:
            raise SystemExit("Nonpositive timing or iteration count")
        group[variant] = int(row["total_ns"]) / int(row["iterations"])
    if not groups or any(set(g) != {"baseline", "candidate"} for g in groups.values()):
        raise SystemExit("Missing paired samples")
    if "--smoke" in sys.argv:
        if len(groups) != 14:
            raise SystemExit("Expected 14 paired smoke-test samples")
        print("PASS: emulated benchmark plumbing; no native performance conclusion")
        return
    print("blocks pairs baseline_median_ns candidate_median_ns median_paired_ratio min_ratio max_ratio")
    for blocks in sorted({key[0] for key in groups}):
        pairs = [v for k, v in groups.items() if k[0] == blocks]
        ratios = [g["baseline"] / g["candidate"] for g in pairs]
        print(blocks, len(pairs), f'{statistics.median(g["baseline"] for g in pairs):.3f}',
              f'{statistics.median(g["candidate"] for g in pairs):.3f}',
              f"{statistics.median(ratios):.4f}", f"{min(ratios):.4f}", f"{max(ratios):.4f}")
    print("Ratio > 1 favors candidate. Raw samples and spread remain essential; repeat independent sessions.")


if __name__ == "__main__":
    main()
