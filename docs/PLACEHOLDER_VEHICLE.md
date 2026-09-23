# Placeholder vehicle (Issue 7)

This fixture provides a reusable model, seating, a consistent forward direction,
basic ground collision, and a temporary seated forward-motion test. Player-controlled
acceleration, steering, suspension, race spawning, and automatic respawn are later
work. The enlarged wheels are welded, collidable cylinders; they slide over
the ground during this test rather than rotating on axles.

## One-time Studio setup

1. Check out `feat/placeholder-vehicle` locally and open the Development place.
2. Stop any play test. Start the existing native Script Sync connections.
   Keep the existing lowercase roots: `ServerScriptService/server` maps to
   `src/server`, and `ReplicatedStorage/shared` maps to `src/shared`.
3. Open `tools/SetupPlaceholderVehicle.luau` in your editor, copy the entire
   file, paste it into Studio's **Command Bar**, and press **Ctrl + Enter**.
   This is an edit-mode setup command, not a synced game script.
4. Save the Development place. The command creates the template in
   `ServerStorage/VehicleTemplates/PlaceholderVehicle`, an invisible marker at
   `Workspace/PlaceholderVehicleSpawn`, and the boolean Workspace attribute
   `EnablePlaceholderVehicleTest = true`.
5. Press **Play**. A vehicle should appear about 14 studs to the world-right
   of the player spawn, on the ground below the marker. Jump onto the seat.
   Check Output for setup errors or warnings.

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
This gives 0.7 studs of body clearance on flat ground. Wheel friction is kept low
for the temporary sliding test. `VehicleService.getGroundSupport` measures the
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
template out of ServerStorage. `spawnOnGround` excludes active vehicles from its
ground ray and checks each collidable part's volume for obstacles before spawning.
It assumes flat terrain beneath the vehicle, so inspect edges and overhangs
visually. Use separate clear positions when spawning multiple vehicles.

`VehicleTest.server.luau` creates one test vehicle per Studio session when the
Workspace attribute is enabled. It never auto-spawns in published servers.
Set `EnablePlaceholderVehicleTest` to false when a race system takes over spawning.
This fixture uses server network ownership; future controls must choose their
own ownership policy. No client input, RemoteEvents, or race logic is added here.

## Seated forward-motion test

After the automatic checks pass (about eight seconds after Play), Output prints
`Forward-motion test ready`. Sit in DriverSeat to move toward the green nose at a
target of 12 studs/second. Jump out to apply the brake. An anchored collidable wall
should block the car; movable objects may be pushed. There is no steering yet.
Stop/Play resets the vehicle to its marker.

`VehicleTestDrive` uses a force-limited horizontal LinearVelocity constraint.
It applies drive only for a living player in the seat while the car is upright
and on the ground. Gravity and collision remain active. An empty seat targets zero
horizontal velocity for braking; braking takes a short distance rather than
teleporting the vehicle to a stop. The mover is disabled in the air or when tipped.
The test activates only on the visible Studio fixture after its stationary checks;
it is not attached to the saved template or the temporary acceptance-test copies.

Tune `TestDriveSpeed` and `TestDriveAcceleration` in `VehicleConfig`, or set
`TestDriveEnabled = false` to return to the stationary fixture. Restart Play
after changing configuration. No setup-command rerun is needed for this feature.

The current wheels are 2.8 studs in diameter and provide rounded ground collision.
They remain welded, so this is not rolling-wheel traction or suspension. Inspect
the proportions while riding, then test a shallow ramp, an anchored wall, and
jumping off. A ramp's entry should meet the floor: a raised vertical lip is a
separate obstacle from its slope. The enlarged-wheel ramp behavior still needs
to be confirmed in Studio.

## Acceptance checks in Studio

The initial play-test spawn and all original stationary acceptance checks were
confirmed in Studio's log on September 23, 2026 (including the 20:56 UTC run).
Rerun the checks after upgrading the wheels; that geometry is not yet verified.

With Script Sync connected, stop and restart Play after updating the branch.
`VehicleChecks` now runs automatically in the Studio test, taking about eight
seconds. It verifies the visible model's connected assembly, seat/marker direction,
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
