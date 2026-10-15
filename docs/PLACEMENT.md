# Race placement (#22 and #34)

`RaceService` owns the race roster and immutable finish records.
`CheckpointService` alone validates ordered checkpoints, completed laps, and
directed finish-plane crossings. `TrackProgress` computes a distance within that
validated checkpoint interval. `PlacementService` compares those inputs. Clients
render placement and cannot submit rank or progress.

## Ordering and synchronization

1. Accepted finishers keep their recorded order, including finishers who leave.
2. Active racers compare completed valid laps, then validated checkpoint index.
3. Racers at the same stage compare continuous 3D arc distance along that stage's path.
4. Exact ties use ascending numeric UserId, independent of previous ranks.

RaceService samples paths on its existing heartbeat at `PlacementInterval` (0.1s).
Checkpoint/finish/departure changes still refresh immediately. Only changed ranks
and existing lifecycle/finish events publish `RaceUpdated`; stationary unchanged
rankings generate no extra event traffic. Player `RacePosition`/`RacePositionId`
attributes provide durable late-subscription data. `RaceFinishPosition`,
`RaceFinishTime`, and `RaceFinishId` remain the finish contract. Snapshot dictionaries
use string UserId keys. No client positions or placement values are accepted.

`TrackProgress` projects only inside a bounded arc window of the currently
validated stage. It measures full 3D length, including elevation, and retains the
last trusted point to distinguish nearby/self-crossing path portions. Speed/time,
arc-to-chord distance and swept-corridor checks reject implausible motion and
shortcuts. Rejected samples display zero within-stage distance; they retain their
trusted anchor and update its timestamp so waiting cannot accumulate teleport
allowance. Returning near that anchor or resetting permits recovery. Backward
travel reduces distance. None of this writes checkpoint/lap state.

Vehicle identity, ResetVersion, checkpoint and completed-lap changes invalidate
the old sample. A new sample can attach only near the start of the valid interval;
it cannot attach to a distant branch. New races and departures remove old samples.
Recovery across a lap boundary still uses CheckpointService's saved destination;
if it is outside the new interval, continuous distance stays zero until legitimate
re-entry. Finishers never use projection again.

## Track authoring in Studio

**Development currently lacks these assets and uses checkpoint fallback.** Do not
claim live continuous placement on this map until all eight intervals are authored
and the checks in [M1_TESTING.md](M1_TESTING.md) pass. Do not connect the existing
checkpoint centers with guessed straight lines through curves.

For a track with N checkpoints, create this non-code hierarchy in Workspace:

```text
RaceProgressPaths (Folder)
  0 (Folder): finish/start -> checkpoint 1
    1, 2, 3, ... (ordered BasePart samples)
  1 (Folder): checkpoint 1 -> checkpoint 2
    1, 2, 3, ...
  ...
  N (Folder): checkpoint N -> finish
    1, 2, 3, ...
```

Use at least two samples per interval, numbered contiguously. Place their centers
at expected chassis height along the intended route, adding enough samples around
every bend, hill, loop and crossing. Markers must be anchored, noncollidable,
non-touchable and nonqueryable; make them transparent for play. The first and last
sample must lie within the corresponding gate's X/Y bounds and Z thickness plus
`ProgressEndpointTolerance`. Adjacent intervals should share the same gate point.
The start is the existing directed FinishLine; grid cars behind it remain at zero
until they enter the start interval. The path never replaces finish validation.

Set an optional numeric `CorridorRadius` attribute on each interval folder, or use
`ProgressCorridorRadius` (12 studs). This is a **3D tube around the chassis path**,
not road width inferred from checkpoint volumes. It must cover usable driving
positions while excluding grass shortcuts and nearby decks. For branching or
tightly overlapping routes, add checkpoint boundaries and sufficiently dense path
samples. A wide tube cannot establish which surface a car occupies. Tune/test the
route rather than loosening tolerances until bad geometry happens to pass.

The loader snapshots all intervals after CheckpointService validates the track.
Missing/invalid intervals, markers or endpoints disable continuous ranking for
the entire race, warn once at setup and set `RaceState.PlacementMode` to
`Checkpoint fallback`. Valid metadata sets it to `Continuous`. Fix assets in Edit
mode and start another race to reload. The fallback retains laps/checkpoints,
fixed finish order and the deterministic UserId tie rule.

## Configuration and limits

All tunables live in `src/shared/RaceConfig.luau`:

| Setting | Purpose |
| --- | --- |
| PlacementInterval | Projection sampling interval (0.1 seconds). |
| ProgressFolderName | Studio metadata root name. |
| ProgressCorridorRadius | Default 3D tube radius in studs. |
| ProgressEndpointTolerance | Extra depth allowance at path endpoints. |
| ProgressMaxSpeed | Maximum plausible chassis displacement rate; 1200 includes current 1000 studs/s test tuning. |
| ProgressMaxSampleGap | Reject stale samples after pauses over 0.5 seconds. |
| ProgressEntryDistance | Start/gate/recovery attachment allowance (24 studs). |
| ProgressSlack | Small movement/arc tolerance (2 studs). |
| ProgressArcRatio | Maximum local arc distance relative to physical movement (1.5). |

At high speeds around tight bends, a sparse sample or a server stall can conservatively
reject legitimate motion. Test actual handling and sampling frequency on each track.
The corridor and continuity rules complement the existing server-owned vehicle
physics; they are not proof against arbitrary server teleports or all possible
malformed track layouts. Keep nonadjacent route sections separated relative to
corridor width and sampling reach, or split them with validated gates.

## Verification

See [M1_TESTING.md](M1_TESTING.md) for current automated and Studio evidence,
known setup gaps and the manual multiplayer checklist. The following historical
record predates continuous placement and used checkpoint-only ties.

## Verification, 2026-10-09

Source checks passed with the standalone Luau CLI:

```text
python tests/run_race_lifecycle.py <luau.exe>
python tests/run_checkpoints.py <luau.exe>
python tests/run_vehicle_lifecycle.py <luau.exe>
python tests/run_camera.py <luau.exe>
```

The expanded lifecycle suite executes real modules with two simulated racers and
two payload subscribers. It covers lap/checkpoint precedence, stable ties,
recorded finish ordering, unique places, recovery without placement gain,
spoofed display attributes, detached snapshots, duplicate/stale finishes,
finisher departure followed by another finish, DNF, cleanup, and a second race.
Existing checkpoint/recovery, vehicle, and camera regressions pass. Changed
production modules compile with `luau-compile`; `git diff --check` passes.

Studio was verified as Development, place 130359159608842, universe 8788799405.
Existing Script Sync propagated PlacementService and RaceService. Single-client
Play verified two complete three-lap races through all seven actual checkpoint
volumes and the directed finish crossing. The server and real client received
position 1, finishOrder and RaceFinishPosition 1; Waiting cleared both maps and
attributes, and race 2 began with a fresh generation and empty finish order.
A third-race client request through Remotes.ResetVehicle returned to checkpoint 1
with zero completed laps and position 1 unchanged. An initial diagnostic used
the wrong remote path and failed without changing game state; the corrected
request passed.
The vehicle was repositioned for trigger checks, not normally driven around the
circuit. This is not multiplayer acceptance. Play was stopped; no publication,
issue changes, push, or persistent non-code edits were performed.

## Remaining two-client Studio acceptance

Use Test > Server & Clients with two clients in the verified development place.
The connected MCP tools expose single-client Play only, so this remains pending.

1. Join both players before either clicks Start. After both click, inspect
   Players' RacePosition/RacePositionId attributes on server and each client.
   At equal progress the lower numeric UserId must be first.
2. Advance B to checkpoint 1: B first. Advance A to checkpoint 1: restore the
   UserId tie rule. Advance either to checkpoint 2: that racer leads.
3. Complete a lap with B while A has all checkpoints on the previous lap:
   B remains ahead despite its checkpoint index resetting to zero.
4. Use R and death/fall recovery at an earned checkpoint. Confirm no lap,
   checkpoint, finish or position gain and one owned car per player; verify
   camera follow and separate controls remain functional.
5. Finish A while B continues: A stays first and coasts. Advance/reset B,
   then finish B: positions stay 1/2 with distinct immutable finish places.
   Repeat with A leaving after finishing; B must still finish second.
6. Allow Results -> Waiting: positions and finish attributes clear. Start a
   second race with both clients; verify fresh progress, tie order, generation,
   and new finishes. In another run allow timeout: DNF has no finish place.

Stop Play afterward. Do not publish as part of validation.
