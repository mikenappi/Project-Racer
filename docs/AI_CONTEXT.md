# AI Context — Project Racer

This file gives coding agents the minimum persistent context needed to work effectively on Project Racer without relying on old chat history.

## Product goal
Project Racer is a multiplayer arcade racing game inspired by kart racers such as Mario Kart, while using its own mechanics, tracks, abilities, and progression. The immediate milestone is a small but complete first playable racing loop.

The first playable requires:
- 1 vehicle
- 1 greybox track
- 2+ players
- start countdown
- checkpoints
- lap tracking
- finish detection
- basic placement
- vehicle reset/respawn

Cosmetics, currency, progression, abilities, finished art/UI, and soundtrack are intentionally outside that milestone.

## Development workflow
- Roblox Studio: world, instances, models, UI objects, testing, publishing
- Luau: game code
- GitHub: source control, issues, branches, project tracking
- Roblox Studio Script Sync: repository ↔ Studio code synchronization
- Rojo is not currently part of the workflow

Do not change this workflow unless asked.

## Architecture
The repository uses:
- `src/client` for local input, camera, HUD, visual/audio behavior
- `src/server` for authoritative game logic and validation
- `src/shared` for configuration, types, constants, and safe shared utilities

Core rule: **client requests; server validates; server decides.**

Important race state such as checkpoints, laps, finish state, placement, spawning, and validation belongs on the server. Camera, player input, and UI belong on the client.

## Current implemented systems
Current code includes vehicle movement, per-player vehicle spawning/lifecycle, a racing camera, checkpoint/race/placement/respawn services, and shared race/vehicle/camera configuration.

Relevant files include:
- `src/client/InputController.local.luau`
- `src/client/CameraController.local.luau`
- `src/client/CameraRig.luau`
- `src/client/RaceHUD.local.luau`
- `src/server/PlayerVehicleService.luau`
- `src/server/VehicleService.luau`
- `src/server/VehicleController.server.luau`
- `src/server/CheckpointService.luau`
- `src/server/PlacementService.luau`
- `src/server/RaceManager.server.luau`
- `src/server/RespawnService.luau`
- `src/shared/VehicleConfig.luau`
- `src/shared/CameraConfig.luau`
- `src/shared/RaceConfig.luau`
- `src/shared/Types.luau`

The repository currently contains some nested folders created around Script Sync. Do not "clean up" or rename these automatically; preserve working Studio mappings unless the user explicitly asks to change them.

## Existing behavior to preserve
Vehicle movement is configurable and intentionally arcade-like rather than rigid simulation. The user specifically likes the current gliding feel because it may support a future drifting system.

The racing camera should behave like a kart-racing camera: follow the player's vehicle, remain usable while turning, and gradually settle behind the vehicle rather than snapping.

Vehicle lifecycle must continue to work after player/character respawn and support multiple players receiving separate vehicles.

## Coding conventions
Use `docs/CONTRIBUTING.md` as the authority. In short:
- variables/functions: `camelCase`
- types/modules: `PascalCase`
- constants: `UPPER_SNAKE_CASE`
- server systems: `Service` suffix where appropriate
- client systems: `Controller` suffix where appropriate
- tunable values: config modules
- comments explain non-obvious reasoning, not obvious syntax
- use Luau types where they clarify APIs/state

Prefer small modules with clear responsibilities and early returns. Avoid duplicate systems.

## Agent/tool behavior
When Roblox Studio MCP is available, use it for live Studio inspection and actions. Do not substitute filesystem searches, process scans, or broad device exploration for Studio inspection.

Before implementing an issue:
1. inspect the current relevant code and docs;
2. identify dependencies and existing behavior;
3. make the smallest coherent change;
4. keep tuning/configuration separate from logic where practical;
5. explain where the user can find each major part of the new functionality;
6. provide a concrete Studio/playtest procedure.

Do not close or merge GitHub issues unless explicitly asked.

## User learning preference
The user is comfortable with Python, Java, OOP, Git, and general software-engineering ideas, but is newer to Roblox/Luau/Studio-specific concepts.

If the user can perform a useful Roblox-specific setup step themselves in roughly 30 seconds, give them the exact step rather than taking control and spending many tool calls doing it. Use automation for substantive implementation, repetitive edits, verification, and tasks where agent tooling clearly saves time.
