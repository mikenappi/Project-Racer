# Player vehicle spawning (Issue 9)

Each connected player is treated as a racer for now. After their living character
appears, the server gives them one vehicle cloned from the existing placeholder.
Enter its DriverSeat to drive. Automatic seating and race/lobby selection are not
part of this issue.

## Where each part lives

| File | Responsibility |
| --- | --- |
| `src/server/PlayerVehicles.server.luau` | Starts the lifecycle service once |
| `src/server/PlayerVehicleService.luau` | Player slots, character lifecycle, owned vehicle lookup, retries, and cleanup |
| `src/server/VehicleService.luau` | Existing template cloning, ground placement, overlap checks, and initial owner attribute |
| `src/server/VehicleController.server.luau` | Existing movement; now also refuses drivers who do not own the car |
| `src/shared/VehicleConfig.luau` | Spawn grid, retry interval, recovery height, and existing movement settings |
| `src/server/VehicleTest.server.luau` | Preserved standalone stationary checks, available when player spawning is disabled |

`PlayerVehicleService.getVehicle(player)` returns that player's active vehicle,
or nil while awaiting a character or an available spawn. Other server systems
can require this module without starting a second lifecycle.

## Spawn locations

No setup command needs to be pasted again for the existing Development place.
With no `Workspace.VehicleSpawns` folder, the service uses the existing
`Workspace.PlaceholderVehicleSpawn` as the first slot and grid origin.

- Three columns by default, spaced 16 studs right and 20 studs backward.
- Positions and forward direction rotate with the origin marker.
- A player keeps their slot through death and respawn.
- Leaving frees that slot for the next player; remaining players keep theirs.
- Spawn height uses the existing ground probe and the cloned model's colliders.
- Each slot needs clear, flat, collidable ground below it.

For authored positions, create `Workspace.VehicleSpawns` containing BaseParts
named `1`, `2`, `3`, etc. These replace the fallback grid. Provide one marker
per concurrent player. Keep them anchored, noncollidable, non-touchable, and
non-queryable; place them above the ground, rotated only around Y. Their
LookVector points in the car's forward direction.

Missing markers, blocked slots, or missing templates produce one warning per
failure period and retry once a second by default. Cars are not stacked or
placed at unrelated random positions. Clearing the obstruction allows spawning.
Ground probes exclude player characters so heads cannot become spawn surfaces;
overlap checks still protect characters from being intersected by a new car.

## Ownership and cleanup

The active model is named `Vehicle_<UserId>` under `Workspace.Vehicles`.
Its `OwnerUserId` attribute identifies its owner; `SpawnSlot` identifies its slot.
The player also has a `VehicleSpawnSlot` attribute for inspection.
Ownership is assigned before the model enters Workspace. The server checks both
ownership and the living seat occupant before accepting input; another player
who sits in the car is unseated.

| Event | Result |
| --- | --- |
| Join / character appears | Spawn one vehicle when the character is alive |
| Character dies or is removed | Destroy their old vehicle and its movement state |
| Character respawns | Create a fresh car in the same slot |
| Car falls below the recovery threshold | Remove it and replace it if its player is alive |
| Car is destroyed, leaves the active folder, or loses its chassis/seat | Remove remnants and retry spawning |
| Player leaves | Remove car, disconnect player/character events, and release slot |
| Player exits their seat | Keep their car; the existing movement system brakes it |

The recovery threshold is `Workspace.FallenPartsDestroyHeight +
VehicleRecoveryHeight` (50 studs above the engine's destruction height by default).
This also recovers an empty car that falls off the map. If a seated driver falls
with it, normal Roblox character death/respawn still applies; the service does
not teleport or automatically reseat the driver. Adjust the threshold for maps
with legitimate driving areas near the destruction height.

## Stationary checks and driving feel

The Issue 7 checks remain unchanged. To run their original standalone fixture,
set `PlayerVehiclesEnabled = false` in VehicleConfig and keep the place's
`EnablePlaceholderVehicleTest` attribute true, then restart Play.

Normal player spawning skips that fixture, so there is no additional unowned car
or temporary check cars alongside the player fleet. Future countdown work can
integrate pre-race validation. The existing check suite creates temporary cars
and waits for them to settle, so it should not simply be run once per racer on
an occupied starting grid.

Acceleration, gliding, steering, input timing, and server physics ownership are
unchanged. This issue does not attempt to tune away the reported seat-entry delay.

## Studio setup and acceptance

1. Check out `feat/player-vehicle-spawning` locally and sync all three existing
   Script Sync roots. Stop and restart Play after syncing.
2. Confirm `PlayerVehicles` is a Script and `PlayerVehicleService` is a
   ModuleScript under the existing server root. No new sync root is needed.
3. In Play, inspect `Workspace.Vehicles`: one model, correct OwnerUserId and
   SpawnSlot, no extra standalone fixture. Enter it and verify the existing feel.
4. Reset the character. The old car must disappear and a new car must appear in
   the same slot. Repeat while seated and while standing outside the car.
5. Drive off the map. After the character respawns, verify the new car is present.
   Separately push an empty car below the recovery height; it should be replaced.
6. Start a server with two clients. Confirm two distinct models and owners at
   separate positions, independent controls, and refusal of the other player's seat.
7. Disconnect one client. Only its car disappears. Rejoin; the freed slot is reused.
8. Block a spawn with a collidable part, then reset that player. Confirm no
   overlapping car appears. Remove the block and confirm one car spawns on retry.
9. In the server view, delete one car (or its Chassis/DriverSeat). Verify one
   replacement, with no abandoned model or movement constraints.
10. For heading checks, rotate the origin 90 degrees in edit mode; both the grid
    and cars should follow its orientation. Test numbered markers if used.

Command-line lifecycle tests use simulated Roblox events and instances; they
cannot establish seat weld behavior, physical collision, replication, or driving
feel. Complete the Studio checks before merging and closing Issue 9.

Run the repeatable lifecycle checks from the repository root with Python and the
Luau CLI installed:

```sh
python tests/run_vehicle_lifecycle.py /path/to/luau
```

The harness executes the actual PlayerVehicleService source with deterministic
events and clock values. It covers startup, two owners, character readiness,
death, stale callbacks, stable rotated slots, missing/blocked spawns, retries,
asset errors, lost cars/chassis/seats, leave cleanup, and slot reuse.
