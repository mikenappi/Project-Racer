# Starting grid (issue #19)

The initial player car spawns on its grid slot with its owner seated. On every
Loading transition, RaceService snapshots the participating players' assigned
slots, resets each current car to its slot, clears momentum, and reseats its owner.
Results/Waiting coasting remains unchanged until the next Loading. Checkpoint
recovery during Racing remains authoritative and unchanged.

## Assignment and setup

PlayerVehicleService owns slots; no second ownership map is introduced. Existing
players are assigned in UserId order at startup; later arrivals take the lowest
free slot. Slots remain stable through replacement and subsequent races. Leaving
frees a slot without shifting other cars. Each race discards its preparation
records and prepares current vehicles again; display attributes cannot choose slots.

The existing PlaceholderVehicleSpawn defines the fallback grid's forward direction.
VehicleConfig uses three columns, one row, and spacing of 16 studs sideways / 20
studs backward. The three configured centers were inspected over the Development
road at Y=6.3333; the authored car measures approximately 7.2 x 2.3 x 10 studs.
Increase SpawnRows only after verifying the additional positions have clear road.
Alternatively, Workspace.VehicleSpawns may contain numbered upright BasePart
markers (1, 2, ...), noncollidable, non-touchable and non-queryable, pointing forward.
That folder replaces the fallback and determines available slots.

## Placement and failure behavior

VehicleService's existing ground/collider checks reject blocked or missing ground.
It preserves the chassis preparation anchor while moving the car and seated rider,
clears both velocity components, and increments ResetVersion so the controller
clears cached throttle/steering. Network ownership is restored when the controller
releases the lock for Racing. Automatic spawn waits for the character root before
placing and seating its owner, including before checkpoint 1.

Missing slots abort to Results with an explicit RaceState Reason. Placement retries
during Loading; a seated racer whose grid remains blocked causes an explicit grid
timeout. The existing readiness deadline still excludes players without a ready
character/seat. Cars are never placed on top of obstructions. Swapped/occupied grid
positions may require clearing the obstruction; there is no unsafe forced teleport.

## Validation

Run tests/run_race_lifecycle.py, run_vehicle_lifecycle.py, run_checkpoints.py and
run_camera.py with a Luau CLI. All four passed on 2026-10-08; the four changed
production Luau files compiled. Tests cover initial seating/root readiness,
distinct rotated slots, two race cycles after displaced cars, anchored placement,
velocity clearing, missing/insufficient slots, blocked-grid timeouts, departures,
replacement, checkpoint recovery, input clearing, and camera regressions.

These source tests simulate engine behavior. Studio evidence is recorded below.
The remaining multi-client acceptance is:

1. Start Project-Racer Development (place 130359159608842, universe 8788799405)
   with two clients after Script Sync. Both must spawn seated in distinct cars.
2. Confirm matching marker headings, ground clearance and separate controls.
3. Complete a race, let both cars coast away, and observe the next Countdown:
   both cars and riders must return to their slots, stationary until Go.
4. During Racing, press R after a checkpoint and reset a character; earned
   checkpoint recovery must still work. Disconnect one client and repeat a race.
5. In a temporary test session, remove a marker or block a slot. Confirm a clear
   grid failure and no stacked cars, then restore assets and retry. Do not publish.

### Studio results, 2026-10-08

Verified the Development place/universe IDs above and existing Script Sync source.
A fresh single-client Play session automatically spawned the owner seated in slot
1 and entered Racing. A temporary server test accelerated finish eligibility only
to exercise the actual Results -> Waiting -> Loading -> Countdown lifecycle. The
car moved over 20 studs away with injected coasting velocity, then race 2 returned
it and its seated owner to (182, 7.983324, 176), with the chassis anchored and both
velocity magnitudes below 0.01. An adjacent physical car spawned successfully at
16-stud separation and was destroyed after the check. This establishes real single
driver seating/reset and two-car clearance, not two-client replication or a fully
driven race. All temporary Play changes were discarded by stopping Play. No
persistent Studio assets or published experience were changed.
