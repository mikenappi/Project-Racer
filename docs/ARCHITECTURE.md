# Project Racer Architecture

This document explains where the major systems in **Project Racer** should live and how the client, server, and shared code should interact.

The main goal of this architecture is to keep the project organized, secure, and easy to expand as more systems are added.

---

## 1. Architecture Overview

Project Racer is divided into three main code areas:

| Area     | Purpose                                                                                     |
| -------- | ------------------------------------------------------------------------------------------- |
| `Client` | Handles player-specific input, camera behavior, UI, and visual feedback                     |
| `Server` | Handles authoritative game logic such as races, laps, checkpoints, spawning, and validation |
| `Shared` | Contains code, configuration, types, and utilities needed by both the client and server     |

The general rule is:

> The client handles player interaction and presentation. The server handles the official game state.

This prevents important game systems from depending on information that can be modified by individual players.

---

## 2. Client Code

Client code runs separately on each player's device.

In Roblox, this is mainly handled using `LocalScripts`.

Our client code should live under the `Client` portion of the project.

Example:

```text
Client/
├── Controllers/
├── UI/
├── Camera/
└── Main.client.luau
```

### Client Responsibilities

The client should handle systems such as:

* Keyboard and controller input
* Vehicle input
* Camera control
* HUD elements
* Speedometer
* Countdown visuals
* Placement display
* Lap display
* Visual effects
* Sound effects
* Local animations

The client may send requests to the server, but it should not decide important race results.

For example:

```text
Player presses reset
        ↓
Client sends reset request
        ↓
Server checks request
        ↓
Server resets vehicle
```

---

## 3. Server Code

Server code runs on the Roblox game server.

Server scripts and server-only modules should generally live inside `ServerScriptService`.

Our server code should live under the `Server` portion of the project.

Example:

```text
Server/
├── Services/
├── Systems/
└── Main.server.luau
```

### Server Responsibilities

The server should control important game systems such as:

* Race state
* Race countdown
* Checkpoint validation
* Lap tracking
* Finish detection
* Player placement
* Vehicle spawning
* Vehicle resetting
* Player initialization
* Race initialization
* Rewards
* Progression
* Currency
* Anti-cheat validation

The server should be considered the authoritative source for race information.

For example, the client should not be able to simply tell the server:

```text
"I completed another lap."
```

Instead, the server should determine whether the player actually completed the required checkpoints before increasing the lap count.

---

## 4. Shared Code

Some code needs to be accessible by both the client and server.

Shared code should be stored in `ReplicatedStorage`.

Our shared code should live under the `Shared` portion of the project.

Example:

```text
Shared/
├── Config/
├── Constants/
├── Types/
└── Utility/
```

Shared code may include:

* Configuration values
* Constants
* Type definitions
* Utility functions
* Shared data structures
* Vehicle configuration
* Race configuration

Shared code should not contain sensitive server-only logic.

Anything stored in `ReplicatedStorage` can potentially be inspected by a player's client.

---

## 5. Script Types

Roblox uses several different script types.

### Scripts

Regular `Scripts` run on the server.

They should mainly be used as server entry points that initialize the game's server systems.

Example:

```text
Main.server.luau
```

The main server script may load the different server modules when the game starts.

---

### LocalScripts

`LocalScripts` run on an individual player's device.

They are useful for:

* Input
* UI
* Camera behavior
* Visual effects
* Local sound
* Client-side feedback

Example:

```text
Main.client.luau
```

---

### ModuleScripts

`ModuleScripts` contain reusable code that can be loaded using `require()`.

Most major game systems should eventually be implemented as modules rather than large individual scripts.

Example:

```text
RaceService.luau
CheckpointService.luau
VehicleService.luau
```

This makes systems easier to test, maintain, and expand.

A ModuleScript may be:

* Server-only
* Client-only
* Shared

Its location determines which side of the game should use it.

---

## 6. ReplicatedStorage

`ReplicatedStorage` contains objects that both the client and server can access.

It should be used for things such as:

```text
ReplicatedStorage
├── Shared
└── Remotes
```

Possible shared content includes:

* Configuration
* Constants
* Type definitions
* Utility modules
* RemoteEvents
* RemoteFunctions

Important server logic should not be stored here.

---

## 7. ServerScriptService

`ServerScriptService` contains code that should only run on the server.

Example:

```text
ServerScriptService
└── Server
    ├── Main.server.luau
    ├── RaceService.luau
    ├── VehicleService.luau
    ├── CheckpointService.luau
    ├── LapService.luau
    └── PlayerService.luau
```

This should contain most of Project Racer's authoritative systems.

---

## 8. ServerStorage

`ServerStorage` contains assets that should only be accessible by the server.

Unlike `ServerScriptService`, it is mainly intended for storage rather than active scripts.

Possible uses include:

```text
ServerStorage
├── Vehicles
├── TrackTemplates
└── ServerAssets
```

For example, vehicle templates could remain in `ServerStorage` until the server needs to spawn them into the game.

---

## 9. RemoteEvents

`RemoteEvents` allow the client and server to send messages to each other.

They should be used when one side needs to notify the other without waiting for a response.

Example:

```text
Client
  ↓
Request Vehicle Reset
  ↓
RemoteEvent
  ↓
Server
```

They can also work in the opposite direction:

```text
Server
  ↓
Race Started
  ↓
RemoteEvent
  ↓
Client
  ↓
Display countdown
```

RemoteEvents will likely be the main method of client-server communication in Project Racer.

---

## 10. RemoteFunctions

`RemoteFunctions` are similar to RemoteEvents but are used when the caller expects a response.

Example:

```text
Client
  ↓
"What vehicles can I use?"
  ↓
RemoteFunction
  ↓
Server
  ↓
Returns available vehicles
```

RemoteFunctions should only be used when an immediate response is actually needed.

RemoteEvents should be preferred for normal notifications and actions.

---

## 11. Remote Security

Clients should never be trusted automatically.

A client can request that something happen, but the server should validate the request before changing important game state.

The general rule should be:

> Client requests. Server validates. Server decides.

For example:

```text
BAD

Client:
"I completed checkpoint 5."

Server:
"Okay."
```

Instead:

```text
BETTER

Player reaches checkpoint
        ↓
Server detects or validates checkpoint
        ↓
Server updates checkpoint progress
```

Important systems that should be server-controlled include:

* Checkpoints
* Laps
* Finish detection
* Placement
* Rewards
* Currency
* Progression
* Vehicle spawning
* Important race state

---

## 12. Players

The Roblox `Players` service manages players connected to the server.

It can be used to detect when players:

* Join
* Leave
* Spawn
* Respawn

A future `PlayerService` may handle these events.

Example:

```text
Player joins
    ↓
PlayerService
    ↓
Initialize player
    ↓
Spawn vehicle
    ↓
Add player to race
```

Common player events include:

```lua
Players.PlayerAdded
Players.PlayerRemoving
```

Player character spawning can also be tracked using events such as:

```lua
Player.CharacterAdded
```

---

## 13. Workspace

`Workspace` represents the active 3D game world.

Objects currently being used in the game should exist here.

Example:

```text
Workspace
├── Track
├── Vehicles
├── Checkpoints
├── SpawnPoints
└── Characters
```

Workspace should mainly contain physical game objects rather than large amounts of game logic.

For example, checkpoints should not each require their own separate script.

Instead of:

```text
Checkpoint1
└── Script

Checkpoint2
└── Script

Checkpoint3
└── Script
```

Project Racer should use something closer to:

```text
Workspace
└── Checkpoints
    ├── Checkpoint1
    ├── Checkpoint2
    └── Checkpoint3

Server
└── CheckpointService.luau
```

One centralized checkpoint system can manage every checkpoint.

---

## 14. Planned Major Systems

The following structure represents the expected location of Project Racer's major systems.

### Server Systems

```text
Server/
├── RaceService
├── CheckpointService
├── LapService
├── PlacementService
├── VehicleService
└── PlayerService
```

### Client Systems

```text
Client/
├── InputController
├── VehicleController
├── CameraController
└── UIController
```

### Shared Systems

```text
Shared/
├── Config
├── Constants
├── Types
└── Utility
```

These names may change as development continues.

The important part is keeping server, client, and shared responsibilities separated.

---

## 15. High-Level Project Structure

A simplified version of the final Roblox structure may look like this:

```text
ReplicatedStorage
├── Shared
│   ├── Config
│   ├── Constants
│   ├── Types
│   └── Utility
│
└── Remotes
    ├── VehicleInput
    ├── ResetVehicle
    └── RaceStateChanged

ServerScriptService
└── Server
    ├── Main.server.luau
    ├── RaceService.luau
    ├── CheckpointService.luau
    ├── LapService.luau
    ├── PlacementService.luau
    ├── VehicleService.luau
    └── PlayerService.luau

StarterPlayer
└── StarterPlayerScripts
    └── Client
        ├── Main.client.luau
        ├── InputController.luau
        ├── VehicleController.luau
        ├── CameraController.luau
        └── UIController.luau

ServerStorage
├── Vehicles
└── ServerAssets

Workspace
├── Track
├── Checkpoints
├── Vehicles
└── SpawnPoints
```

This structure is not required to exist immediately. It represents the direction the project should follow as systems are implemented.

---

## 16. Communication Overview

The game's architecture can be summarized as:

```text
CLIENT
│
│ Input
│ UI
│ Camera
│ Visual feedback
│
↓
RemoteEvents / RemoteFunctions
│
↓
SERVER
│
│ Race logic
│ Lap validation
│ Checkpoint validation
│ Placement
│ Vehicle spawning
│ Player state
│
↓
WORKSPACE
│
│ Track
│ Vehicles
│ Checkpoints
│ Characters
```

Shared code used by both sides lives in:

```text
ReplicatedStorage
└── Shared
```

---

## 17. Architecture Rules

Project Racer should generally follow these rules:

1. Keep authoritative game logic on the server.
2. Keep input, UI, camera, and visual behavior on the client.
3. Put reusable code inside ModuleScripts.
4. Put shared modules and configuration in `ReplicatedStorage`.
5. Put server-only assets in `ServerStorage`.
6. Put server game systems in `ServerScriptService`.
7. Use RemoteEvents for most client-server communication.
8. Use RemoteFunctions only when a response is required.
9. Never blindly trust information received from a client.
10. Keep Workspace focused on physical objects rather than scattered scripts.
11. Prefer centralized systems over placing individual scripts inside every game object.
12. Keep the `Client`, `Server`, and `Shared` responsibilities clearly separated.

---

## References

Roblox Creator Documentation:

* Client-server model: https://create.roblox.com/docs/projects/client-server
* Script locations: https://create.roblox.com/docs/scripting/locations
* ModuleScripts: https://create.roblox.com/docs/scripting/module
* RemoteEvents and RemoteFunctions: https://create.roblox.com/docs/scripting/events/remote
* Client-server security: https://create.roblox.com/docs/scripting/security/client-server-boundary
* Players service: https://create.roblox.com/docs/reference/engine/classes/Players
* ServerScriptService: https://create.roblox.com/docs/reference/engine/classes/ServerScriptService
* Workspace: https://create.roblox.com/docs/workspace
