<!-- contextgate:begin -->
# Project-Racer

Keep the existing Roblox Studio Script Sync layout. Studio owns non-code assets; Git owns Luau source. Do not add Rojo, dependencies, or change sync workflow without a task that requires it. Preserve unrelated files and current work. See CLAUDE.md for existing project conventions; read feature documentation only when relevant.

The server owns race results, checkpoint validation and reset decisions. Clients handle input, camera and presentation; shared modules hold configuration and types. Reuse existing services before adding parallel systems.

Start with the subsystem involved:
- Checkpoints/races: src/server/CheckpointService.luau, RaceManager.server.luau, RespawnService.luau; src/shared/RaceConfig.luau.
- Vehicle lifecycle/recovery: src/server/PlayerVehicleService.luau and VehicleService.luau; src/shared/VehicleConfig.luau; tests/vehicle_lifecycle.luau and run_vehicle_lifecycle.py.
- Camera: src/client/CameraRig.luau and CameraController.local.luau; src/shared/CameraConfig.luau; tests/camera.luau and run_camera.py.

Follow references only as needed. TODO responsibilities are not implemented behavior. For source-only audits, report runtime/Studio limits. For changes, run the relevant existing test and use Studio only when the requested behavior needs runtime validation; never modify an unrelated open experience. Do not claim source tests validate real physics or networking.
<!-- contextgate:end -->
