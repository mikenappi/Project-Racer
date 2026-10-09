# Project Racer roadmap

[GAMEDESIGN.md](GAMEDESIGN.md) is the first-playable scope and acceptance checklist for [#1](https://github.com/mikenappi/Project-Racer/issues/1). This roadmap maps existing work; it does not introduce new features or certify runtime completion. Status snapshot: 2026-10-08.

## Preserve completed foundations

The closed component issues are [#7 vehicle](https://github.com/mikenappi/Project-Racer/issues/7), [#8 movement](https://github.com/mikenappi/Project-Racer/issues/8), [#9 spawning](https://github.com/mikenappi/Project-Racer/issues/9), [#10 camera](https://github.com/mikenappi/Project-Racer/issues/10), [#16 checkpoints](https://github.com/mikenappi/Project-Racer/issues/16), and [#23 recovery](https://github.com/mikenappi/Project-Racer/issues/23). Reuse the existing services and preserve driving feel, Script Sync layout, server authority, and checkpoint/reset behavior. Component completion does not substitute for the later two-client integrated test.

## Existing feature map and dependencies

Dependencies below are those listed in the GitHub issues, checked on 2026-10-08. A dependency on an open asset issue does not mean a completed source feature must be reopened. In particular, #16 is complete while #15 still needs full-track acceptance.

| Issue | Delivery | Listed dependencies | Current implementation evidence |
| --- | --- | --- | --- |
| [#15](https://github.com/mikenappi/Project-Racer/issues/15) | Complete greybox test track | #8 | Open; full circuit/width/start-finish acceptance unverified. Prior checkpoint asset checks are narrower. |
| [#16](https://github.com/mikenappi/Project-Racer/issues/16) | Ordered independent checkpoints | #15 | Completed; preserve and integrate. |
| [#17](https://github.com/mikenappi/Project-Racer/issues/17) | Independent laps, configurable total, lap wrap | #16 | Pending. |
| [#18](https://github.com/mikenappi/Project-Racer/issues/18) | Race state machine, participation/end rules, repeat-race cleanup | [#6](https://github.com/mikenappi/Project-Racer/issues/6) | Pending; current RaceManager only bootstraps checkpoints/recovery. |
| [#19](https://github.com/mikenappi/Project-Racer/issues/19) | Starting grid for every race | #9, #15 | Initial spawn infrastructure exists; race-grid integration pending. |
| [#20](https://github.com/mikenappi/Project-Racer/issues/20) | Shared countdown and early-start prevention | #18, #19, #8 | Pending. |
| [#21](https://github.com/mikenappi/Project-Racer/issues/21) | Server elapsed/finish time | #18 | Pending. |
| [#22](https://github.com/mikenappi/Project-Racer/issues/22) | Active placement and fixed finish order | #16, #17 | TODO module; pending. Coordinate finish records with #24. |
| [#23](https://github.com/mikenappi/Project-Racer/issues/23) | Manual/off-track recovery and respawn | #16, #9, #10 | Completed; preserve, do not rebuild/reopen. |
| [#24](https://github.com/mikenappi/Project-Racer/issues/24) | Validated one-time finish and immutable result | #17, #21, #18 | Pending. |
| [#25](https://github.com/mikenappi/Project-Racer/issues/25) | Basic countdown/lap/time/placement HUD | #17, #20, #21, #22 | Existing checkpoint/reset HUD is partial; remaining race UI pending. |
| [#26](https://github.com/mikenappi/Project-Racer/issues/26) | Basic results and next-race clearing | #18, #24, #22, #21 | Pending. |
| [#27](https://github.com/mikenappi/Project-Racer/issues/27) | Two-client whole loop, second race, disconnect checks | #8, #9, #10, #20, #16, #17, #22, #23, #24, #25, #26 | Integrated runtime acceptance pending. |
| [#28](https://github.com/mikenappi/Project-Racer/issues/28) | Reproducible test failures or explicit no-bug record | #27 | Follows the multiplayer test. |

## Integration sequence

1. Validate/finish track assets in #15; retain completed vehicle, checkpoint, camera, and recovery work.
2. Build #18 lifecycle and #19 per-race grid on existing services. #17 lap tracking builds on #16. These are feature tasks, not additional implementation for definition #1.
3. Integrate #20 countdown, #21 timer, #24 finish, and #22 placement using their listed dependencies. Agree on shared progress/finish contracts; #22's finished ordering consumes #24 results even though #24 is not a listed dependency in #22.
4. Extend #25 HUD, add #26 results, and complete #18's next-race cleanup. Decide readiness, late joins, ending/DNF, and tie rules within the owning features.
5. Run #27 against the scope checklist, including #23 recovery regressions with the new lap/finish systems and a second race. Record failures through #28.

Issue #1 ends with scope documentation and traceability. The complete playable milestone ends with demonstrated runtime acceptance in #27. No issue closure, comment, push, or experience publication is implied by this documentation update.
