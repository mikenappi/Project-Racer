# Race timer (issue #21)

Implemented in `src/server/RaceService.luau` and
`src/shared/RaceTiming.luau`. The existing RaceManager starts RaceService;
its existing validated finish path now records timing in the actual game.
No new race driver, finish trigger, full HUD, or movement/recovery policy was added.

## Timing and integration contract

- `startedAt` is the actual authoritative transition to Racing (GO), using
  `Workspace:GetServerTimeNow()`. Countdown deadlines are never timer origins.
- `RaceService.getElapsedTime()` returns seconds, zero before GO, increasing
  during Racing, frozen at `endedAt` in Results, and zero again in Waiting.
  Preparation aborted before GO also reports zero.
- `RaceService.markFinished(player, expectedRaceId)` is the server-only API for
  #24. It uses private participant state and validated final-lap completion.
  On the first valid call it returns `true, finishTime`; invalid, duplicate,
  spectator, and stale-generation requests return false with no timing mutation.
  Callers cannot supply a timestamp. The existing lifecycle already polls this
  same path; do not add another timer or a client finish remote.
- `RaceService.getFinishTime(userId, expectedRaceId)` returns that racer's
  immutable elapsed seconds, or nil for an unknown generation/unrecorded finish.
  Records survive participant departure through Results. DNF has no finish time.
- `getSnapshot()` includes `startedAt`, `endedAt`, and a detached `finishTimes`
  dictionary keyed by **stringified UserId**, e.g. `finishTimes[tostring(id)]`.
  String keys preserve Roblox RemoteEvent serialization. Mutating a snapshot
  cannot change server records.
- `RaceUpdated` now also fires after each accepted finish. Consumers should
  detect entry into Racing by state/generation, not treat every Racing payload
  as another GO. Each payload contains the complete current timing snapshot.
- `RaceState` retains StartedAt and adds EndedAt. Player attributes
  RaceFinishTime and RaceFinishId expose the local player's durable finish.
  Waiting/Loading clear timing and finish attributes before the next race.

## Client use for #25

Require `ReplicatedStorage.shared.RaceTiming`. For a coherent RaceUpdated
snapshot, call `RaceTiming.getElapsed(snapshot, workspace:GetServerTimeNow(),
player.UserId)` every display frame. Omit userId for global elapsed time. A
finished player returns the fixed finish value while other racers keep timing.
For late subscribers, `RaceTiming.getReplicatedElapsed(RaceState, player)` reads
durable attributes with generation matching and uses the same server clock.
Attributes are not atomic; RaceUpdated is the coherent event contract. No
per-frame networking or local wall-clock origin is required. This issue provides
data/helpers only; adding a timer label and the full HUD remains with #25.

## Source evidence — 2026-10-09

Passed `tests/run_race_lifecycle.py`, `tests/run_checkpoints.py`,
`tests/run_vehicle_lifecycle.py`, and `tests/run_camera.py` using the official
standalone Luau CLI. Both changed production Luau files passed luau-compile.
The lifecycle suite covers no timing before GO, an overdue countdown starting
from the actual transition, increasing elapsed time, two independent immutable
finishes, duplicates/stale generations, detached snapshots, string-key client
payloads, departure retention, DNF, frozen Results, aborted preparation, and a
second race with cleared results. Existing recovery, lap, vehicle, input/coast,
and camera regression cases pass. Source simulation does not establish physics
or multiplayer replication.

## Studio evidence — 2026-10-09

Verified Development place 130359159608842, universe 8788799405 before operating.
Script Sync propagated RaceService and the new RaceTiming module through the
existing roots. Single-client Play verified:

- Client elapsed stayed zero in Waiting/Countdown, then increased after GO
  (sampled approximately 0.535, 1.051, 1.567, 2.068, 2.584, 3.085 seconds).
- Moving the owned car through the real checkpoint/finish trigger geometry for
  three laps exercised the running game's validated completion path.
- Race 2 retained 25.088871 seconds across 19 client Results samples, then
  returned to zero in Waiting. Its countdown had cleared the previous finish
  and used a new start origin.
- A fresh Play after the remote serialization fix produced server finish
  12.165517807006836 and the exact same client RaceUpdated/helper finish value.
- No errors appeared in the inspected Studio console. Play was stopped.

These are single-client, scripted-position checks, not a normally driven circuit
or two-client acceptance. No persistent non-code assets were changed, no
experience was published, and no issues/comments/pushes were made.

## Remaining two-client runtime checks

1. Open this verified experience and use Test > Server & Clients with two
   clients. Click Start on both. Check timer helpers report zero throughout
   Countdown and both Racing payloads share raceId/startedAt; elapsed should
   grow from that origin despite different event arrival times.
2. Drive A to a valid finish while B continues. Verify A's finish is fixed in
   RaceUpdated and player attributes while B's elapsed keeps growing; finish B
   later and verify distinct immutable values. Duplicate the server-only
   markFinished call in a running game server script using its captured raceId;
   expect false and an unchanged finish. Do not rely on tool-context requires
   for private state belonging to the actual running server scripts.
3. Let Results expire, click Start again, and verify zero timer/empty finishes,
   a new raceId/start origin, and no prior result on either client. Include a
   late join, a finisher leaving, and a timeout with no fabricated DNF finish.
4. Run CHECKPOINTS.md recovery cases alongside the race: R, fall/death, blocked
   recovery, separate progress/vehicles, no free lap/finish, and camera follow.
   Stop Play afterward. Multiplayer runtime verification remains pending.
