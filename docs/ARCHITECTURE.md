# Architecture Specifications

## Source of Truth

Roblox Studio is the source of truth for the game world and non-code instances, including:

* Tracks and terrain
* Vehicles and models
* Parts and attachments
* UI instances
* Lighting
* RemoteEvents and RemoteFunctions
* Other non-script Roblox instances

Git is the source of truth for Luau source files synchronized through Roblox Studio Script Sync.

Rojo is not currently part of the development workflow.

---

## Code Organization

Project Racer separates game code into three primary areas:

| Area   | Studio Location                             | Repository Location |
| ------ | ------------------------------------------- | ------------------- |
| Client | `StarterPlayer/StarterPlayerScripts/Client` | `src/client`        |
| Server | `ServerScriptService/Server`                | `src/server`        |
| Shared | `ReplicatedStorage/Shared`                  | `src/shared`        |

Only `Script`, `LocalScript`, `ModuleScript`, and `Folder` instances should exist inside these synchronized roots.

Models, Parts, RemoteEvents, UI objects, and other Roblox instances should remain managed through Studio.

---

## Client

The client contains code that runs separately for each individual player.

Client code is primarily responsible for receiving player input and presenting information to the player.

Examples include:

* Keyboard, controller, and mobile input
* Vehicle control input
* Camera behavior
* Race HUD
* Countdown display
* Speedometer
* Menus
* Local visual effects
* Local audio effects
* Displaying race position and lap information supplied by the server

Client code must not be trusted to determine authoritative game state.

For example, the client may detect or report that the player's vehicle appears to have crossed a checkpoint, but the server determines whether that checkpoint counts.

Client scripts placed under `StarterPlayerScripts` should normally use the `.local.luau` filename convention so Script Sync creates them as `LocalScript` instances.

---

## Server

The server contains authoritative game logic.

The server is responsible for determining game state that players must not be able to manipulate from their own clients.

Examples include:

* Race state
* Starting and ending races
* Authoritative countdown logic
* Checkpoint validation
* Lap validation and tracking
* Finish detection
* Player placement
* Vehicle spawning and respawning
* Reset behavior
* Multiplayer synchronization
* Player data
* Currency and progression when those systems are eventually implemented
* Purchase validation
* Anti-exploit validation

When there is disagreement between the client and server about authoritative game state, the server's state wins.

---

## Shared

Shared contains `ModuleScript` instances that may legitimately be required by both client and server code.

Examples include:

* Race configuration
* Vehicle configuration
* Shared constants
* Shared type definitions
* Utility functions
* Mathematical calculations
* Data structures
* Enumerations or identifiers used by both sides

Because `ReplicatedStorage` is accessible to clients, Shared must not contain secrets or server-only security logic.

If code only needs to exist on the server, it belongs in Server rather than Shared.

---

## Client-Server Communication

The client and server communicate using `RemoteEvent` and `RemoteFunction` instances managed in Roblox Studio.

A general rule for Project Racer is:

> **The client requests; the server decides.**

The client may send information about player actions or request an action.

The server validates the request and determines whether the resulting game-state change is allowed.

`RemoteEvent` and `RemoteFunction` instances themselves remain Studio-managed objects rather than synchronized source files.

---

## Script Sync File Naming

Script Sync uses filenames to determine what kind of Roblox script should exist in Studio.

| File               | Roblox Instance               |
| ------------------ | ----------------------------- |
| `Name.luau`        | ModuleScript                  |
| `Name.server.luau` | Script running on the server  |
| `Name.client.luau` | Script with Client RunContext |
| `Name.local.luau`  | LocalScript                   |
| Directory          | Folder                        |

For Project Racer:

* Server entry scripts should normally use `.server.luau`.
* Client scripts inside `StarterPlayerScripts/Client` should normally use `.local.luau`.
* Reusable modules should normally use `.luau`.

---

## Current Initial Structure

```text
src/
├── client/
│   ├── InputController.local.luau
│   ├── CameraController.local.luau
│   └── RaceHUD.local.luau
│
├── server/
│   ├── RaceManager.server.luau
│   ├── CheckpointService.luau
│   ├── PlacementService.luau
│   └── RespawnService.luau
│
└── shared/
    ├── RaceConfig.luau
    ├── VehicleConfig.luau
    └── Types.luau
```

This structure is expected to grow as individual game systems are implemented.

New files should be added according to whether their responsibility belongs to the client, server, or both.

