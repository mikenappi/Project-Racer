# Race countdown (issue #20)

The existing RaceService owns the countdown after #19 finishes grid preparation.
RaceConfig.CountdownDuration configures seconds (default 3, finite and positive).
RaceConfig.GoDisplayDuration configures the short GO display (default 1 second).
RaceHUD adds only the large countdown/GO label; full HUD work remains with #25.

## Server and client contract

RaceService.getSnapshot() now includes countdown and startedAt. During Countdown,
countdown is ceil(deadline - server time), updated by the existing Heartbeat.
The ReplicatedStorage.RaceUpdated RemoteEvent broadcasts a detached complete
snapshot to all clients on state changes and countdown ticks. Racing is the GO
event; its raceId and startedAt identify one common authoritative start. startedAt
is the actual transition time, not a promise that the server will hit the planned
deadline exactly. It clears on Waiting/Loading. Clients can acknowledge lobby readiness; only the server can transition states.

RaceState retains its existing state/deadline/reason attributes and adds Countdown
and StartedAt for durable presentation. Attributes are not an atomic packet;
consumers needing coherent event data should use RaceUpdated. The HUD reads the
current state each frame, supports late subscribers, and never predicts GO from
its own clock. It hides GO after GoDisplayDuration and hides the display for
nonparticipants. There are no delayed per-race UI callbacks.

The existing VehicleController rejects throttle/steering before Racing, clears
cached input, anchors preparation cars, and restores server ownership on release.
InputController continuously sends held seat input, so no new key press is needed
after GO. Checkpoint/reset eligibility shares the same canDrive policy. The next
physics step releases prepared cars together after the authoritative transition.
No movement tuning, checkpoint/recovery policy, or post-race coasting is changed.

Cancellation uses the existing Results transition. One heartbeat driver handles
all generations; no countdown timers or callbacks survive into a later race.
Server stalls may skip obsolete numeric ticks; they cannot cause an early GO.

## Source validation — 2026-10-09

All four existing Python runners passed with official Luau CLI 0.741:
run_race_lifecycle.py, run_checkpoints.py, run_vehicle_lifecycle.py, run_camera.py.
The changed production Luau scripts also compiled; git diff --check passed.

New lifecycle tests execute actual RaceService, movement input/lock code, and the
HUD countdown function. They cover 3/2/1/GO payloads received by two simulated
subscribers, matching generation/start time, one GO per race, aborted countdowns,
fresh later races, held throttle AND steering rejected before GO and accepted
afterward, late HUD subscription, GO expiry, cancellation and spectator hiding.
Existing checkpoint/lap/recovery, grid, coasting, vehicle and camera tests pass.
Simulated subscribers do not establish two-client network acceptance.

## Studio evidence — 2026-10-09

Verified Development place 130359159608842, universe 8788799405. Script Sync
propagated RaceService, RaceConfig and RaceHUD through their existing mappings.
Single-client Play recorded RaceUpdated values 3, 2, 1, then Racing/GO with raceId 1.
The planned countdown deadline was 1791519922.589519 and actual server startedAt
was 1791519922.597254. The real client displayed numeric countdown and GO, then
cleared GO. During sampled countdown frames the chassis remained anchored at
(182, 7.9833245, 176); it was unanchored at GO and moved afterward. The test sent
repeated throttle/steering RemoteEvent input during the observation; ordinary
InputController remained active, so this is not a physical-key driving test.
Play was stopped afterward. No persistent non-code assets or publication changed.

## Remaining runtime acceptance

1. In the verified Development experience, use Test > Server & Clients with two
   clients. Join both before Loading. In each client observe RaceHUD.Countdown
   and record RaceUpdated payloads; require 3, 2, 1, then Racing with identical
   raceId and startedAt on both clients (arrival time may differ by network delay).
2. Hold W and A/D on both clients before GO. Cars must remain on their separate
   grid slots with no translation/rotation; at GO they must respond without a
   new key press. Confirm server network ownership and no early checkpoints.
3. Finish the race and wait through Results/Waiting. Verify both return to their
   grid slots and see a fresh countdown with one GO for the new raceId. Repeat
   with the last participant leaving during Countdown; no stale GO may appear.
4. Drive checkpoint/recovery regressions: R after a checkpoint, character death
   or fall, blocked recovery, retained progress, separate cars and camera follow.
   Stop Play afterward. Do not publish.

Two-client replication, physical held-key driving, and the second-race runtime
sequence remain pending; the connected tool exposes single-client Play only.


## Whole-lobby Start button — 2026-10-09

Waiting now lasts until every currently connected player clicks the centered
Start button. The button shows the ready count and changes to "Waiting for
everyone..." after acknowledgment. The final click begins existing Loading/grid
preparation, then the shared countdown. WaitingDuration was removed because the
lobby no longer starts on a timer. MinimumPlayers still applies.

Readiness is held in a private server table; LobbyReady is display-only.
RaceReady carries the Waiting raceId to reject stale clicks. Duplicate requests,
wrong generations, and requests outside Waiting do nothing. Server StartRace
cannot bypass the gate. New arrivals during Waiting must also click; departures
are removed from the requirement. Players joining after Loading begins wait for
the next race under the existing roster policy. Readiness clears each time the
server returns to Waiting, including after aborted preparation.

All four source regression suites passed after this change. New cases verify
indefinite waiting, all-client consent, joins/departures, spoofed attributes,
duplicate/stale requests, and fresh readiness on the second race.

Single-client Studio Play in the verified Development experience stayed Waiting
beyond the old automatic-start delay and displayed "Start / 0 / 1 players ready"
at screen position (0.5, 0.5). An actual mouse click on StartButton entered
Countdown, hid the button, and then entered Racing. Play was stopped afterward.
Two-client runtime validation remains pending: click on client A only and verify
both remain Waiting at 1/2 ready; click B and verify both enter the countdown.
Repeat with a joining/leaving player and again after the race ends.
