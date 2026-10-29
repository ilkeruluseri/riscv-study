"""Check summaries against the actual perf 6.8 text format."""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import profile_operations


class ProfileTests(unittest.TestCase):
    def test_weighted_totals_include_unresolved_runtime_symbols(self):
        text = """  10101010 cpu-clock:u: 7605f84a69a0 [unknown] (/usr/lib/libgomp.so.1.0.0)
  20000000 cpu-clock:u: 1234 ggml_compute_forward_rms_norm (/workspace/test-backend-ops)
  10101010 cpu-clock:u: 7605f84a68a2 [unknown] (/usr/lib/libgomp.so.1.0.0)
"""
        counts, periods = profile_operations.sample_totals(text)
        self.assertEqual(sum(counts.values()), 3)
        self.assertEqual(counts["libgomp.so.1.0.0"], 2)
        self.assertEqual(periods["libgomp.so.1.0.0"], 20202020)
        self.assertEqual(periods["test-backend-ops"], 20000000)

    def test_missing_addresses_or_wrong_events_are_not_accepted(self):
        for text in ("10101010 cpu-clock:u:", "10101010 cycles:u: 1234 symbol (/binary)", ""):
            with self.subTest(text=text), self.assertRaises(ValueError):
                profile_operations.sample_totals(text)


if __name__ == "__main__":
    unittest.main()
