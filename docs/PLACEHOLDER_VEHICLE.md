# Placeholder vehicle (Issue 7)

This fixture provides a reusable model, seating, a consistent forward direction,
and basic ground collision. Acceleration, steering, suspension, race spawning,
and automatic respawn are later work. The wheels are welded visual placeholders.

## One-time Studio setup

1. Check out `feat/placeholder-vehicle` locally and open the Development place.
2. Stop any play test. Start the existing native Script Sync connections.
   Keep the existing lowercase roots: `ServerScriptService/server` maps to
   `src/server`, and `ReplicatedStorage/shared` maps to `src/shared`.
3. Open `tools/SetupPlaceholderVehicle.luau` in your editor, copy the entire
   file, paste it into Studio's **Command Bar**, and press Enter.
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
the vehicle's heading. Allow at least a clear 8 by 12 stud area and room overhead.

Setup is safe to rerun: existing template and marker edits are preserved.
It re-enables the test attribute. To rebuild deliberately, rename the old template
in Studio first, then rerun setup. Do not put models or parts in Script Sync roots.
The setup file records the initial construction recipe; the saved Studio model
remains the source of truth for subsequent asset edits.

## Model contract

| Item | Purpose |
| --- | --- |
| `Chassis` | PrimaryPart, physics root, and the only collidable part; 6 x 1.4 x 10 studs |
| `FrontMarker` | Green strip at local negative Z |
| `RearMarker` | Red strip at local positive Z |
| `DriverSeat` | VehicleSeat facing the same direction as Chassis; touch to sit |
| `DriverSeat/DriverAttachment` | Named reference at the seat surface for future mounting logic |
| Four named wheels | Non-collidable, massless decoration, welded to Chassis |
| WeldConstraints | Keep seat and decorations in one rigid assembly |

The model pivot is the chassis center. `vehicle:GetPivot().LookVector` is forward.
The DriverAttachment is a reference point; VehicleSeat supplies the actual
character weld. The stored chassis is anchored, while spawned copies are unanchored.
The chassis underside and visible wheel bottoms align at local Y = -0.7.
If you change these dimensions, update the ground-placement calculation as needed.

## Reusing it from server code

```lua
local VehicleService = require(game.ServerScriptService.server.VehicleService)

-- Place the chassis center at a precise CFrame; caller provides free space.
local vehicle = VehicleService.spawn(CFrame.new(0, 5, 0))
vehicle:Destroy()

-- Find ground beneath an upright marker, preserving its heading.
-- Returns nil with a warning if there is no flat ground or the chassis is blocked.
local marker = workspace.PlaceholderVehicleSpawn
local groundedVehicle = VehicleService.spawnOnGround(marker.CFrame)
```

Spawns clone the saved template into `Workspace/Vehicles`; they never move the
template out of ServerStorage. `spawnOnGround` excludes active vehicles from its
ground ray and checks the chassis volume for obstacles before spawning.
It assumes flat terrain beneath the full chassis, so inspect edges and overhangs
visually. Use separate clear positions when spawning multiple vehicles.

`VehicleTest.server.luau` creates one test vehicle per Studio session when the
Workspace attribute is enabled. It never auto-spawns in published servers.
Set `EnablePlaceholderVehicleTest` to false when a race system takes over spawning.
This fixture uses server network ownership; future controls must choose their
own ownership policy. No client input, RemoteEvents, or race logic is added here.

## Acceptance checks in Studio

These checks must pass before Issue 7 is closed. They have not been run remotely.

| Check | Expected result |
| --- | --- |
| Start Play | Exactly one vehicle appears under `Workspace/Vehicles`; no errors |
| Wait 10 seconds on a flat floor | Vehicle rests on the floor without falling through or separating |
| Jump onto DriverSeat, then jump off | Avatar attaches facing the green front, then detaches |
| Stop, rotate marker 90 degrees around Y, Play again | Green nose follows the new marker heading |
| Stop/Play three times | Each session creates a fresh vehicle; template remains in ServerStorage |
| While playing, call `spawnOnGround` again at the occupied marker | Returns nil and warns; no overlapping duplicate |
| Move marker over empty space beyond the floor, then Play | Warns instead of spawning a falling vehicle |
| Disable the Workspace test attribute, then Play | No automatic test vehicle |
| Start a local server with two clients | Both clients see the same vehicle; only one driver occupies the seat |

Restore the marker over flat ground and the test attribute afterward if needed.
Save the place after edit-mode changes; Play-mode clones disappear when testing stops.

## Engine references

- [VehicleSeat](https://create.roblox.com/docs/reference/engine/classes/VehicleSeat)
- [Model pivots](https://create.roblox.com/docs/reference/engine/classes/Model)
- [WeldConstraint](https://create.roblox.com/docs/reference/engine/classes/WeldConstraint)
- [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams)
