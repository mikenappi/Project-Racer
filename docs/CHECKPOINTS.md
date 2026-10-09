# Checkpoints, laps, and manual vehicle reset

`RaceManager.server.luau` initializes the existing vehicle/recovery services and
one authoritative RaceService. See [RACE_LIFECYCLE.md](RACE_LIFECYCLE.md) for
Waiting -> Loading -> Countdown -> Racing -> Results -> Waiting, readiness,
late-join policy, controls, cleanup, and issue #18 validation. Checkpoints and
laps (issue #17) advance only for active participants during Racing. This lifecycle
supersedes the immediate-start/restart policy described in earlier validation
records below. Finish order/results presentation remains separate issue #24/#26 work.

The server accepts a checkpoint only from a touch by the player's current owned
vehicle with its living owner in DriverSeat. Only the next index is accepted.
Progress is private per-player state; `LastCheckpoint` is a display attribute,
never validation input. The final index remains final until a validated finish crossing.
On a non-final lap that crossing increments completed laps and resets the sequence
to zero, requiring checkpoint 1 next. On the final lap it latches completion and
leaves the checkpoint index at N; further checkpoint/finish touches do nothing.
Leaving clears progress; character/car replacement preserves it and recovers the
new car and living owner at that checkpoint. Before checkpoint 1, the normal spawn
slot is used on the first lap. Across a lap boundary the last earned reset frame
is retained independently of the new sequence. Recovery at checkpoint N cannot
restore N/N or award a lap. A blocked checkpoint respawn retries instead of falling back to the grid.

R sends an empty `Remotes.ResetVehicle` request. The server chooses the current
owned model and the last accepted checkpoint's snapshotted CFrame. Before any
checkpoint it uses the lifecycle's spawn slot. Reset is allowed for a living
owner with an empty car or their own occupied seat. Other occupants are rejected.
Requests, including failed requests, have a two-second cooldown in RaceConfig.
The car is placed upright on flat ground using collider/overlap checks.
Bounding-box candidates are confirmed against actual collision geometry so a
hollow mountain mesh does not block clear road. Ground height is captured at race
start so later obstacles cannot become a raised reset surface. Blocked or missing ground leaves it unchanged; retry with R after clearing
the destination. No random fallback or destructive replacement occurs.

Manual reset retains the model, slot and ownership. A seated rider moves with it;
an on-foot owner moves to DriverSeat and is seated. Reset from another vehicle
is refused. Automatic checkpoint recovery also seats the owner in the new car. Linear/angular velocity
is cleared and the movement controller clears cached input and steering on its
next PreSimulation step using `ResetVersion`, independently of deferred events.
No client checkpoint index, target model or destination is trusted.

The existing RaceHUD shows `Lap current / total`, `Checkpoint n / total`, the R control and reset
feedback. It observes server-owned player attributes and survives character
respawn; it does not maintain or submit race progress.

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
5. Create an anchored, noncollidable, nonqueryable, touchable BasePart named
   `FinishLine` directly under Workspace, spanning the start/finish lane at car
   height. Keep it separate from checkpoint volumes. Set Transparency=1 to hide
   the trigger. The existing Development place now has this part over the
   checkered line in `Workspace.Model.StartTrack` (see issue #17 results below).
   Keep it upright, with its center plane aligned to the visible line and its
   LookVector pointing in the forward race direction. Local X spans the lane,
   local Y spans the permitted car height, and local Z is trigger depth.
   Changing its transform or size during a race disables finish detection until
   the next race captures the new geometry.
6. Set `RaceConfig.TotalLaps` (default 3). `FinishPartName` selects the finish part;
   `CheckpointFolderName` selects the folder whose contiguous markers determine N.
   The lap target is validated and captured at each successful race start.
7. Start Play and sit in your car. RaceManager admits players after Waiting,
   validates the sequence in Loading, then runs Countdown before unlocking Racing.
   Invalid setup times out to Results and returns to Waiting; fix markers in edit
   mode. Cars and checkpoint/reset requests remain gated outside Racing.

To restart during Play from the **server** Command Bar (standard server sync root):

```lua
game:GetService("ServerScriptService"):WaitForChild("server")
    :WaitForChild("RaceManager"):WaitForChild("StartRace"):Fire()
```

This BindableEvent lives under the actual RaceManager Script and is server-only.
If your existing root has a different Studio name, use that Script's path.
StartRace now requests Loading only from Waiting; active-race requests are ignored.
Loading rereads markers and resets the admitted roster to zero. Waiting clears
checkpoint/lap/recovery state and reset cooldowns. Cars are not teleported to a
new grid by this issue (#19 owns that integration). Edit markers between races.

## Lap state and issue #24 integration

`CheckpointService` owns checkpoints and the single server finish detector.
Both accept only the current owned vehicle with its living owner in DriverSeat.
Checkpoint touches retain their existing ordered validation. Finishing samples
the owned vehicle's PrimaryPart (chassis) on server Heartbeat after checkpoint N.
The chassis must cross the finish part's center plane in its LookVector direction;
the interpolated crossing point must fall within the part's local X/Y bounds.
Sweeping between samples detects fast cars even when neither sample overlaps the
thin trigger. First contact by a bumper or wheel does not award progress.
Finishing consumes a complete sequence without yielding, so lingering, jitter,
and duplicate contacts cannot award another lap. Skipped checkpoints cannot
qualify a finish. Invalid drivers, non-racing participants, resets (ResetVersion),
and replacement vehicles/chassis discard the previous crossing sample.

Server consumers call `CheckpointService.getRaceProgress(player)` for a detached
snapshot: `completedLaps` starts at 0, `currentLap` starts at 1 and is capped at
`totalLaps`, and `lapComplete` becomes true only after the required final crossing.
Despite its short name, `lapComplete` means all required laps are complete. It
stays true until a new race or racer removal. Issue #24 should consume this
validated terminal state to record results, rather than add another finish detector.
There is no finish-order or timing implementation in this change.

Player attributes `CompletedLaps`, `CurrentLap`, `TotalLaps`, and `LapComplete`
mirror that state for display only. The HUD never submits race state. A successful
start resets all lap/checkpoint/recovery data; admitted participants start at zero
completed laps, while late joiners wait for the next race, and leaving clears the state and attributes. Invalid track/configuration
leaves an existing race untouched.

## Source validation

```sh
python tests/run_checkpoints.py /path/to/luau
python tests/run_race_lifecycle.py /path/to/luau
python tests/run_vehicle_lifecycle.py /path/to/luau
```

The checkpoint suite reuses the established lifecycle simulator and executes the
actual checkpoint/recovery modules, direct checkpoint start/restart path, remote
listener and client reset binding. `run_race_lifecycle.py` covers the current actual
RaceManager path and state-dependent participation policy. It covers order, repeats/skips, player isolation, eligibility, spoofed
attributes/payloads, restart, invalid setup, join/leave, car replacement, spawn
fallback, cooldown, blocked/missing ground, upright reset, rider movement, zero
velocity, server ownership, and controller input reset. Additional coverage checks delayed character root creation, automatic checkpoint
recovery, on-foot seating, ground-level snapshots, and hollow-mesh false positives.
Geometry support is stubbed
in the ground-reset unit fixture; these tests do not validate real physics,
Touched delivery, replication, or seat weld behavior.

## Studio validation

The initial implementation was source-tested only. Follow-up validation uses
Project-Racer Development (place 130359159608842, universe 8788799405).
All 18 source scripts matched Git before edits, and edits automatically propagated
through the three existing sync roots. No remapping was needed.

Markers 1-7 had upward-facing LookVectors, which stopped race initialization.
Their local axes and Size were corrected from (100, 1, 50) to (100, 50, 1),
preserving each world-space gate volume and position. They now use Y-up frames
with horizontal reset headings. These are Studio asset changes: save the open
Development place to retain them; Git stores source, not the place assets.

The repeatable checks below remain useful after later track edits.

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
6. Die/respawn after checkpoint 1: the lifecycle creates one new car at checkpoint 1 and seats the player
   in it automatically. R returns that car there again. Repeat fall recovery.
7. Confirm typing R in chat does not reset, rapid requests are limited, and the
   existing driving and stationary vehicle checks still behave correctly.

Do not publish as part of these checks.

## Issue #17 validation (2026-10-08)

Source: `run_checkpoints.py`, `run_vehicle_lifecycle.py`, and `run_camera.py` passed
with the standalone Luau CLI. New integrated cases cover finish eligibility,
skips/repeats, checkpoint N immediately after reset, separate players on different
laps, final-state latching, immutable-by-copy server snapshots, spoofed attributes,
configured targets (1, 2, 3), changing checkpoint count, target capture, restart,
invalid configuration, omitted-racer cleanup, and manual/death recovery at lap
boundaries. Existing ground placement, controller reset, input, lifecycle, and
camera regressions passed. These deterministic tests do not simulate networking.

Studio: verified Development place 130359159608842 / universe 8788799405, then
confirmed the three changed scripts propagated through existing Script Sync roots.
Created `Workspace.FinishLine` at (-44.4705, 31.3333, 176.0149), Size (76, 50, 2),
with checkpoint 1's rotation. It spans the existing checkered start line, faces
toward checkpoint 1, is invisible, anchored and touchable, and does not collide
or participate in queries. Save the open place to retain this Studio-owned asset.

Single-client Play passed actual engine contacts for ordered gates 1-7, skipped
and repeated gates, finish-before-checkpoints rejection, 7/7 -> moving finish
crossing -> 0/7 on lap 2, repeated finish contacts, checkpoint 7 after reset,
real client reset RemoteEvent, seated manual/death recovery at checkpoint 7 while
remaining 0/7 on lap 2, completion at 3/3, no extra lap, and repeated StartRace.
Client HUD showed lap 2 at 0/7 and final `Lap 3 / 3 - Complete` at 7/7.
Tests positioned the real car at gates using the existing placement helper and
used physical velocity for the first finish crossing; this was not a full driven
circuit or a multiplayer physics test. Play was stopped afterward; nothing was
published. Existing Nile Crocodile Head/LowerTorso warnings remain unrelated.

Remaining Studio checks: use Test > Server & Clients with two clients. Drive
player A through 1-N and finish while B remains on lap 1; verify A shows lap 2,
0/N and B's progress is unchanged. Reset both and verify their separate recovery
destinations; fire StartRace and verify both return to completed=0/current=1.
For a configured-target runtime check, stop Play, temporarily set TotalLaps=1,
sync and restart, complete a circuit and verify terminal 1/1; restore TotalLaps=3
afterward. Drive a full circuit normally to check trigger coverage at racing speed.

### Follow-up validation results

Passed in Development Play: real gate contacts 1-7, skipped/repeated gate rejection,
on-foot owner seating and reset, blocked reset, death/respawn at checkpoint 1,
all seven saved reset destinations, and the actual R-key client request at checkpoint 7.
HUD displayed Checkpoint 7 / 7 and successful reset feedback. Source checkpoint
and lifecycle suites passed. Multiplayer isolation is source-tested; a multi-client
Studio run remains a separate regression check.

Unrelated Nile Crocodile Health/ R15 Ragdoller scripts reported missing Head and
LowerTorso errors. Those assets were not modified.


## Finish-line crossing regression (2026-10-08)

The old finish handler awarded a lap as soon as any vehicle part touched the
trigger. Vehicle extent and trigger depth could therefore complete a lap before
the chassis reached the line. RaceService correctly trusted that premature
terminal lap state and then marked the racer finished.

The fix changes only CheckpointService's finish detector; checkpoint touches,
recovery destinations, race generation/state guards, lap target, HUD, and
RaceService's validated completion consumer retain their existing behavior.
Crossing is measured at the chassis center, not the front bumper.

Source regression checks cover early contact, approach/retreat, reverse travel,
rotated gate bounds, fast swept crossings, landing exactly on the plane,
duplicate/lingering samples, reset/chassis replacement, driver eligibility,
checkpoint sequencing, independent players, final completion, race lifecycle,
and existing reset/recovery behavior. These simulated checks do not establish
real vehicle physics, replication, or a complete driven multiplayer race.

Studio playtest:

1. Sync the existing roots and start a fresh Play session. FinishLine's center
   must align with the visible line and its LookVector must point along the
   course (the inspected Development trigger already faces the approach from 7).
2. Complete checkpoints 1-N. Slowly approach until the nose touches the finish
   trigger, but stop with the chassis center before it. CompletedLaps and
   CurrentLap must stay unchanged; on the last lap Racing must remain active.
3. Drive the chassis center forward through the line. Award exactly one lap;
   repeat for the final lap and verify completion happens only at this crossing.
4. Repeat with a skipped checkpoint, backward crossing, and a crossing beside
   the gate. None should award a lap. Complete a valid circuit at high speed
   and verify the thin finish trigger still detects it.
5. Stop on the line, reverse and cross repeatedly: no extra lap until all
   checkpoints are earned again. Press R or die near the finish; recovery alone
   must not award a lap. Drive the required remaining route to finish normally.
6. Run two clients, complete different numbers of laps, and verify independent
   progress. Finishing one racer must not finish the other. Run another race
   to verify the previous race's samples and completion state are cleared.
