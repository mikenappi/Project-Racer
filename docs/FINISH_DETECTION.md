# Finish detection (issue #24)

Implemented in `src/server/RaceService.luau`, started by the existing
`RaceManager.server.luau`. The game continues to consume #17's private validated
`CheckpointService.getRaceProgress().lapComplete` latch on the existing Racing
heartbeat. CheckpointService alone validates checkpoint order and the directed
final-lap chassis crossing. No extra lap, finish trigger, timer, remote request,
or heartbeat is introduced. Existing checkpoint and recovery code is unchanged.

## Result contract

`RaceService.markFinished(player, raceId)` rejects stale generations, transitions,
spectators, duplicates, and racers without a validated final lap. It captures
#21's server elapsed time once. Before any display attribute or event is
published, the non-yielding commit stores the frozen result, time, finish order,
and participant's finished status. Input and progress are then gated by the
existing participant policy; finished cars retain existing coasting behavior.

`RaceService.getFinishResult(userId, raceId)` returns a frozen `FinishResult` or
nil. Each record contains `raceId`, `userId`, `finished`, `position` (one-based),
and `elapsedTime` (seconds). Server callers cannot mutate its fields.
`getSnapshot()` and `RaceUpdated` include `finishResults`, a detached dictionary
keyed by stringified UserId. Its server records are frozen; remote clients receive
serialized copies and cannot mutate server authority. This joins the existing
`finishOrder`, `finishTimes`, and `positions` contracts for #22 and #26.

Ordering retains #22's policy: server acceptance order, with ascending UserId
for completions first observed in the same polling tick. It is not sub-frame
crossing precision. Placement uses the recorded order, never a sort of times.
Results survive a finisher leaving through Results. Waiting/Loading clear the
current result map; previously retained frozen records remain unchanged.

The same lifecycle update that accepts finishes checks #18's established end
condition: all remaining participants have finished/left, or the race timeout
expires. A first finisher cannot end another active racer's race. DNF creates no
finish record. Explicit server acceptance calls are checked by that heartbeat
for the Results transition. No new unfinished-racer policy is introduced.

## Source evidence — 2026-10-09

Passed with the official standalone Luau CLI:

```
python tests/run_race_lifecycle.py <path-to-luau>
python tests/run_checkpoints.py <path-to-luau>
python tests/run_vehicle_lifecycle.py <path-to-luau>
python tests/run_camera.py <path-to-luau>
```

The lifecycle suite runs the real manager and modules in the existing simulator.
Added coverage checks early/skipped crossings, valid non-final laps, atomic
authority before display notification, reentrant duplicate rejection, frozen
records and detached maps, both update subscribers, death/replacement followed
by touches/crossings, finished reset rejection, departure retention, DNF without
results, Results cleanup, retained old records, and equal-time final crossings
with unique stable positions despite reversed roster order. Existing tests cover
distinct finish times, stale generations, two full races, checkpoint/reset,
vehicle/controller and camera behavior. RaceService passes `luau-compile` and
the checkout passes `git diff --check`. These are source/simulation checks.

## Studio evidence — 2026-10-09

Verified Development place **130359159608842**, universe **8788799405**.
Script Sync propagated the new API into `ServerScriptService.server.RaceService`.
Single-client Play exercised the running game's real manager and checkpoint
volumes, with a client listener on the real RaceUpdated RemoteEvent:

- Early finish crossing left completed laps at zero with no finish.
- Seven ordered checkpoints per lap: laps 1 and 2 remained Racing without a
  finish; lap 3 entered Results with position 1.
- Server finish time **20.415701866149904** exactly matched the client's
  finishResults record in both Racing and Results payloads for race 1.
- Waiting cleared finish records and attributes. Race 2 started with zero laps,
  no finish, and a new generation.
- Race 2 finished at **4.868790864944458** seconds; repeated finish crossings
  and all seven later checkpoint contacts retained that time, position 1, and
  three completed laps while Results continued.
- The inspected console contained no errors. Play was stopped afterward.

These were scripted car-position checks, not normal driving or multiplayer
acceptance. No persistent Studio assets, sync mappings, publication, GitHub issue
state/comments, or pushes were changed.

## Remaining two-client runtime acceptance

The connected tools expose single-client Play; use Studio Test > Server & Clients
with two clients in the verified development experience:

1. Click Start on both clients. Attempt an early finish, skipped checkpoints,
   and a valid non-final lap. Confirm no RaceFinishPosition/Time and no
   finishResults entry; Countdown crossings must also award nothing.
2. Finish A legally while B remains active. Verify A's record and place 1 on
   both clients, B can still drive/reset/advance, and state stays Racing. Finish
   B later: fixed places 1/2, distinct times, then Results.
3. Repeat with near-simultaneous final crossings. Confirm two unique positions
   and stable records on both clients; one polling-tick tie uses numeric UserId.
4. After A finishes while B continues, attempt R, duplicate crossings, checkpoint
   contacts, and death/fall replacement. A's result must stay fixed. Check one
   owned vehicle, seated recovery, independent progress, and camera follow;
   include blocked recovery and cooldown checks from CHECKPOINTS.md.
5. Repeat with A leaving after finishing: B still receives place 2. In another
   run allow the deadline to expire; unfinished B gets no fabricated result.
6. Let Results return to Waiting and click Start again. Both clients must have
   fresh progress, empty result data, and a new raceId. Complete another race.

Stop Play afterward. Multiplayer runtime verification remains pending.
