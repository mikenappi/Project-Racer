"""Run integrated checkpoint/reset source tests; Roblox physics remains a Studio check.

Usage: python tests/run_checkpoints.py /path/to/luau
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
read = lambda name: (root / name).read_text()
# Reuse the established simulator setup, without running its independent cases.
setup = read('tests/vehicle_lifecycle.luau').split('-- Existing-player startup,', 1)[0]
harness = setup + read('tests/checkpoint_reset.luau')
controller = read('src/server/VehicleController.server.luau')
reset_prelude = controller.split('local function stepVehicle(state: DriveState, dt: number)', 1)[1].split('\n\tlocal chassis = state.chassis', 1)[0]
sources = {
    'SERVICE': read('src/server/PlayerVehicleService.luau'),
    'CHECKPOINT': read('src/server/CheckpointService.luau'),
    'RESPAWN': read('src/server/RespawnService.luau'),
    'MANAGER': read('src/server/RaceManager.server.luau'),
    'VEHICLE': read('src/server/VehicleService.luau'),
    'CONTROLLER_RESET': 'return function(state)' + reset_prelude + '\nend',
    'CLIENT_RESET': 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n' + read('src/client/InputController.local.luau').split('-- Keep reset input independent', 1)[1].split('\n', 1)[1],
}
for key, source in sources.items():
    delimiter = '='
    while ']' + delimiter + ']' in source:
        delimiter += '='
    harness = harness.replace('__' + key + '_SOURCE__', '[' + delimiter + '[' + source + ']' + delimiter + ']')
with tempfile.TemporaryDirectory() as temporary:
    runner = Path(temporary) / 'checkpoint_reset.luau'
    runner.write_text(harness)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(runner)], check=True)
