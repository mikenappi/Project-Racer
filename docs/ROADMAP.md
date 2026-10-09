# Project Racer roadmap

The first-playable scope is [GAMEDESIGN.md](GAMEDESIGN.md). Current evidence and
the required manual checklist are in [M1_TESTING.md](M1_TESTING.md). Status checked
against GitHub and the local implementation on 2026-10-09; implemented does not
mean multiplayer-validated.

| Issue | Dependencies | Current state |
| --- | --- | --- |
| #7, #8, #9, #10 | Vehicle foundation | Already closed; existing vehicle, spawning and camera preserved. Source regressions pass. |
| #15 | #8 | Open; normal full-course/two-car driving and track asset acceptance pending. |
| #16 | #15 | Already closed; ordered checkpoint authority preserved and regression-tested. |
| #17 | #16 | Implemented configurable laps and directed finish crossing; multiplayer acceptance pending. |
| #18 | #6 | Implemented full lifecycle, readiness, timeouts and cleanup; multiplayer acceptance pending. |
| #19 | #9, #15 | Implemented per-race grid and clear insufficient-slot failures; multiplayer acceptance pending. |
| #20 | #18, #19, #8 | Implemented countdown/control gates; multiplayer acceptance pending. |
| #21 | #18 | Implemented shared server clock and frozen per-racer times; multiplayer acceptance pending. |
| #22 | #16, #17 | Implemented lap/checkpoint ranking and retained finish order; multiplayer acceptance pending. |
| #23 | #16, #9, #10 | Already closed; recovery preserved, source and single-client reset/respawn checks pass. |
| #24 | #17, #21, #18 | Implemented immutable one-time finishes; multiplayer acceptance pending. |
| #25 | #17, #20, #21, #22 | Minimal upper-right time/lap and lower-left ordinal HUD implemented; two-client and multi-resolution review pending. |
| #26 | #18, #24, #22, #21 | Full results screen still absent; local FINISH/DNF status is not a results table. |
| #27 | #8, #9, #10, #20, #16, #17, #22, #23, #24, #25, #26 | Two-client full-loop driving and second-race acceptance pending. |
| #28 | #27 | Record reproducible bugs from the multiplayer test. |
| #34 | #16, #17, #22, #23, #24 | Continuous-placement infrastructure/source tests implemented; Development path authoring and runtime multiplayer acceptance pending. |

## Next steps

1. Author all eight Development progress paths, following [PLACEMENT.md](PLACEMENT.md),
   and validate driveability/corridor separation. The live map uses checkpoint fallback.
2. Complete #26 using the existing immutable RaceService results.
3. Run #27's two-client checklist, including normal driving, overtakes, resets,
   finishers/departures and a second complete race. Record failures in #28 and retest.
4. Review the finalization PR. Do not merge automatically or declare M1 complete
   until its required acceptance passes. #1 remains open with its whole-loop checklist.
