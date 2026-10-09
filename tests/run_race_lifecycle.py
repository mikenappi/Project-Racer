"""Run real race modules and manager in the existing deterministic simulator.

Usage: python tests/run_race_lifecycle.py /path/to/luau
Does not establish engine physics, replication, or multiplayer acceptance.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
read = lambda name: (root / name).read_text()
setup = read('tests/vehicle_lifecycle.luau').split('-- Existing-player startup,', 1)[0]
fixtures = read('tests/checkpoint_reset.luau').split('local first, second = player(101), player(202)', 1)[0]
harness = setup + fixtures + read('tests/race_lifecycle.luau')
controller = read('src/server/VehicleController.server.luau')
step = controller.split('local function stepVehicle(state: DriveState, dt: number)', 1)[1].split('\n\tlocal normal = getGroundNormal(state)', 1)[0]
remote = controller.split('inputRemote.OnServerEvent:Connect(function', 1)[1].split('\nend)', 1)[0]
sources = {
    'TRACK': read('src/server/TrackProgress.luau'),
    'PLACEMENT': read('src/server/PlacementService.luau'),
    'TIMING': read('src/shared/RaceTiming.luau'),
    'COUNTDOWN_UI': 'return function()' + read('src/client/RaceHUD.local.luau').split('local function showCountdown()', 1)[1].split('-- COUNTDOWN_END:', 1)[0],
    'COAST': 'local function getDriveTarget' + controller.split('local function getDriveTarget', 1)[1].split('local function getYawTarget', 1)[0]
        + '\nreturn function(state, speed, hasInput, coasting, dt)\n'
        + '\tlocal throttle = if hasInput' + controller.split('\tlocal throttle = if hasInput', 1)[1].split('\n\t-- The plane', 1)[0]
        + '\nreturn mode, state.driveForce, target\nend',
    'SERVICE': read('src/server/PlayerVehicleService.luau'),
    'CHECKPOINT': read('src/server/CheckpointService.luau'),
    'RESPAWN': read('src/server/RespawnService.luau'),
    'RACE': read('src/server/RaceService.luau'),
    'MANAGER': read('src/server/RaceManager.server.luau'),
    'DRIVE_GATE': 'return function(state)' + step + '\nend',
    'INPUT_GATE': 'return function' + remote + '\nend',
}
for key, source in sources.items():
    delimiter = '='
    while ']' + delimiter + ']' in source:
        delimiter += '='
    harness = harness.replace('__' + key + '_SOURCE__', '[' + delimiter + '[' + source + ']' + delimiter + ']')
with tempfile.TemporaryDirectory() as temporary:
    runner = Path(temporary) / 'race_lifecycle.luau'
    runner.write_text(harness)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(runner)], check=True)
