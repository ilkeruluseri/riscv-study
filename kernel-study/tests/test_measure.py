"""Exercise capture boundaries without requiring perf or native hardware."""

import argparse
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import measure


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.args = argparse.Namespace(
            command=[sys.executable, "-c", "print('hello')"], kind="smoke",
            profile="none", repetitions=1, timeout=5, events=None,
            output_dir=str(self.root / "run"), artifact=[])

    def capture(self):
        with patch.object(measure, "environment", return_value={"test": True}), \
                redirect_stdout(io.StringIO()):
            return measure.run(self.args)

    def manifest(self):
        return json.loads((self.root / "run/run.json").read_text())

    def test_repetitions_streams_literal_arguments_and_artifacts(self):
        sentinel = self.root / "must-not-exist"
        literal = f"$(touch {sentinel}); `touch {sentinel}`"
        source = self.root / "input file.txt"
        source.write_text("known contents\n")
        self.args.artifact = [str(source)]
        self.args.repetitions = 2
        self.args.command = ["--", sys.executable, "-c",
                             "import sys; print(sys.argv[1]); print('diagnostic', file=sys.stderr)", literal]
        self.assertEqual(self.capture(), 0)
        report = self.manifest()
        self.assertEqual(report["status"], "complete")
        self.assertFalse(report["native_rvv_timing_eligible"])
        self.assertEqual(len(report["samples"]), 2)
        self.assertFalse(sentinel.exists())
        self.assertEqual((self.root / "run/rep-002.stdout").read_text(), literal + "\n")
        self.assertEqual((self.root / "run/rep-001.stderr").read_text(), "diagnostic\n")
        artifact = next(a for a in report["artifacts"] if a["source"] == str(source))
        self.assertEqual(artifact["sha256"], hashlib.sha256(source.read_bytes()).hexdigest())
        self.assertEqual((self.root / "run" / artifact["copy"]).read_bytes(), source.read_bytes())

    def test_failed_command_stops_repetitions_and_keeps_diagnostics(self):
        self.args.repetitions = 3
        self.args.command = [sys.executable, "-c", "import sys; print('bad input', file=sys.stderr); sys.exit(7)"]
        self.assertEqual(self.capture(), 7)
        self.assertEqual(self.manifest()["status"], "failed")
        self.assertEqual(len(self.manifest()["samples"]), 1)
        self.assertIn("bad input", (self.root / "run/rep-001.stderr").read_text())

    def test_missing_executable_is_recorded(self):
        self.args.command = [str(self.root / "missing")]
        self.assertEqual(self.capture(), 127)
        self.assertEqual(self.manifest()["status"], "failed")
        self.assertTrue(self.manifest()["samples"][0]["error"])

    def test_timeout_is_recorded(self):
        self.args.command = [sys.executable, "-c", "import time; time.sleep(10)"]
        self.args.timeout = 0.05
        self.assertEqual(self.capture(), 124)
        self.assertEqual(self.manifest()["samples"][0]["error"], "command timed out")

    def test_existing_directory_is_never_overwritten(self):
        (self.root / "run").mkdir()
        sentinel = self.root / "run/keep"
        sentinel.write_text("preserve")
        with self.assertRaises(FileExistsError):
            self.capture()
        self.assertEqual(sentinel.read_text(), "preserve")

    def test_native_and_profile_guards(self):
        with patch.object(measure.platform, "machine", return_value="x86_64"):
            with self.assertRaisesRegex(ValueError, "riscv64"):
                measure.validate("native", "none", ["benchmark"])
        with self.assertRaisesRegex(ValueError, "native mode"):
            measure.validate("smoke", "stat", ["benchmark"])
        with patch.object(measure.platform, "machine", return_value="riscv64"):
            with self.assertRaisesRegex(ValueError, "QEMU"):
                measure.validate("native", "none", ["qemu-riscv64"])
            with patch.object(measure.shutil, "which", return_value=None):
                with self.assertRaisesRegex(ValueError, "unavailable"):
                    measure.validate("native", "stat", ["benchmark"])

    def test_perf_argv_and_unsupported_counter_failure(self):
        self.args.kind, self.args.profile = "native", "stat"
        directory = Path(self.args.output_dir)
        expected = measure.invocation(self.args.command, "stat", directory, 1, None)

        def fake_run(argv, **kwargs):
            self.assertEqual(argv, expected)
            (directory / "rep-001.stat.csv").write_text("<not supported>,,cycles\n")
            return argparse.Namespace(returncode=0)

        with patch.object(measure, "validate"), patch.object(measure.subprocess, "run", side_effect=fake_run):
            self.assertEqual(self.capture(), 3)
        self.assertEqual(self.manifest()["status"], "failed")
        self.assertIn("did not count", self.manifest()["samples"][0]["error"])

    def test_successful_record_and_empty_profile_failure(self):
        self.args.kind, self.args.profile = "native", "record"
        directory = Path(self.args.output_dir)

        def fake_run(argv, **kwargs):
            self.assertEqual(argv[0:2], ["perf", "record"])
            self.assertIn("cpu-clock:u", argv)
            (directory / "rep-001.perf.data").write_bytes(b"test profile")
            return argparse.Namespace(returncode=0)

        with patch.object(measure, "validate"), patch.object(measure.subprocess, "run", side_effect=fake_run):
            self.assertEqual(self.capture(), 0)
        self.args.output_dir = str(self.root / "empty-profile")
        with patch.object(measure, "validate"), patch.object(measure.subprocess, "run", return_value=argparse.Namespace(returncode=0)):
            self.assertEqual(self.capture(), 3)
        report = json.loads((self.root / "empty-profile/run.json").read_text())
        self.assertEqual(report["status"], "failed")


if __name__ == "__main__":
    unittest.main()
