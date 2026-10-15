# Performance repair — 2026-10-09

## Report and scope

The user reports that two Studio clients correctly update placement on checkpoint
crossings, but both windows suffer low FPS; solo Play was fine. They did not
complete the race. This is partial multiplayer evidence, not finish/full-loop
acceptance. They requested a performance repair and removal of shader-style effects.

## Applied in Development (place 130359159608842)

- Replaced `Workspace["Anti-Gravity"].Script` with the versioned template
  `tools/AntiGravityZone.server.luau`. The old script recursively enumerated the
  entire workspace on every legacy wait and started another waiting coroutine for
  every eligible in-zone part, even when a BodyForce already existed.
- The replacement caches candidate parts once and maintains that cache using
  descendant events. One 10 Hz heartbeat loop manages one owned force per eligible
  dynamic part. There are no per-part coroutine/wait loops, no catch-up bursts,
  and no forces on anchored scenery. Exit/removal cleans only its own forces.
- Preserved the 196.175 lift acceleration, world-axis zone bounds, existing part
  class eligibility, and respect for another system's existing BodyForce.
- Archived 35 PostEffect instances (bloom, blur, sun rays, color correction and
  depth of field) from Workspace/Lighting into ServerStorage. Objects directly
  under Workspace included repeated imported effects; their presence alone does
  not prove they were all contributing rendering cost. Zero remain in the scene.
- Sky, materials, map geometry, collisions and global shadow settings were preserved.
  No additional effect-writing game script was found in the scoped script scan;
  Roblox's built-in VR camera modules mention effects and were left unchanged.

## Backup and Git/Studio workflow

The original disabled script clone and every original effect are preserved in
`ServerStorage.PerformanceBackup_20261009`. Each archived effect has an
`OriginalParent` ObjectValue plus original name/enabled attributes in its record.
The backup lives outside Workspace/Lighting; scripts in it are disabled.

These changes are applied to the open Studio Edit datamodel, not published to
Roblox. Save the place through the usual Studio workflow. Non-code place edits
are not included in the Git diff, so checking out the branch on another computer
does not automatically remove effects or replace the imported Workspace script.

No Script Sync root was added or changed. The replacement template is versioned
under tools because this imported Workspace script is outside the existing sync
roots. To reproduce: back up its source, paste the template into
`Workspace["Anti-Gravity"].Script`, and run `tools/ArchivePostEffects.luau` in
the Edit-mode Command Bar. That archive utility is safe to rerun.

To undo the visual change, move each archived PostEffect back to the Instance in
its record's OriginalParent.Value, provided that parent still exists. The effect's
original properties are retained. To undo the script repair, restore Source from
OriginalAntiGravityScript and its OriginalEnabled attribute. Stop Play first.

## Executed checks

- Replacement script passes standalone Luau compilation.
- Actual Studio Play: zone entry creates one force with expected magnitude;
  repeated updates retain the same single force; exit removes it; anchored parts
  receive none; another system's force is neither replaced nor deleted; re-entry
  works and test-part destruction leaves no fixture/forces behind.
- Before the repair, one earlier five-second server sample grew Lua memory
  from 881.863 to 884.660 MB (about 2.797 MB). Temporarily disabling the old script
  during that run grew about 0.105 MB over the next five seconds.
- After repair, a fresh single-client run grew from 980.822 to 980.885 MB
  (about 0.063 MB) in five seconds. Absolute heaps differ across sessions and
  include tooling/engine allocations; these short samples are not a controlled
  leak benchmark or proof of a particular FPS improvement.
- Server remained about 60 heartbeats/second. The inspected client stayed near
  15 rendered frames/second (median 66.5 ms, p95 68.2 ms), with reported rendering
  CPU work about 3.6 ms/frame. This did not demonstrate a client-FPS improvement.
  Background-window throttling is a hypothesis, not a confirmed diagnosis.
  The available APIs did not expose the focus/throttle setting; no user setting
  was changed.
- Post-Play Edit verification: repaired source remains installed, 35 archived
  effect records exist, zero PostEffects remain in Workspace/Lighting.

## Other place findings and next test

The scene contains roughly 3,567 parts, 417 MeshParts, 317 unions and thousands of
collidable/shadow-casting parts. Those counts are possible rendering/physics costs,
not proof of a bottleneck. Streaming was already enabled. Runtime unanchored parts
were consistent with the player/vehicle. The other imported scripts inspected were
startup prints and touched-trigger land mines; no comparable recurring task-growth
pattern was found. Racing code was also inspected; continuous path projection is
inactive on the current unconfigured track.

Retest with two clients, clicking each window into the foreground before judging
its FPS. Compare both foreground driving and the other, unfocused window.
If foreground FPS still drops, capture a client MicroProfiler sample while driving
and compare CPU/render/physics work and memory; normal driving and completing a
race remain pending. Do not mark the performance report or M1 acceptance closed
solely on the anti-gravity repair.

Play was stopped after testing; no experience publication was performed.
