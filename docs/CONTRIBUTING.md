# Contributing

This document defines the coding conventions used throughout the project. The goal is to keep the codebase consistent, readable, and easy to work with as the project grows and multiple developers contribute.

---

## Naming Conventions

| Element               | Convention          | Example             |
| --------------------- | ------------------- | ------------------- |
| Local variables       | `camelCase`         | `currentLap`        |
| Functions             | `camelCase`         | `startRace()`       |
| Luau types            | `PascalCase`        | `RaceState`         |
| Constants             | `UPPER_SNAKE_CASE`  | `MAX_LAPS`          |
| ModuleScripts         | `PascalCase`        | `RaceService`       |
| Folders               | `PascalCase`        | `Controllers`       |
| Server systems        | `Service` suffix    | `RaceService`       |
| Client systems        | `Controller` suffix | `VehicleController` |
| Configuration modules | `Config` suffix     | `RaceConfig`        |
| Type modules          | `Types` suffix      | `RaceTypes`         |

Names should clearly describe the purpose of the value, function, module, or system.

Prefer descriptive names:
```lua
local currentCheckpoint = 4

local function resetVehicle()
end
```

Avoid unclear names:
```lua
local cp = 4

local function doThing()
end
```
Short variable names such as `i` are acceptable when their purpose is obvious, such as loop indexes.

---

## Module Naming

ModuleScripts should use `PascalCase` and should describe the responsibility of the module.

Examples:
```text
RaceService.luau
CheckpointService.luau
VehicleController.luau
RaceConfig.luau
RaceTypes.luau
```

Avoid vague module names such as:
```text
Manager.luau
Handler.luau
Stuff.luau
Code.luau
```

Do not add `Module` to the end of ModuleScript names.

Use:
```text
RaceService
```

Instead of:
```text
RaceServiceModule
```

---

## Service and Controller Naming

Server-side systems responsible for game logic should generally use the `Service` suffix.

Examples:
```text
RaceService
CheckpointService
VehicleService
RespawnService
```

Client-side systems should generally use the `Controller` suffix.

Examples:
```text
VehicleController
CameraController
InputController
RaceUIController
```

Roblox engine services should keep their normal Roblox names.
```lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
```

---

## Folder Conventions

The project is separated into three main areas:
```text
src/
    Client/
    Server/
    Shared/
```

| Folder   | Purpose                                                             |
| -------- | ------------------------------------------------------------------- |
| `Client` | Code that runs only on the player's client                          |
| `Server` | Authoritative server-side game logic                                |
| `Shared` | Code and data that can safely be accessed by both client and server |

Additional folders should be created when they are needed.

Common examples include:
```text
Client/
    Controllers/
    UI/

Server/
    Services/

Shared/
    Config/
    Types/
    Utility/
```

### Client

Typical client responsibilities include:
* Player input
* Camera behavior
* Local vehicle controls
* UI
* Client-side visual effects

### Server

Typical server responsibilities include:
* Race state
* Lap tracking/Checkpoint validation/Finish detection
* Player placement
* Respawning
* Server-side validation

### Shared

Typical shared content includes:
* Configuration
* Shared types
* Utility modules
* Data structures used by both client and server

Sensitive or server-authoritative logic should not be placed in `Shared`.

---

## Constants and Configuration

Constants that exist only within one script should use `UPPER_SNAKE_CASE`.
```lua
local MAX_RETRIES = 3
local DEFAULT_SPEED = 50
```

Values that are likely to change during development or balancing should generally be placed inside configuration modules.

Example:
```lua
local RaceConfig = {
	MaxLaps = 3,
	CountdownDuration = 3,
	RespawnDelay = 2,
}

return RaceConfig
```

Configuration modules should use `PascalCase` keys.
Avoid scattering configurable values throughout the code.

Prefer:
```lua
if currentLap >= RaceConfig.MaxLaps then
	finishRace()
end
```

Instead of repeatedly using unexplained values:
```lua
if currentLap >= 3 then
	finishRace()
end
```

Related configuration values should be grouped together.

Examples:
```text
RaceConfig.luau
VehicleConfig.luau
```
Do not create a separate configuration module for every individual constant.

---

## Comments

Comments should explain information that is not already obvious from the code.

Comments are useful for:
* Non-obvious decisions
* Important assumptions
* Workarounds
* Roblox-specific behavior
* Complicated calculations
* Reasons behind unusual implementation choices

Good:
```lua
-- Checkpoints must be completed in order so players
-- cannot skip parts of the track to complete a lap.
if checkpointIndex ~= expectedCheckpoint then
	return
end
```

Avoid comments that simply repeat the code.
```lua
-- Increase the lap by one.
currentLap += 1
```
Code should generally be understandable through clear names and structure without requiring excessive comments.

### TODO Comments

Temporary unfinished work may use `TODO:`.
```lua
-- TODO: Replace temporary respawning with checkpoint-based respawning.
```
TODO comments should explain what remains to be done. Avoid ambiguous `TODO` comments. Larger or long-term tasks should be tracked through GitHub Issues instead of remaining indefinitely as TODO comments.

---

## Type Annotations

Luau type annotations should be used where they improve readability, clarify interfaces, or help prevent meaningful errors.

Type annotations are expected for:

| Situation                                     | Expected              |
| --------------------------------------------- | --------------------- |
| Public module APIs                            | Yes                   |
| Shared data structures                        | Yes                   |
| Custom types                                  | Yes                   |
| Important game state                          | Yes                   |
| Complex tables                                | Yes                   |
| Function parameters where the type is unclear | Yes                   |
| Function return values where useful           | Yes                   |
| Obvious local variables                       | Usually not necessary |

Example:
```lua
local function calculatePlacement(
	player: Player,
	checkpointIndex: number
): number
	-- ...
end
```
Custom types should use `PascalCase`.

```lua
export type RaceState = {
	currentLap: number,
	currentCheckpoint: number,
	finished: boolean,
	finishTime: number?,
}
```

Obvious local variables do not need unnecessary annotations.

```lua
local currentLap = 1
local finished = false
```

The goal is useful type safety 

`--!strict` is not currently required project-wide and might just be introduced later as the codebase becomes more established.

---

## General Code Style

Functions should generally have one clear responsibility.

Prefer early returns when they reduce unnecessary nesting.

Prefer:
```lua
local function processCheckpoint(player: Player, checkpointIndex: number)
	if not player then
		return
	end

	if checkpointIndex ~= expectedCheckpoint then
		return
	end

	advanceCheckpoint(player)
end
```

Instead of:
```lua
local function processCheckpoint(player: Player, checkpointIndex: number)
	if player then
		if checkpointIndex == expectedCheckpoint then
			advanceCheckpoint(player)
		end
	end
end
```

Before creating a new module, consider whether the functionality belongs inside an existing module. Avoid duplicating functionality that already exists elsewhere in the project.

---

## Convention Summary

| Element               | Convention          | Example             |
| --------------------- | ------------------- | ------------------- |
| Variables             | `camelCase`         | `currentLap`        |
| Functions             | `camelCase`         | `startRace()`       |
| Types                 | `PascalCase`        | `RaceState`         |
| Constants             | `UPPER_SNAKE_CASE`  | `MAX_LAPS`          |
| ModuleScripts         | `PascalCase`        | `RaceService`       |
| Server systems        | `Service` suffix    | `RaceService`       |
| Client systems        | `Controller` suffix | `VehicleController` |
| Configuration modules | `Config` suffix     | `RaceConfig`        |
| Type modules          | `Types` suffix      | `RaceTypes`         |
| Folders               | `PascalCase`        | `Controllers`       |
