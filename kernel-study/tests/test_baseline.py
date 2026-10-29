"""Reject false-success operation results and altered baseline snapshots."""

import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import baseline


class BaselineTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.case = {"id": "rms-f32-k33-n1", "operation": "RMS_NORM"}

    def sql(self, **overrides):
        values = dict(backend_name="CPU", op_name="RMS_NORM",
                      op_params="name=rms-f32-k33-n1,type=f32", test_mode="perf",
                      supported=1, passed=1, error_message="", time_us=1.25, n_runs=100)
        values.update(overrides)
        with sqlite3.connect(":memory:") as connection:
            connection.execute("CREATE TABLE test_backend_ops (backend_name TEXT, op_name TEXT, op_params TEXT, test_mode TEXT, supported INTEGER, passed INTEGER, error_message TEXT, time_us REAL, n_runs INTEGER)")
            connection.execute("INSERT INTO test_backend_ops VALUES (?,?,?,?,?,?,?,?,?)", tuple(values.values()))
            path = self.root / "result.sql"
            path.write_text("\n".join(connection.iterdump()).replace("Inf", "1e999"))
        return path

    def test_valid_result_preserves_internal_timing(self):
        result = baseline.read_result(self.sql(), self.case, "perf")
        self.assertEqual(result["time_us"], 1.25)
        self.assertEqual(result["n_runs"], 100)

    def test_unsupported_failed_mismatched_or_invalid_results_rejected(self):
        variants = ({"supported": 0}, {"passed": 0}, {"error_message": "skipped"},
                    {"backend_name": "CUDA0"}, {"op_name": "MUL_MAT"},
                    {"test_mode": "test"}, {"op_params": "name=rms-f32-k33-n10,type=f32"},
                    {"time_us": 0}, {"time_us": float("inf")}, {"time_us": None}, {"n_runs": 0})
        for variant in variants:
            with self.subTest(variant=variant), self.assertRaises(ValueError):
                baseline.read_result(self.sql(**variant), self.case, "perf")

    def test_empty_result_set_is_not_success(self):
        path = self.sql()
        path.write_text(path.read_text() + "\nDELETE FROM test_backend_ops;\n")
        with self.assertRaisesRegex(ValueError, "expected one result"):
            baseline.read_result(path, self.case, "perf")

    def test_snapshot_changes_and_extra_files_are_rejected(self):
        source = self.root / "source"
        source.mkdir()
        original = source / "kernel.c"
        original.write_text("unchanged source")
        (self.root / "source.json").write_text(json.dumps({"files": baseline.source_hashes(source)}))
        baseline.verify_snapshot(self.root)
        original.write_text("modified source")
        with self.assertRaisesRegex(ValueError, "changed"):
            baseline.verify_snapshot(self.root)
        original.write_text("unchanged source")
        (source / "extra.c").write_text("extra source")
        with self.assertRaisesRegex(ValueError, "changed"):
            baseline.verify_snapshot(self.root)


if __name__ == "__main__":
    unittest.main()
