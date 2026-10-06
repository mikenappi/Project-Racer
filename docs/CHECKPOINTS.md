# Checkpoints and manual vehicle reset

`RaceManager.server.luau` starts the shared vehicle lifecycle and reset listener,
then starts a checkpoint sequence for connected players. Late joiners start at
zero, following the existing policy that everyone is a racer. A failed start
warns and leaves an existing race intact. There is no countdown, lap wrap,
automatic next race, finish detection, or placement added by this feature.

The server accepts a checkpoint only from a touch by the player's current owned
vehicle with its living owner in DriverSeat. Only the next index is accepted.
Progress is private per-player state; `LastCheckpoint` is a display attribute,
never validation input. The final index remains final until a new race.
Leaving clears progress; character/car replacement preserves it.

R sends an empty `Remotes.ResetVehicle` request. The server chooses the current
owned model and the last accepted checkpoint's snapshotted CFrame. Before any
checkpoint it uses the lifecycle's spawn slot. Reset is allowed for a living
owner with an empty car or their own occupied seat. Other occupants are rejected.
Requests, including failed requests, have a two-second cooldown in RaceConfig.
The car is placed upright on flat ground using the existing collider/overlap
checks. Blocked or missing ground leaves it unchanged; retry with R after clearing
the destination. No random fallback or destructive replacement occurs.

Reset retains the model, slot, ownership and seated rider. Linear/angular velocity
is cleared and the movement controller clears cached input and steering on its
next PreSimulation step using `ResetVersion`, independently of deferred events.
No client checkpoint index, target model or destination is trusted.

## Studio setup

1. Open **Project-Racer**, stop Play, and sync the existing `src/server`,
   `src/client`, and `src/shared` roots. Keep the existing Script Sync layout.
   `RaceManager` is a Script; CheckpointService and RespawnService are ModuleScripts.
2. Keep the existing vehicle template and ground/spawn setup from VEHICLE_SPAWNING.md.
3. In Workspace create a **Folder** named `Checkpoints`. Insert direct-child
   **Parts** named `1`, `2`, `3`, etc., with no gaps, duplicates or other children.
   At least one marker is required.
4. For each marker set Anchored=true, CanCollide=false, CanTouch=true,
   CanQuery=false. Rotate only around Y; its LookVector is the reset heading.
   Span the drivable lane with its trigger volume, including the car chassis
   height. Example on ground Y=0: center Y=4, height=8, depth=2, lane-width X.
   The marker's center X/Z must have flat clear ground beneath it and enough
   clearance for the whole car. Space markers so their volumes do not overlap.
   Transparency=0.7 helps setup; it can later be set to 1.
5. Start Play. RaceManager automatically begins the sequence. If marker validation
   fails, fix it in edit mode and restart Play. Cars continue to work without a
   valid sequence, but manual checkpoint reset is unavailable until race start.

To restart during Play from the **server** Command Bar (standard server sync root):

```lua
game:GetService("ServerScriptService"):WaitForChild("server")
    :WaitForChild("RaceManager"):WaitForChild("StartRace"):Fire()
```

This BindableEvent lives under the actual RaceManager Script and is server-only.
If your existing root has a different Studio name, use that Script's path.
Successful start rereads markers, disconnects prior handlers and resets all current
players to zero. It does not teleport cars or clear the reset-request cooldown.
Edit markers between races and fire StartRace to capture their new transforms.

## Source validation

```sh
python tests/run_checkpoints.py /path/to/luau
python tests/run_vehicle_lifecycle.py /path/to/luau
```

The checkpoint suite reuses the established lifecycle simulator and executes the
actual modules, RaceManager start/restart path, remote listener and client reset
binding. It covers order, repeats/skips, player isolation, eligibility, spoofed
attributes/payloads, restart, invalid setup, join/leave, car replacement, spawn
fallback, cooldown, blocked/missing ground, upright reset, rider movement, zero
velocity, server ownership, and controller input reset. Geometry support is stubbed
in the ground-reset unit fixture; these tests do not validate real physics,
Touched delivery, replication, or seat weld behavior.

## Required Studio validation (pending)

The connected Studio during implementation was an unrelated unpublished Place8
containing StormglassServer. It was inspected read-only and not modified.

1. In Project-Racer Play, drive through 2 before 1; inspect the player's
   LastCheckpoint attribute: it stays 0. Drive through 1 twice, then 3; it stays 1.
   Drive through 2 then 3; it reaches 3. Retracing the course must not wrap to 1.
2. Press R before checkpoint 1: return to your starting slot. After checkpoint 1,
   drive away/flip the car and press R: return upright at checkpoint 1, stopped,
   still seated and able to resume driving. Check the camera follows the same car.
3. Block the checkpoint destination with a collidable part, drive away, and press
   R. Car and progress must remain unchanged. Clear it, wait two seconds, retry.
   Repeat with missing ground and with another player's car occupying the reset.
4. Run two clients: reach different checkpoints and reset each. Verify independent
   destinations, no overlapping cars, and no progress from touching on foot,
   empty vehicles or another player's occupied car. Leave/rejoin and verify zero.
5. Fire StartRace on the server: both players return to progress zero. R now uses
   their separate starting slots. Repeat restart to detect duplicated callbacks.
6. Die/respawn after checkpoint 1: the normal lifecycle makes one car in the same
   spawn slot, and R returns that new car to checkpoint 1. Repeat fall recovery.
7. Confirm typing R in chat does not reset, rapid requests are limited, and the
   existing driving and stationary vehicle checks still behave correctly.

Do not publish as part of these checks.
