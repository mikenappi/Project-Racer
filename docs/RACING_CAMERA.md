# Racing camera (Issue 10)

Enter your own DriverSeat to automatically use the chase camera. It gradually
swings behind the car as you turn, keeps a level horizon over bumps, and frames
some road ahead. Reversing keeps the same rear view instead of flipping around.
Leaving the seat or dying restores Roblox's normal character camera. Enter the
replacement car after respawn to reconnect automatically; spawning still does
not seat the player automatically.

## Implementation map

| File | Responsibility |
| --- | --- |
| `src/client/CameraController.local.luau` | Select the local player's owned, seated vehicle; control and release the camera; check obstructions |
| `src/client/CameraRig.luau` | Frame-rate-independent turn/position smoothing, level horizon, lag limits, teleport reset |
| `src/shared/CameraConfig.luau` | Camera distance, height, field of view, smoothing, and collision tuning |

Ownership uses the existing `OwnerUserId` attribute and `Workspace.Vehicles`.
No server code, movement settings, remote events, or vehicle assets are changed.
The target is checked every render frame, so delayed vehicle/chassis replication,
vehicle deletion, new characters, and CurrentCamera replacement can recover
without accumulating connections. The render callback runs after the default
camera and sets both CFrame and Focus while using Scriptable mode.

## Tuning

Edit CameraConfig and restart Play.

| Setting | Default | Effect |
| --- | --- | --- |
| `HeadingResponse` | 3.5 | Lower makes turns more floaty; higher catches up faster |
| `Distance` / `Height` | 24 / 10 studs | Camera placement behind/above chassis center |
| `LookAhead` | 5 studs | Amount of road ahead included in the framing |
| `FieldOfView` | 75 degrees | Width of view; kept constant while driving |
| `PositionResponse` | 16 | Higher tracks chassis translation more closely |
| `MaxHeadingLag` | 65 degrees | Prevents the camera orbiting around to the front |
| `MaxPositionLag` | 3 studs | Limits lag even with the current experimental 1000 speed cap |
| `CollisionReturnResponse` | 5 | Speed of easing back after a wall clears |

Keep response rates positive, heading lag below 90 degrees, and distances/radius
positive. The view intentionally ignores chassis roll and pitch. First seat
entry, a replacement car, and relocations over 100 studs in one frame establish
a fresh view rather than dragging the camera across the map. Normal driving uses
continuous smoothing. Collision pulls inward immediately to avoid crossing a
wall, then eases outward; tight spaces may bring the view very close to the car.
Spherecasts exclude the vehicle fleet and local character and respect collidable
geometry. A cast that starts inside geometry is an engine limitation; avoid
track surfaces intersecting the chassis/focus point. Full camera-volume recovery
from enclosed geometry and banked/looping anti-gravity tracks are outside this
initial camera's scope.

## Sync and Studio acceptance

1. Stop Play. Check out `feat/racing-camera` and sync the existing client and
   shared roots. Do not create additional roots or paste a setup command.
2. Under `StarterPlayer.StarterPlayerScripts.client`, confirm CameraController
   is a **LocalScript** and CameraRig is a **ModuleScript**. Under
   `ReplicatedStorage.shared`, CameraConfig must be a **ModuleScript**.
3. Play, enter your vehicle, accelerate, coast, brake, and reverse. The car should
   stay visible with room to see the road. Hold left/right, make a full circle,
   and alternate turns; the view should swing smoothly and catch up after release.
4. Drive across bumps/ramps. The horizon should stay level without copying wheel
   vibrations or chassis roll. Check Output for errors.
5. Drive near a wall: the camera should pull in and gradually return afterward.
6. Exit and reenter. On-foot camera controls should return, and reseating should
   restore the racing camera.
7. Reset while seated, then enter the replacement car. Repeat by falling off the
   map and respawning. The camera must follow the new car, never the deleted one.
8. Use a server with two clients. Each camera must follow only its own driver/car;
   attempt the other seat and confirm it does not acquire that car.
9. If available, compare lower and higher frame rates. The turn response should
   feel similar. Check a narrow window as well as fullscreen.

## Automated checks

From the repository root with the Luau CLI installed:

```sh
python tests/run_camera.py /path/to/luau
```

The harness runs the actual production sources against deterministic Roblox test
doubles. It checks 30/60/144 FPS easing, shortest-angle wrapping, continuous turns,
high-speed lag bounds, teleports, owner selection, seat exit, collision return,
camera replacement, missing chassis, respawn, and render-binding cleanup.
These checks do not establish rendered visibility, real collision/replication,
or subjective driving feel. Complete the Studio checklist before merging.

References: [Roblox camera customization](https://create.roblox.com/docs/workspace/camera),
[WorldRoot spherecasts](https://create.roblox.com/docs/reference/engine/classes/WorldRoot).
