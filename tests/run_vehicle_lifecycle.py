"""Run the real lifecycle module against a small deterministic Roblox simulation.

Usage: python tests/run_vehicle_lifecycle.py /path/to/luau
This checks lifecycle logic, not Roblox physics or replication.
"""

from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "src/server/PlayerVehicleService.luau").read_text()
harness = (root / "tests/vehicle_lifecycle.luau").read_text()
assert "__SERVICE_SOURCE__" in harness
# Choose a long-string delimiter that cannot terminate inside the module.
delimiter = "="
while "]" + delimiter + "]" in source:
    delimiter += "="
embedded = "[" + delimiter + "[" + source + "]" + delimiter + "]"
controller = (root / "src/server/VehicleController.server.luau").read_text()
driver_check = controller.split("local function getDriver", 1)[1].split(
    "\nlocal function finiteNumber", 1
)[0]
driver_check = "local function getDriver" + driver_check + "\nreturn getDriver"
harness = harness.replace("__DRIVER_SOURCE__", "[====[" + driver_check + "]====]")
with tempfile.TemporaryDirectory() as temporary:
    runner = Path(temporary) / "vehicle_lifecycle.luau"
    runner.write_text(harness.replace("__SERVICE_SOURCE__", embedded))
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(runner)], check=True)
