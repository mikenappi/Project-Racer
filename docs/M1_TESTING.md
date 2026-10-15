# Milestone 1 verification — 2026-10-09

This records tests performed for the HUD/continuous-placement finalization. It
does not certify Milestone 1 or replace a two-client driving test. Earlier feature
documents retain their historical evidence.

## Executed source tests

Using the standalone Luau CLI and Python runners:

```text
luau tests/track_progress.luau
python tests/run_race_lifecycle.py <luau-executable>
python tests/run_checkpoints.py <luau-executable>
python tests/run_vehicle_lifecycle.py <luau-executable>
python tests/run_camera.py <luau-executable>
```

- PASS: real geometry/ranking modules exchange two racers' positions between
  identical checkpoints; curved route length, elevation, backward movement,
  loop/overlap isolation, corner-cut rejection, falls, teleports, distant initial
  attachment, excessive sampling gaps, reset initialization, malformed paths.
- PASS: real RaceService integrated with a synthetic path: independent racers,
  changed-only rank publication to both simulated subscribers, reset-version
  invalidation, departures, and fresh state on the next race. Only track asset
  loading is replaced in this integration fixture.
- PASS: lap/checkpoint precedence, frozen finish places/times, DNF, duplicate and
  stale requests, late joiners, departure retention, countdown/control gates,
  lobby readiness, starting-grid failures and cleanup, two complete simulated races.
- PASS: checkpoint/reset, vehicle lifecycle, and camera regression suites.
- PASS: millisecond formatting, ordinal exceptions (11th/12th/13th), actual HUD
  countdown function, timer origin/freeze/restart helpers.
- PASS: changed production Luau files compile; whitespace diff check.

The initial sandboxed Python attempts could not write temporary files; rerunning
with normal local access passed. These are deterministic source tests, not engine
physics, network replication, or two-client driving acceptance.

## Executed Studio checks

Development place **130359159608842**, universe **8788799405**, single-client Play.
Existing Script Sync propagated the new files. No experience publication or
persistent track edits were made; Play was stopped afterward.

- PASS: Waiting displays zero time and hides placement. Countdown displayed `2`
  while the timer remained `00:00.000`; Racing displayed increasing server time.
- PASS: an early finish crossing awarded no lap. In three successive circuits,
  checkpoint 7 and the approach side of the finish retained the old lap; crossing
  the directed finish plane advanced exactly one lap. The third crossing finished.
- PASS: final HUD showed `LAP 3/3`, `1st`, `FINISH`, and `TIME 01:39.245`, matching
  server finish time `99.24509811401367` seconds.
- PASS: Waiting reset time to zero; a second race displayed `LAP 1/3` and a new
  elapsed time. The real reset RemoteEvent returned `Returned to checkpoint`.
- PASS: a final fresh Play session verified reset feedback appears and expires after three seconds; its console contained only startup messages and the expected missing-path warning.
- PASS: character respawn preserved exactly one HUD (`ResetOnSpawn=false`), one
  owned vehicle, a seated player, correct lap, and continuing elapsed time.
- PASS: all HUD labels reported fitting their bounds at the available 1036×512
  viewport; timer/lap are upper right and placement lower left. This is a GUI
  bounds check, not a screenshot or comprehensive visual/resolution review.
- PASS: real Roblox marker instances loaded a temporary two-interval path;
  displaced endpoints and missing metadata were rejected. The fixture was destroyed.
- EXPECTED FALLBACK: the actual track has seven checkpoints and no
  `Workspace.RaceProgressPaths`; the server reports `Checkpoint fallback`.

The car was repositioned to exercise triggers; it was not normally driven around
the circuit. Two inspection commands initially failed (a GUI `Position` property
was mistaken for its child label, and an isolated module require had no live
vehicle state). Corrected inspections used `FindFirstChild` and the actual owned
workspace vehicle. These diagnostics changed no progression; their Output errors
are not game runtime failures. No game runtime error was observed in this session.

## Required manual acceptance (not yet run)

Use Studio **Test > Server & Clients**, with at least two clients. The available
MCP start/stop tool provides single-client Play; Remote Desktop Commander was offline.

- [ ] Author and validate all eight Development progress intervals (0–7) as
  described in [PLACEMENT.md](PLACEMENT.md); confirm `PlacementMode=Continuous`.
- [ ] Drive the entire track in both vehicles: acceleration, braking/reverse,
  steering, camera follow, ramps/collisions, grid clearance, and separate controls.
- [ ] Both clients click Start, see matching countdown/GO, cannot leave early,
  and see their own time/lap/place; verify 1280×720, 1920×1080 and narrow layouts,
  including the expanded Roblox player list and default controls.
- [ ] Overtake within the same checkpoint interval on a straight and curve;
  ranks change without a gate crossing and without flicker on both clients.
- [ ] Try skipped gates, corner cuts, backward driving, falls, wrong elevations,
  overlapping route sections, and teleports; none grants forward route credit.
- [ ] Use R, blocked reset, rapid repeated reset, and death/respawn; verify
  feedback, one vehicle, camera reconnection, preserved valid laps/checkpoints,
  and discarded pre-reset distance. Test recovery after a lap boundary.
- [ ] Finish A while B continues: A's place/time freezes and B keeps racing.
  Finish B later, then repeat with a finisher leaving and near-simultaneous finishes.
- [ ] Leave mid-race; remaining active positions compact behind retained finishers.
  Let a race time out; unfinished racers receive no fabricated finish.
- [ ] Run a second complete race: fresh grid, countdown, timer, progress, and results.
- [ ] Complete the separate results-screen issue #26 (all names, positions,
  times, DNF, and clearing). The new HUD only displays the local finish state.
- [ ] Record each failure with reproduction steps under #28 and retest it; finish #27.

## Issue audit and readiness

GitHub was inspected on 2026-10-09. #7/#8/#9/#10/#16/#23 are already closed;
their source and integration regressions remain relevant. #17–#22, #24 and #25
have implementation and the above evidence, but retain open status pending full
multiplayer acceptance. #34 covers continuous placement; current-track metadata
and two-client acceptance remain incomplete. #15, #26, #27 and #28 remain open.
#1 defines the first playable and remains open because its whole-loop checklist
has not been demonstrated. No new closing keywords are warranted by this run.

The branch is ready for focused user testing and path authoring, **not Milestone 2**.
Complete track setup, results UI and multiplayer acceptance before declaring M1 done.
