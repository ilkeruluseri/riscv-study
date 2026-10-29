"""Ensure inference results cannot silently use another workload or thread count."""

import json
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import inference_baseline


class InferenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.model = self.root / "model.gguf"
        self.row = {"n_prompt": 128, "n_gen": 0, "n_threads": 1, "n_gpu_layers": 0,
                    "backends": "CPU", "n_batch": 128, "n_ubatch": 128, "n_depth": 0,
                    "poll": 0, "repack": False, "no_kv_offload": True, "no_op_offload": 1,
                    "flash_attn": 0, "type_k": "f16", "type_v": "f16",
                    "model_filename": str(self.model), "samples_ns": [100, 200, 300]}

    def write(self, rows):
        path = self.root / "benchmark.json"
        path.write_text(json.dumps(rows))
        return path

    def test_valid_timing_keeps_raw_samples(self):
        row = inference_baseline.validate_benchmark(self.write([self.row]), self.model, "pp128", 3)
        self.assertEqual(row["samples_ns"], [100, 200, 300])

    def test_wrong_workload_and_settings_fail(self):
        for change in ({"n_threads": 12}, {"backends": "CUDA"}, {"n_gpu_layers": 1},
                       {"n_gen": 128}, {"n_batch": 512}, {"repack": True},
                       {"model_filename": "/other/model.gguf"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                inference_baseline.validate_benchmark(self.write([dict(self.row, **change)]), self.model, "pp128", 3)

    def test_missing_nonpositive_or_nonfinite_timings_fail(self):
        for samples in ([], [1], [0, 2, 3], [-1, 2, 3], [float("nan"), 2, 3], [float("inf"), 2, 3]):
            with self.subTest(samples=samples), self.assertRaises(ValueError):
                inference_baseline.validate_benchmark(self.write([dict(self.row, samples_ns=samples)]), self.model, "pp128", 3)
        with self.assertRaises(ValueError):
            inference_baseline.validate_benchmark(self.write([]), self.model, "pp128", 3)

    def test_incorrect_model_bytes_rejected_before_reading_gguf(self):
        self.model.write_bytes(b"incomplete download")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            inference_baseline.model_inventory(self.model, self.root, "0" * 64)

    def test_inventory_does_not_shadow_stdlib_inspect(self):
        package = self.root / "source/gguf-py"
        package.mkdir(parents=True)
        (package / "gguf.py").write_text(
            "import inspect\nassert hasattr(inspect, 'cleandoc')\n"
            "class Field:\n def contents(self): return 'qwen2'\n"
            "class GGUFReader:\n def __init__(self, path):\n"
            "  self.tensors=[]\n  self.fields={'general.architecture': Field()}\n")
        self.model.write_bytes(b"metadata import fixture")
        expected = hashlib.sha256(self.model.read_bytes()).hexdigest()
        code = ("import sys; from pathlib import Path; "
                "sys.path.insert(0, sys.argv[1]); import inference_baseline as module; "
                "result=module.model_inventory(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]); "
                "assert result['architecture']=='qwen2'")
        subprocess.run([sys.executable, "-c", code, str(inference_baseline.baseline.HERE),
                        str(self.model), str(self.root), expected], check=True, capture_output=True)


if __name__ == "__main__":
    unittest.main()
