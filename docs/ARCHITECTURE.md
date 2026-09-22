# Architecture Specifications

## Source of truth

Roblox Studio is the source of truth for the world, vehicles, models, UI instances, lighting, terrain, and other non-code objects. Git is the source of truth for Luau source files exported through Studio's native Script Sync.

## Script layout

| Studio folder | Local repository folder | Purpose |
| --- | --- | --- |
| `ServerScriptService/Server` | `src/server` | Server-only race and vehicle logic |
| `ReplicatedStorage/Shared` | `src/shared` | Modules shared by server and client |
| `StarterPlayer/StarterPlayerScripts/Client` | `src/client` | Client controls, camera, and race UI logic |

Only Script, LocalScript, ModuleScript, and Folder instances belong inside these synced roots. Models, parts, RemoteEvents, UI objects, and other instances remain managed in Studio.

## File naming

- `Name.server.luau` represents a server Script.
- `Name.client.luau` represents a client Script.
- `Name.local.luau` represents a LocalScript.
- `Name.luau` represents a ModuleScript.
- A directory represents a Folder.

Rojo is not part of the initial workflow. Reconsider it only if the project later needs reproducible filesystem builds, automated publishing, or broader non-script source control.
