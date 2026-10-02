"""Run actual camera sources against deterministic Roblox test doubles.

Usage: python tests/run_camera.py /path/to/luau
This checks math and lifecycle, not rendered appearance or real collision.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
harness = (root / 'tests/camera.luau').read_text()
for key, path in {
    'CONFIG': 'src/shared/CameraConfig.luau',
    'RIG': 'src/client/CameraRig.luau',
    'CONTROLLER': 'src/client/CameraController.local.luau',
}.items():
    source = (root / path).read_text()
    delimiter = '='
    while ']' + delimiter + ']' in source:
        delimiter += '='
    harness = harness.replace('__' + key + '_SOURCE__', '[' + delimiter + '[' + source + ']' + delimiter + ']')
with tempfile.TemporaryDirectory() as temporary:
    runner = Path(temporary) / 'camera.luau'
    runner.write_text(harness)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(runner)], check=True)
