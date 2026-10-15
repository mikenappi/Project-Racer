# Race lifecycle (issue #18)

`RaceManager` remains the game entry point. It initializes the existing vehicle
and recovery services and starts one `RaceService`. The server alone owns
`Waiting -> Loading -> Countdown -> Racing -> Results -> Waiting`.
The existing `RaceManager.StartRace` BindableEvent requests Loading only while
Waiting; duplicate requests in every other state do nothing. Every connected player must click the centered Start button before Loading.
The server validates readiness through RaceReady; clients cannot choose a state.
The StartRace entry point also respects this gate.

## Policies and defaults

All durations live in `src/shared/RaceConfig.luau`, in seconds:

| Setting | Default | Behavior |
| --- | --- | --- |
| MinimumPlayers | 1 | Supports solo development; use 2 for multiplayer-only admission. |
| Lobby readiness | Every player | No automatic timeout; each connected player must click Start. |
| LoadingTimeout | 30 | Maximum wait for track validation and seated drivers. |
| LoadingRetryInterval | 1 | Retry invalid track setup while Loading. |
| CountdownDuration | 3 | Server countdown interval; #20 broadcasts remaining seconds and displays GO. |
| RaceTimeout | 300 | Unfinished participants are DNF when time expires. |
| ResultsDuration | 5 | Retain final checkpoint/lap data before clearing it. |

Loading captures the connected-player roster. Readiness requires a current owned
vehicle, a living character, and that character seated in its DriverSeat. Late
joiners wait for the next roster. Loading may proceed early when all participants
are ready. At its deadline unready players are excluded; insufficient ready
players or invalid track setup aborts to Results. Countdown rechecks readiness
before Racing; remaining ready participants can race after another player leaves.
An empty Loading/Countdown also aborts directly to Results. These two abort edges
are deliberate exceptions to the normal successful transition order.

During Racing, the service consumes `CheckpointService.getRaceProgress` and its
validated `lapComplete` latch. One finisher does not stop others. Results starts
when all remaining participants finish/leave, or the deadline expires. This does
not implement placement, rewards, or a results screen. Issue #21 now records finish times; #24/#22
can consume the lifecycle and existing lap completion rather than adding another
race controller or finish trigger.

## Integration contracts

- `RaceService.getSnapshot()` returns a detached state/raceId/deadline/reason table.
- `RaceService.requestStart()` returns false for invalid, duplicate, empty-server,
  or reentrant requests. Only the service advances subsequent states.
- `RaceService.canDrive(player)` is the private server policy used by the actual
  movement controller, checkpoint touches, and manual reset requests. Player or
  vehicle display attributes never authorize participation.
- `RaceService.markFinished(player, raceId)` rejects stale race generations,
  duplicate completions, and players without validated final-lap completion.
  The lifecycle already polls this same path; a later finish consumer can call it.
- `RaceService.onEntered(state, callback)` registers a persistent state-entry
  callback and returns an unsubscribe function. The callback receives a detached
  snapshot and may return a per-entry cleanup function. Cleanup runs exactly once
  before the next transition. Hooks and cleanups must not yield; use the captured
  raceId to reject stale asynchronous work. Errors are warned and isolated.
  Register before `start` for subsequent transitions, or inspect the current
  snapshot when attaching after startup. Initial Waiting is exposed by snapshot;
  entry hooks run on transitions, including Results -> Waiting.
- `ReplicatedStorage.RaceState` is a server-written StringValue. Clients read its
  current Value and listen to Changed, so late subscribers do not miss the state.
  RaceId, Deadline (server time), and Reason attributes are metadata written before
  Value changes; use the state value as the transition notification. They are not
  an atomic multi-field snapshot. Server consumers use `getSnapshot()` instead.
- `RaceParticipant` is a display-only player attribute. RaceHUD adds lifecycle
  state and next-race waiting status to the existing lap/checkpoint/reset UI.

VehicleController rejects input outside active racing. Preparation and waiting
racers stay anchored; completed racers instead coast with input disabled.
Results/Waiting preserve that coasting until the next Loading state. Releasing
the preparation lock restores server network ownership.
Unowned vehicle test fixtures keep their previous behavior. Character/car
replacement continues to use the existing checkpoint recovery service.

Loading resets checkpoint/lap data through the existing `startRace` entry point;
touch eligibility remains gated until Racing. `CheckpointService.stopRace`
disconnects all gate/finish callbacks, invalidates queued callbacks by generation,
and clears progress and recovery destinations. Waiting calls it and clears reset
cooldowns/status and roster attributes. Results retains final progress but gates
touches and controls. No per-race timers or extra Heartbeat listeners accumulate.

Per-race grid placement (#19) now runs during Loading. It snapshots each
participant's privately assigned vehicle slot, moves their existing car there,
clears linear/angular velocity and controller input, and seats the owner. A new
race clears placement records, so coasting through Results/Waiting never becomes
the next starting position. Initial character spawns also seat their owner.
Countdown requires successful placement of the current vehicle plus a living,
seated owner. Replacement cars during Loading are prepared again; replacement
during Countdown cannot inherit the old car's readiness. Racing recovery still
uses earned checkpoints. See [Starting grid](STARTING_GRID.md) for capacity,
failure handling, and validation. #20 uses Countdown entry/deadline for presentation and publishes the actual
Racing start time; #21 uses that same start origin; see [Race timer](RACE_TIMER.md).

## Source validation

Run from the repository root with a standalone Luau CLI:

```text
python tests/run_race_lifecycle.py <path-to-luau>
python tests/run_checkpoints.py <path-to-luau>
python tests/run_vehicle_lifecycle.py <path-to-luau>
python tests/run_camera.py <path-to-luau>
```

All four passed on 2026-10-08. Changed Luau files also passed `luau-compile`.
The new suite executes the real RaceManager, RaceService, checkpoint and recovery
modules plus the actual controller lock and input callback in the established
simulator. It covers two races, transition order, reentry/duplicates, durable
state, stale/invalid finishes, late joins, roster departures in every active
phase, empty servers, loading/race timeouts, cleanup, and input/physics gating.
The checkpoint suite now drives checkpoint starts directly; its previous manager
restart expectations belonged to the old immediate-start policy. Manager wiring
is covered by the new lifecycle suite. Existing lap, recovery, vehicle and camera
cases remain intact. These tests do not establish engine physics or networking.

## Studio evidence and remaining checks

Verified **Project-Racer Development**, place **130359159608842**, universe
**8788799405**. All changed source propagated through the existing Script Sync
roots, including the new RaceService ModuleScript. No remapping, persistent
non-code asset changes, or publication was performed. Play was stopped afterward.

Single-client Play on 2026-10-08 verified:

- Owned car locked in Loading/Countdown and released in Racing.
- Actual checkpoint contact in Countdown left checkpoint/laps at zero.
- Server RaceState and client RaceHUD agreed on Racing and race ID.
- Duplicate server StartRace during Racing left the race/generation unchanged.
- Real gate/finish contacts advanced through three laps and entered Results.
- Results locked the car; Waiting cleared checkpoint and lap attributes.
- The next race used race ID 2, fresh progress, Countdown, and Racing, then
  completed three laps and entered Results again.
- The real client's ResetVehicle RemoteEvent recovered at checkpoint 1 during
  race 2, retained the seat and checkpoint, and awarded no lap.

The test repositioned the actual car into the existing trigger volumes. It was
not a normally driven circuit or a two-client physics run. An initial diagnostic
using tool-context module requires did not represent the running game's private
module state; Play was restarted, and the evidence above was collected from
actual game instances, replicated values, BindableEvent/RemoteEvent entry points,
and physical contacts. No claim is based on that diagnostic module state.

Remaining runtime procedure (use Test > Server & Clients, two clients):

1. Join both players before Loading and seat each in their own car. Hold throttle
   through Countdown. Verify both see the same state and neither car moves until
   Racing; check checkpoint/finish contacts do not count early.
2. Join another client during Racing: it must wait, remain locked, and receive no
   checkpoint state until the next race. Try duplicate StartRace requests during
   Loading, Countdown, Racing and Results; race ID must not advance.
3. Finish A while B continues; A coasts while B drives. Leave with B and verify
   Results, then Waiting with cleared attributes. Repeat with all players leaving
   during Loading/Countdown. Start another race and verify fresh state on both.
4. Leave one player unseated through LoadingTimeout; ready racers may proceed.
   Test an invalid track setup and restore it: preparation must time out and retry
   on a later race. Let an unfinished race reach RaceTimeout and inspect the DNF
   reason, Results, and next-race cleanup.
5. Drive a complete circuit normally. Repeat CHECKPOINTS.md multiplayer recovery
   checks: separate checkpoints, manual R, blocked destinations, fall/death,
   ownership rejection and one car per player. Check camera follow after recovery.

Stop Play after testing. Do not publish or close issues as part of validation.


## Post-race coasting (2026-10-08)

Finished racers keep their momentum and use the existing CoastDeceleration
instead of being anchored. Steering/throttle input remains disabled; ground
stability and lateral grip remain active. Timeout/DNF participants also coast.
Coasting continues through Results and Waiting; Loading/Countdown for the next
race restores the preparation lock. Late joiners still wait with locked cars.

Playtest: cross the final finish line at speed while holding W. The car should
roll forward and slow gently without accepting more acceleration or steering.
Repeat with two racers (A coasts while B can drive), at the race timeout, and
through Results/Waiting. Verify the next countdown locks cars and Go restores
normal controls.
