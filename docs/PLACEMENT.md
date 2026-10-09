# Player placement (issue #22)

`PlacementService.getPositions` ranks racers using private server data. The
existing RaceManager starts RaceService, which consumes validated
`CheckpointService.getRaceProgress` and `getLastIndex`, refreshes placement on
its existing Racing heartbeat, and publishes changes. No additional heartbeat,
client authority, UI, or changes to checkpoints/recovery are introduced.

## Ordering and results contract

1. Accepted finishers retain their recorded places, ahead of active racers.
2. Active racers sort by completed laps descending, then validated checkpoint
   index descending. Lap wrap to checkpoint zero cannot lose lap precedence.
3. Equal active progress sorts by ascending numeric UserId. This is stable
   regardless of table traversal, resets, or the previous standings. Distance
   toward the next checkpoint is intentionally deferred.

The current repository exposes the finish contract for #24 through
`RaceService.markFinished(player, raceId)` and `finishTimes`; no separate #24
result module exists here. This change extends that same validated, one-time
acceptance path with an append-only `finishOrder` of numeric UserIds. Its index
is the finish place; the existing `finishTimes[tostring(userId)]` supplies time.
Never reconstruct finish order by sorting times. Equal completions first
observed in one polling tick are accepted in ascending UserId order. Explicit
server calls retain their acceptance order. This is server observation order,
not sub-frame precision timing.

Duplicate, stale-generation, spectator and unvalidated finishes remain rejected.
Finished records survive departures through Results, reserving those places.
Unfinished departures are removed and remaining active positions compact behind
all retained finishers. Timeout/DNF receives no finish place/time. Late joiners
remain outside the roster until the next race. Waiting clears all placement and
finish data; Loading starts a fresh roster and deterministic initial order.

## HUD/results data (UI remains #25/#26)

- `RaceService.getSnapshot()` and `ReplicatedStorage.RaceUpdated` include detached
  `positions` (string UserId keys to one-based positions), `finishOrder` (ordered
  numeric UserIds), and existing `finishTimes`. Use the snapshot's `raceId` and
  `state`. Racing payloads can represent placement changes, not another GO.
- `Player.RacePosition` and `RacePositionId` attributes provide durable current
  placement for clients attaching after an update. `RaceFinishPosition` joins
  existing `RaceFinishId` and `RaceFinishTime`. Match generation IDs against
  `ReplicatedStorage.RaceState.RaceId`. Attributes are display data, not inputs.
- Remote snapshots contain the full retained finish order, including departed
  finishers. Late subscribers can read current players' attributes immediately;
  there is no new historical-results request endpoint in this issue.
- Server snapshots refresh on the existing heartbeat, accepted finishes,
  departures and state publication. Attributes are not an atomic snapshot.

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
