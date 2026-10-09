# Project Racer: first playable scope

This document completes the definition work in [issue #1](https://github.com/mikenappi/Project-Racer/issues/1). It defines the minimum complete multiplayer race and maps it to existing feature issues. It does not certify that the whole game is playable today. Implementation ordering and dependencies are in [ROADMAP.md](ROADMAP.md).

The target loop is **join → enter a vehicle → start a race → drive the track → complete laps → finish → receive a placement → race again**.

## Scope and ownership

One shared vehicle type, one complete greybox track, and at least two simultaneous racers are sufficient. Each player gets a separate vehicle. Use a configurable three-lap baseline and a basic countdown such as `3 → 2 → 1 → GO`. Placeholder models and temporary readable UI are sufficient.

Studio owns track geometry, models, checkpoint parts, grid markers, and other non-code assets. Git owns Luau source in the existing `src/client`, `src/server`, and `src/shared` Script Sync roots. Preserve those mappings. The server decides checkpoint progress, laps, starts, resets, finishes, and placement; clients handle input, camera, and presentation. Shared configuration holds tuning. See [ARCHITECTURE.md](ARCHITECTURE.md).

Cosmetics, currency, progression, abilities, additional tracks/vehicle types, finished art/UI, soundtrack, are outside this milestone. The finalization request adds a minimal styled HUD and continuous placement under #34; track metadata and runtime validation are required. Basic timer, HUD, results, and repeat-race integration already have feature issues below; they do not require polished presentation.

## Current finalization status — 2026-10-09

Race lifecycle, grid, countdown, laps, timing, finish detection, HUD and continuous
placement infrastructure are now implemented. The current map lacks progress paths
and retains checkpoint fallback; the full results screen and multiplayer acceptance
remain outstanding. [ROADMAP.md](ROADMAP.md) is the current feature status and
[M1_TESTING.md](M1_TESTING.md) records executed tests and remaining acceptance.
The detailed implementation observations below are the preserved **2026-10-08
baseline**, not current TODO status. The requirements and unchecked whole-loop
acceptance remain applicable.

## Historical baseline evidence and status

Snapshot: 2026-10-08, source revision `df9c430f7f13454f8f31e6ea490c046338c29f7f`. Issue numbers, titles, and dependencies were checked against GitHub. Issues #7, #8, #9, #10, #16, and #23 were confirmed closed; #15 was open. An issue's closed state is separate from runtime verification.

- **Completed component:** implemented source plus completed feature tracking. Preserve it and verify integration when adding later systems.
- **Unverified:** current runtime behavior or Studio asset acceptance has not been established by this review.
- **Pending:** required behavior is absent from the inspected implementation, or only a placeholder exists.

The user reports #16 and #23 complete. [CHECKPOINTS.md](CHECKPOINTS.md) records earlier Development Play passes for real gates 1–7, skip/repeat rejection, on-foot reset/seating, blocked reset, death/respawn at checkpoint 1, all seven reset destinations, and the real R-key request. It records source-tested multiplayer isolation, with multi-client Studio regression still outstanding. These are prior results, not new runtime tests performed for this definition task.

## Required systems

### 1. Vehicle

**Required:** every player can enter/control a vehicle, accelerate, brake, reverse, steer, and drive the testing track. A stuck or off-track vehicle can recover. One placeholder vehicle type is enough.

**Owners:** [#7 — Create placeholder vehicle](https://github.com/mikenappi/Project-Racer/issues/7), [#8 — Implement basic vehicle movement](https://github.com/mikenappi/Project-Racer/issues/8), [#9 — Implement player vehicle spawning](https://github.com/mikenappi/Project-Racer/issues/9), and recovery #23. [#10 — Implement racing camera](https://github.com/mikenappi/Project-Racer/issues/10) supports usable driving and recovery.

**Current:** completed vehicle, movement, spawning, and camera components. `InputController.local.luau`, `VehicleController.server.luau`, `PlayerVehicleService.luau`, and `VehicleService.luau` provide input, server movement/ownership validation, and lifecycle. Preserve the existing arcade/gliding feel. Full-course driving and two-client physics remain runtime acceptance checks. See [VEHICLE_MOVEMENT.md](VEHICLE_MOVEMENT.md), [VEHICLE_SPAWNING.md](VEHICLE_SPAWNING.md), and [RACING_CAMERA.md](RACING_CAMERA.md).

### 2. Greybox track

**Required:** one continuous racing path with an identifiable start/finish line, enough turns/terrain to exercise handling, ordered checkpoints that prevent major shortcuts, and room for simultaneous racers and a starting grid. Basic Roblox parts are acceptable; visual quality is irrelevant.

**Owner:** [#15 — Create greybox test track](https://github.com/mikenappi/Project-Racer/issues/15).

**Current:** unverified full-track acceptance. Prior checkpoint validation establishes seven gates in the Development place, not proof of a complete circuit, usable start/finish line, drivable ramps, or two-car clearance. #15 remains open. Assets must be inspected in the correct Studio experience when this feature is validated.

### 3. Multiplayer support

**Required:** at least two players spawn into the same race, own/control separate vehicles, progress independently, finish at different times, and receive distinct finishing placements. Increasing player count later must not require rebuilding the race system.

**Owners:** #9 and #16 supply the base; #17, #18, #19, #22, and #24 integrate the race; [#27 — Test first playable race with multiple clients](https://github.com/mikenappi/Project-Racer/issues/27) verifies the whole loop.

**Current:** completed per-player vehicle records, stable spawn slots, and independent checkpoint records use player-keyed state rather than a fixed pair of racers. Simulated isolation has prior test coverage. Full multiplayer race acceptance is pending because lap, lifecycle, and finish/placement behavior is pending. More players also require enough valid Studio grid space.

### 4. Race start

**Required:** place players and vehicles at separate valid starting positions, show a shared countdown, prevent early movement, and activate racing/release controls at zero. Temporary countdown UI is enough.

**Owners:** [#18 — Implement race state machine](https://github.com/mikenappi/Project-Racer/issues/18), [#19 — Implement starting grid](https://github.com/mikenappi/Project-Racer/issues/19), [#20 — Implement race countdown](https://github.com/mikenappi/Project-Racer/issues/20), and #25 presentation.

**Current:** pending race-start integration. Existing lifecycle slots handle initial vehicle placement, but do not implement a per-race grid reset. `RaceManager.server.luau` starts checkpoint tracking immediately and exposes a server-only `StartRace` BindableEvent. Successful restart clears checkpoint progress; it does not reposition cars, count down, or prevent driving. It is not a complete race start.

### 5. Checkpoints

**Required:** detect vehicle crossings on the server; store each player's current checkpoint; accept only the next ordered checkpoint; reject skips/repeats; reset progress for a new race. For `Start → C1 → C2 → C3 → Finish`, C3 cannot count before C2.

**Owner:** [#16 — Implement checkpoint system](https://github.com/mikenappi/Project-Racer/issues/16), completed.

**Current:** `CheckpointService.luau` maintains private per-player progress, validates the living owner in their current vehicle's DriverSeat, and accepts only `lastIndex + 1`. Display attributes are not validation input. A successful new sequence resets progress; invalid marker setup preserves the prior sequence. The last checkpoint stays final; lap wrapping is pending #17. Preserve this component and its reset destination snapshots when integrating laps.

### 6. Lap tracking

**Required:** track laps independently, increment only after the full ordered checkpoint sequence and valid start/finish crossing, use a predefined configurable lap total (initially three), and expose final-lap completion. Display can be `Lap 1/3`, `Lap 2/3`, `Lap 3/3`.

**Owner:** [#17 — Implement lap tracking](https://github.com/mikenappi/Project-Racer/issues/17).

**Current:** pending. Checkpoints do not wrap and `RaceConfig.luau` currently configures checkpoints/reset only. #17 must reset the sequence for each subsequent lap without losing completed-lap progress or weakening #16/#23 validation.

### 7. Finish detection

**Required:** after all required laps and checkpoint sequences, validate the final-lap finish-line crossing. Store the finish exactly once, freeze its result/position, and stop treating that player as actively racing while others continue. A final checkpoint touch alone is insufficient.

**Owner:** [#24 — Implement finish detection](https://github.com/mikenappi/Project-Racer/issues/24), using #17, #18, and [#21 — Implement race timer](https://github.com/mikenappi/Project-Racer/issues/21).

**Current:** pending. The final checkpoint remains ordinary checkpoint progress; no finish record or race timer is implemented in the inspected race path. The valid crossing that completes the final circuit should produce one finish; repeated or premature crossings must not create another result.

### 8. Basic placement

**Required:** finished racers first, ordered by recorded finish time/order; active racers follow by lap, then validated checkpoint. Finished positions remain fixed. Use a consistent tie rule for active racers with equal progress; precise distance to the next checkpoint can wait. Basic labels such as `1st — Player A` suffice.

**Owners:** [#22 — Implement basic player placement](https://github.com/mikenappi/Project-Racer/issues/22), #21/#24 recorded finishes, and [#26 — Create basic results screen](https://github.com/mikenappi/Project-Racer/issues/26).

**Current:** pending. `PlacementService.luau` is a TODO module, not a working placement system. Timer and results are also pending. #22 owns the exact deterministic tie rule; #26 already requires names, positions, finish times, and clearly distinguished DNF/unfinished players.

### 9. Reset / respawn

**Required:** recover from flipping, falling off the map, becoming stuck, or intentional reset. Return to a valid drivable position, preferably the last accepted checkpoint (starting slot before any checkpoint), without awarding checkpoints, laps, or a finish.

**Owner:** [#23 — Implement off-track recovery and respawn](https://github.com/mikenappi/Project-Racer/issues/23), completed; preserve it rather than reopen or rebuild it.

**Current:** `RespawnService.luau` validates and rate-limits R requests; `PlayerVehicleService.luau` and `VehicleService.luau` own placement, upright reset, velocity/input clearing, seating, and replacement cleanup. Death/fall replacement uses the saved checkpoint and reseats the owner after checkpoint progress; before checkpoint 1 it retains spawn-slot behavior. Blocked manual reset leaves the current car/progress unchanged; blocked replacement at an earned checkpoint retries without falling back to the grid. Flips/stuck situations use manual R; automatic recovery is tied to the fall threshold/lifecycle. See [CHECKPOINTS.md](CHECKPOINTS.md) for exact eligibility and ground/clearance rules. Future lap/finish integration must verify that recovery cannot grant progress in those new systems; that is not evidence that completed #23 needs rebuilding.

## Whole-loop acceptance checklist

These unchecked items are future integrated runtime acceptance under #27. They do not undo completed component issues. Each row maps the original issue #1 checklist to its feature owners.

| Runtime check | Feature issues | Current evidence / remaining work |
| --- | --- | --- |
| [ ] Two players join the game | #9, #18, #27 | Player lifecycle exists; full race participation unverified. |
| [ ] Both players get vehicles | #7, #8, #9, #27 | Completed components; verify separate ownership/control with two clients. |
| [ ] Both players are positioned at the starting grid | #15, #19 | Initial spawn slots exist; per-race grid integration pending. |
| [ ] A race countdown begins | #18, #20, #25 | Pending. |
| [ ] The race starts | #18, #20 | Pending synchronized GO and early-start prevention. |
| [ ] Players drive through checkpoints | #15, #16, #27 | Completed #16, prior single-client Studio checks; multi-client integration unverified. |
| [ ] The game tracks each player's lap | #17, #25 | Pending. |
| [ ] Players can reset if necessary | #9, #16, #23, #27 | Completed recovery; verify alongside future laps/finish states. |
| [ ] One player completes the required laps | #17, #24 | Pending. |
| [ ] The game recognizes that player as finished | #21, #24 | Pending. |
| [ ] Additional players can finish afterward | #18, #22, #24 | Pending; first finisher must not stop other racers. |
| [ ] Players receive their finishing position | #22, #24, #26 | Pending. |
| [ ] Players race again | #18, #19, #20, #26, #27 | Required by issue #1's opening loop; full lifecycle/cleanup pending. |

## Repeat-race and presentation integration

#18 defines `Waiting → Loading → Countdown → Racing → Results → Waiting`, authoritative state changes, valid transitions, and per-race cleanup. #19 positions racers again, #20 starts a fresh countdown, #21 resets timing, #17/#16 reset progress, and #22/#24/#26 clear prior placement/finish/results data. The checkpoint-only restart currently available is useful infrastructure, not this finished loop.

[#25 — Create basic race HUD](https://github.com/mikenappi/Project-Racer/issues/25) covers countdown/GO, lap total, elapsed time, placement, and waiting/finished states. Current `RaceHUD.local.luau` displays checkpoint count, the R control, and reset feedback only; extend that working UI. Results #26 shows server results consistently and clears before the next race.

Exact participant/readiness, late-join, race-end/timeout/DNF, and active-progress tie policies are implementation decisions owned by #18/#22 and exposed by #26. They are not established current behavior. The current checkpoint path adds late joiners at zero. Resolve lifecycle policies in those feature issues without silently treating this temporary policy as a finished multiplayer design.

## Validation and completion boundary

Definition acceptance for #1 is covered here: all nine systems, all twelve original checklist items, repeat racing, explicit feature owners, and completed/unverified/pending distinctions. Source and issue review does not establish physics, replication, seat welds, or current Studio asset correctness.

For this documentation change, both existing regression runners were attempted on 2026-10-08: `tests/run_checkpoints.py` and `tests/run_vehicle_lifecycle.py`. They could not execute their generated Luau harnesses because the `luau` executable was unavailable on PATH (`FileNotFoundError`). No new passing regression result is claimed. The prior passes remain documented in CHECKPOINTS.md. With a Luau CLI available, run from the repository root:

```text
python tests/run_checkpoints.py <path-to-luau>
python tests/run_vehicle_lifecycle.py <path-to-luau>
```

Later runtime acceptance belongs to #27, with reproducible failures tracked under [#28 — Document bugs from the first multiplayer race test](https://github.com/mikenappi/Project-Racer/issues/28):

1. Verify Studio is **Project-Racer Development**, place `130359159608842`, universe `8788799405`, before any Studio operation. Use the existing Script Sync roots; never publish as part of these checks.
2. Start a local server with at least two clients. Complete every checklist row above, recording pass/fail and conditions; hold throttle during countdown to test early-start prevention.
3. Put racers at different checkpoints/laps; attempt skips, repeats, and early finish crossings. Verify independent server progress, consistent placement, and immutable finishes while another player continues.
4. Follow CHECKPOINTS.md recovery checks: R before/after checkpoints, flip/stuck, fall/death, on-foot reseating, blocked/missing ground, cooldown, ownership rejection, and no duplicate vehicles. Verify no lap or finish gain once those systems exist.
5. Complete another race in the same session: fresh grid, countdown, progress, timer, placement, and results. Include a player leaving mid-race and confirm the chosen #18 end policy cannot leave the lifecycle stuck.
6. Record failures with reproduction steps and link them through #28; if none occur, explicitly record tested cases and the result. Do not equate this definition document with passing #27.
