# Basic vehicle movement (Issue 8)

Issue 7 / PR #13 was merged before this work. The Issue 8 branch
`feat/basic-vehicle-movement` starts at `main` commit `d908a99`.
The existing chassis, VehicleSeat, green nose, welds, enlarged wheels, saved template,
and spawn marker are preserved. The setup tool needs no changes or rerun.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| `src/shared/VehicleConfig.luau` | Speed, acceleration, braking, coasting, steering, grip, stability, and input timing |
| `src/server/VehicleController.server.luau` | Validated input, physics, controller lifetime, and server ownership |
| `src/client/InputController.local.luau` | Read the existing VehicleSeat's ThrottleFloat/SteerFloat; send input at 20 Hz |
| `src/server/VehicleService.luau` | Existing cloning and spawning; new optional movementEnabled argument |
| `src/server/VehicleTest.server.luau` | Spawn the Studio fixture, run Issue 7 checks, then enable player controls |
| `src/server/VehicleChecks.luau` | Keep temporary stationary acceptance copies passive |
| `tools/SetupPlaceholderVehicle.luau` | Unchanged: physical placeholder creation/upgrades only |

The obsolete `VehicleTestDrive.luau` is removed so automatic forward motion cannot
compete with player controls. Its `TestDrive*` configuration is removed as well.

Within the server controller:

| Function | Behavior |
| --- | --- |
| `getDriveTarget` | W acceleration, S braking/reverse, reverse-to-forward braking, neutral coasting, exit braking |
| `stepVehicle` / `getYawTarget` | Speed caps, finite drive/brake force, sideways grip, speed-sensitive steering, ramp alignment |
| `getGroundNormal` | Wheel-area ground probes; no suspension forces |
| `getDriver` / RemoteEvent handler | Require a living seated player, reject invalid numbers, clamp/rate-limit input |
| `startVehicle` / `resetDriver` | Create runtime movers, keep server ownership, clear previous-driver input |
| `watchVehicle` / `stopVehicle` | Enable/disable controls and clean up when a vehicle leaves Workspace/Vehicles |

## Controls and physics

- **W:** accelerate toward the green nose.
- **S:** brake while travelling forward; reverse once below `StopSpeed`.
- **W while reversing:** brake before accelerating forward.
- **A/D:** left/right steering; reversing changes the yaw direction like a car.
- **Release W/S:** coast, then hold at rest on flat ground.
- **Jump out, die, or stop sending input:** brake; never leave the old throttle latched.

The server reads actual speed each step and chooses a bounded target. A horizontal
LinearVelocity with separate forward/sideways force limits supplies acceleration
and grip at the assembly's center of mass. It does not teleport the model or
overwrite its velocity. Vertical motion remains free for gravity and ramps.
An AngularVelocity constraint has finite torque, smooths steering, damps unwanted
rotation, and aligns the chassis toward the detected ground normal.

Assistance switches off when airborne or severely tipped. This is not suspension,
an automatic flip recovery, or a realistic wheel drivetrain. Stop/Play resets the
fixture. Welded wheels do not visibly rotate.

Speed settings describe **horizontal forward/reverse speed**. Normal powered
driving targets cannot exceed the configured values. External impacts, downhill
gravity, or airtime can temporarily exceed them; grounded braking brings the car
back toward its cap. This preserves collision response instead of forcibly
discarding outside impulses. Verify actual limits in Studio before acceptance.

The client sends seat inputs only. The server checks that the sender occupies that
exact registered seat, rejects NaN/infinity, clamps values, rate-limits accepted
updates, and brakes after a timeout. It does not accept client speed or position.
Server ownership is intentionally simple for M0; test responsiveness with two
clients before considering prediction or client-owned physics in a later issue.

## Exact Studio setup and test

1. Open the Development place and stop Play. The local repository should be on
   `feat/basic-vehicle-movement`.
2. Start the existing **Script Sync** connections. Keep these exact mappings:

   | Local directory | Studio root |
   | --- | --- |
   | `src/server` | `ServerScriptService/server` |
   | `src/shared` | `ReplicatedStorage/shared` |
   | `src/client` | `StarterPlayer/StarterPlayerScripts/client` |

3. In Explorer, confirm `server/VehicleController` is a **Script**,
   `shared/VehicleConfig` is a **ModuleScript**, and `client/InputController`
   is a **LocalScript**. If sync shows the old `VehicleTestDrive`, remove that
   obsolete ModuleScript. Do not create duplicate uppercase or nested roots.
4. Confirm the existing template is at
   `ServerStorage/VehicleTemplates/PlaceholderVehicle`, and
   `Workspace.EnablePlaceholderVehicleTest` is true. Leave the spawn marker
   above clear flat ground. Only if the template is missing, paste the entire
   unchanged setup tool into the edit-mode Command Bar and press **Ctrl+Enter**.
5. Open **Output** from Studio's Window/View menu. Press **Play** (F5), and stay
   off the car for about eight seconds. Expect the Issue 7 checks to pass,
   followed by `[Issue 8] Controls ready`.
6. Sit in DriverSeat, click the game viewport to focus input, and test W/S/A/D.
   Stop Play before changing configuration; restart to reload ModuleScripts.
7. Save the Development place after any edit-mode changes. Do not merge until
   the tests below pass.

During Play, switch Studio to **Server**, select
`Workspace/Vehicles/PlaceholderVehicle`, and inspect its Attributes:
`ForwardSpeed` is signed horizontal speed, `MovementGrounded` indicates support,
and `MovementInputActive` indicates valid recent driver input. ForwardSpeed
excludes vertical falling speed.
No movers or RemoteEvents need to be pasted into the Command Bar.

## Acceptance checklist

| Criterion | Test | Expected result |
| --- | --- | --- |
| Forward/reverse/steer | Hold W on flat ground; release; hold S from forward speed and keep holding | Smooth acceleration, coasting stop, braking before reversal |
| Forward/reverse/steer | Try A and D going forward, then in reverse; try steering while stationary | Correct directions; no stationary spin; reversed yaw when backing up |
| Bounded speed | Hold W for 15 seconds in a clear straight line; repeat S in reverse | ForwardSpeed plateaus near +48 and -18; never keeps increasing |
| Adjustable variables | Set MaxForwardSpeed to 30, MaxReverseSpeed to 10, Acceleration to 25; restart Play | Lower caps and slower acceleration without controller edits |
| Adjustable variables | Change Braking, CoastDeceleration, and TurningStrength individually; restart each time | Clearly different stopping/coasting/turning behavior |
| Stable driving | Alternate A/D at low speed and full speed on flat ground | Controlled turns, limited sideways sliding, no persistent spin/tipping |
| Stable driving | Climb/descend a shallow ramp whose entry meets the floor | Ground contact and gravity retained; no hovering or forced flattening |
| Stable driving | Hit an anchored wall at a moderate speed; release throttle | Wall blocks the vehicle; no teleporting through it or runaway acceleration |
| Stable driving | Drive off a small ledge | Falls naturally; air steering/traction disabled; resumes after landing |
| Lifecycle | Jump out while moving; re-enter; reset character; Stop/Play three times | Empty/dead driver brakes; no stale throttle, duplicate movers, or Output errors |
| Multiplayer | Test tab → Server & Clients, choose 2 clients, Start; let each player drive in turn | Both see the same motion; only the current driver can steer; handoff clears input |

For a two-vehicle check, while playing on the **Server**, run this in Command Bar
(it attempts a second spawn 20 studs to the marker's right; use a clear area):

```lua
local service = require(game.ServerScriptService.server.VehicleService)
service.spawnOnGround(workspace.PlaceholderVehicleSpawn.CFrame * CFrame.new(20, 0, 0))
```

Each player should independently control their own car. In the non-driving client,
pressing W/S/A/D must not change the other car. Remove a test car in the Server
Explorer and spawn again to check that no stale controller keeps running.

## Tuning

All values are in `src/shared/VehicleConfig.luau`; restart Play after editing.

| Setting | Default | Effect |
| --- | --- | --- |
| MaxForwardSpeed | 48 | Forward cap, studs/second |
| MaxReverseSpeed | 18 | Reverse cap, studs/second |
| Acceleration | 45 | Available acceleration, studs/second squared |
| Braking | 90 | Opposite-input, exit, timeout, and near-rest brake strength |
| CoastDeceleration | 12 | Slowing when W/S is released; higher stops sooner |
| StopSpeed | 0.75 | Near-stop threshold for direction changes and holding still |
| TurningStrength | 1.6 | Maximum yaw rate, radians/second |
| SteeringFullSpeed | 12 | Speed where low-speed steering reaches full strength |
| HighSpeedSteeringScale | 0.55 | Steering multiplier at forward maximum speed |
| SteeringResponse | 8 | How quickly steering builds and settles |
| LateralGrip | 90 | Available sideways correction acceleration |
| StabilityStrength | 6 | Pitch/roll correction toward the ramp/floor normal |
| MaxTiltCorrection | 2 | Maximum corrective pitch/roll rate |
| AngularTorquePerMass | 600 | Torque budget for steering and stability |

Acceleration/braking are force-per-mass limits; friction and slopes affect measured
acceleration. Tune speed and acceleration first, then braking/coasting, then turning
and grip. Keep acceleration/braking/coasting positive. Ground and network settings
are grouped below the main tuning values and normally need no changes.

## Validation status

Pre-Studio validation passed:

- All 15 Luau files (including the unchanged setup tool) compile with the Luau CLI.
- Roblox-aware Luau LSP analysis reports no errors for the controller, input relay,
  and config, using a temporary source map matching the Script Sync roots.
- Extracted controller-function checks cover braking before direction changes,
  forward/reverse limits, neutral/timeout braking, analog input, steering signs,
  low/high-speed steering, invalid numbers, and changed configuration.
- Git whitespace checks pass.

Engine-independent checks do not establish the acceptance criteria by themselves.
Studio driving, ramp/wall physics, input replication, and two-client responsiveness
must still be tested using the checklist above before merge.

## Engine references

- [VehicleSeat](https://create.roblox.com/docs/reference/engine/classes/VehicleSeat)
- [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity)
- [AngularVelocity](https://create.roblox.com/docs/reference/engine/classes/AngularVelocity)
- [Network ownership](https://create.roblox.com/docs/physics/network-ownership)
