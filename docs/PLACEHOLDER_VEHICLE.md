# Placeholder vehicle (Issue 7)

This fixture provides a reusable model, seating, a consistent forward direction,
basic ground collision, and stationary acceptance checks. Player-controlled movement
is now implemented by [Issue 8](VEHICLE_MOVEMENT.md). Suspension, race spawning,
and automatic respawn remain later work. The enlarged wheels are welded, collidable cylinders; they slide over
the ground during this test rather than rotating on axles.

## One-time Studio setup

If the vehicle already exists, Issue 8 needs only Script Sync and
a new Play session. The Studio test applies 2.8-stud wheels to each spawned copy,
even when the saved template still has the original small wheels. No Command Bar
paste is required for testing. Output reports the wheel diameter and target speed.
The saved edit-mode template changes only if you deliberately rerun setup below.

1. Check out the current working branch locally and open the Development place.
2. Stop any play test. Start the existing native Script Sync connections.
   Keep the existing lowercase roots: `ServerScriptService/server` maps to
   `src/server`, `ReplicatedStorage/shared` maps to `src/shared`, and
   `StarterPlayer/StarterPlayerScripts/client` maps to `src/client`.
3. Open `tools/SetupPlaceholderVehicle.luau` in your editor, copy the entire
   file, paste it into Studio's **Command Bar**, and press **Ctrl + Enter**.
   This is an edit-mode setup command, not a synced game script.
4. Save the Development place. The command creates the template in
   `ServerStorage/VehicleTemplates/PlaceholderVehicle`, an invisible marker at
   `Workspace/PlaceholderVehicleSpawn`, and the boolean Workspace attribute
   `EnablePlaceholderVehicleTest = true`.
5. Press **Play**. A vehicle should appear about 14 studs to the world-right
   of the player spawn, on the ground below the marker. Wait for the
   stationary checks before sitting. Check Output for errors or warnings.

If the test area has no flat ground there, select `PlaceholderVehicleSpawn` in
Explorer and move it above an empty flat area. The marker's height is a raycast
starting point, not the final vehicle height. Keep it upright; Y rotation chooses
the vehicle's heading. Allow at least a clear 10 by 12 stud area and room overhead.

Setup is safe to rerun. On the first run of the enlarged-wheel version, it upgrades
the four existing wheels to fixed dimensions of 1.6 x 2.8 x 2.8 studs, moves their
centers to X = +/-3.6, enables their collision, and marks `WheelGeometryVersion = 2`.
Repeated runs do not double their size again. Other model and marker edits are
preserved. It re-enables the test attribute. To rebuild deliberately, rename the old template
in Studio first, then rerun setup. Do not put models or parts in Script Sync roots.
The setup file records the initial construction recipe; the saved Studio model
remains the source of truth for subsequent asset edits.

## Model contract

| Item | Purpose |
| --- | --- |
| `Chassis` | PrimaryPart, physics root, and body collider; 6 x 1.4 x 10 studs |
| `FrontMarker` | Green strip at local negative Z |
| `RearMarker` | Red strip at local positive Z |
| `DriverSeat` | VehicleSeat facing the same direction as Chassis; touch to sit |
| `DriverSeat/DriverAttachment` | Named reference at the seat surface for future mounting logic |
| Four named wheels | Massless, collidable cylinders, welded to Chassis; diameter 2.8, width 1.6 studs |
| WeldConstraints | Keep seat and decorations in one rigid assembly |

The model pivot is the chassis center. `vehicle:GetPivot().LookVector` is forward.
The DriverAttachment is a reference point; VehicleSeat supplies the actual
character weld. The stored chassis is anchored, while spawned copies are unanchored.
The chassis underside is at local Y = -0.7; wheel bottoms are at Y = -1.4.
This gives 0.7 studs of body clearance on flat ground. These dimensions apply to
the upgraded template and the automatic Studio-test overrides. Wheel friction is kept low
for the arcade movement controller. `VehicleService.getGroundSupport` measures the
lowest colliders for spawn height, ground detection, and acceptance checks.

## Reusing it from server code

```lua
local VehicleService = require(game.ServerScriptService.server.VehicleService)

-- Place the chassis center at a precise CFrame; caller provides free space.
local vehicle = VehicleService.spawn(CFrame.new(0, 5, 0))
vehicle:Destroy()

-- Find ground beneath an upright marker, preserving its heading.
-- Returns nil with a warning if there is no flat ground or a collider is blocked.
local marker = workspace.PlaceholderVehicleSpawn
local groundedVehicle = VehicleService.spawnOnGround(marker.CFrame)
```

Spawns clone the saved template into `Workspace/Vehicles`; they never move the
template out of ServerStorage. In Studio with `EnablePlaceholderVehicleTest = true`,
each copy receives the configured test wheel dimensions and collision before its
spawn height is measured. Outside that test, the saved model's geometry is used.
`spawnOnGround` excludes active vehicles from its
ground ray and checks each collidable part's volume for obstacles before spawning.
It assumes flat terrain beneath the vehicle, so inspect edges and overhangs
visually. Use separate clear positions when spawning multiple vehicles.

`VehicleTest.server.luau` creates one test vehicle per Studio session when the
Workspace attribute is enabled. It never auto-spawns in published servers.
Set `EnablePlaceholderVehicleTest` to false when a race system takes over spawning.
Movement uses server network ownership and the existing VehicleSeat. By default,
new VehicleService spawns receive controls automatically. Pass `false` as the second
argument to either spawn function for a passive fixture; enable controls later
with `vehicle:SetAttribute("MovementEnabled", true)`. The automatic Issue 7 checks
use passive copies and enable only the visible car once all checks pass.

## Driving the placeholder

Issue 8 replaces the old automatic seated-forward test. See
[Vehicle movement](VEHICLE_MOVEMENT.md) for W/S/A/D controls, tuning, and testing.
The wheels remain welded cylinders; no setup-command rerun or suspension is needed.
A ramp entry must meet the floor; a raised vertical lip is a separate obstacle.

## Acceptance checks in Studio

The initial play-test spawn and all original stationary acceptance checks were
confirmed in Studio's log on September 23, 2026 (including the 20:56 UTC run).
Rerun the checks after syncing the wheel override; that geometry is not yet verified.

With Script Sync connected, stop and restart Play after updating the branch.
`VehicleChecks` now runs automatically in the Studio test, taking about eight
seconds. It verifies the configured wheel dimensions and collision, connected assembly, seat/marker direction,
and settled floor contact beneath each supporting collider. It then spawns three
independent copies at 0, 90, and 180 degrees on a temporary isolated floor above
the map, checks their orientation and physics, and removes those copies and floor.
The original visible vehicle stays in place. The saved template must stay intact.

Output prints `[Issue 7] ALL AUTOMATED CHECKS PASSED` only if all those checks
succeed. Otherwise it reports the failing assertion. The visible model also gets
an `AcceptanceCheckStatus` attribute: `Running`, `Passed`, or `Failed`.
These checks validate structure and physics; visually inspect the vehicle and
test actual seating as well. Do not mark the issue complete based on syntax alone.

| Check | Expected result |
| --- | --- |
| Start Play and wait for automatic checks | One vehicle remains under `Workspace/Vehicles`; all automated checks pass |
| Wait 10 seconds on a flat floor | Vehicle rests on the floor without falling through or separating |
| Jump onto DriverSeat, then jump off | Avatar attaches facing the green front, then detaches |
| Stop, rotate marker 90 degrees around Y, Play again | Green nose follows the new marker heading |
| Stop/Play three times | Each session creates a fresh vehicle; template remains in ServerStorage |
| While playing, call `spawnOnGround` again at the occupied marker | Returns nil and warns; no overlapping duplicate |
| Move marker over empty space beyond the floor, then Play | Warns instead of spawning a falling vehicle |
| Disable the Workspace test attribute, then Play | No automatic test vehicle |
| Drive onto a shallow ramp with its entry flush to the floor | Rounded wheels meet the ramp; body stays clear and the vehicle climbs |
| Start a local server with two clients | Both clients see the same vehicle; only one driver occupies the seat |

Restore the marker over flat ground and the test attribute afterward if needed.
Save the place after edit-mode changes; Play-mode clones disappear when testing stops.

## Engine references

- [VehicleSeat](https://create.roblox.com/docs/reference/engine/classes/VehicleSeat)
- [Model pivots](https://create.roblox.com/docs/reference/engine/classes/Model)
- [WeldConstraint](https://create.roblox.com/docs/reference/engine/classes/WeldConstraint)
- [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams)
