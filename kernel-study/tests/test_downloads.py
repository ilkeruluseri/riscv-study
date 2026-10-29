"""Exercise interrupted and corrupted model downloads without network access."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


class DownloadTests(unittest.TestCase):
    def test_incomplete_or_corrupt_weights_are_never_published(self):
        script = Path(__file__).resolve().parents[1] / "download-models.sh"
        for exit_code in (0, 56):
            with self.subTest(curl_exit=exit_code), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                shutil.copy2(script, root / script.name)
                tools = root / "bin"
                tools.mkdir()
                curl = tools / "curl"
                curl.write_text("#!/bin/sh\nwhile [ \"$1\" != --output ]; do shift; done\n"
                                "shift\nprintf 'invalid weights' > \"$1\"\n"
                                f"exit {exit_code}\n")
                curl.chmod(0o755)
                environment = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ["PATH"])
                result = subprocess.run(["sh", str(root / script.name)], env=environment,
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                model = root / "workspace/models/qwen2.5-0.5b-instruct/qwen2.5-0.5b-instruct-q4_0.gguf"
                self.assertFalse(model.exists())
                # A network interruption retains resumable data; bad complete data is removed.
                self.assertEqual(Path(str(model) + ".part").exists(), exit_code == 56)


if __name__ == "__main__":
    unittest.main()
