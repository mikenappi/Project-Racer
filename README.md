# Project Racer

Project Racer is a multiplayer arcade racing game being developed on Roblox.

The project is currently in its foundational development stage. The immediate goal is to build a small but complete playable racing loop before expanding into additional vehicles, tracks, abilities, progression, cosmetics, and other systems.

## First Playable Version

The first playable version of Project Racer will include:

* 1 playable vehicle
* 1 greybox track
* Support for 2+ players
* Start countdown
* Checkpoints
* Lap tracking
* Finish detection
* Basic race placement
* Vehicle reset and respawn

The following systems are intentionally outside the scope of the first playable version:

* Cosmetics
* Currency
* Progression
* Abilities
* Finished vehicle or environment models
* Finished UI
* Soundtrack

The purpose of this milestone is to prove that the core multiplayer racing loop works before additional systems are built on top of it.

## Development

Project Racer is developed using:

* **Roblox Studio** for the game world, models, UI objects, Roblox instances, testing, and publishing
* **Luau** for game code
* **GitHub** for source control, issues, branches, and project tracking
* **Roblox Studio Script Sync** for synchronizing Luau source files between the repository and Studio

Roblox Studio remains the source of truth for non-code game content.

Git remains the source of truth for synchronized Luau source files.

Rojo is not currently part of the development workflow.

## Project Structure

Game code is divided into three primary areas:

```text
src/
├── client/
├── server/
└── shared/
```

### Client

`src/client` contains code that runs for individual players, such as:

* Player input
* Camera behavior
* Vehicle controls
* Race HUD
* Local visual and audio behavior

### Server

`src/server` contains authoritative game logic, including:

* Race state
* Countdown logic
* Checkpoint validation
* Lap tracking
* Finish detection
* Placement
* Vehicle spawning and respawning

### Shared

`src/shared` contains modules that may be used by both the client and server, such as:

* Configuration
* Shared constants
* Types
* Utilities
* Common data structures

For a more detailed explanation of the project's code organization and client-server responsibilities, see [`docs/ARCHITECTU]()
