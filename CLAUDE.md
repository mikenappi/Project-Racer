# CLAUDE.md

Project Racer is a multiplayer arcade racing game on Roblox. Treat this repository as the persistent project context for coding-agent work.

## Read first
Before making architectural changes, read:
- `docs/AI_CONTEXT.md`
- `docs/ARCHITECTURE.md`
- `docs/CONTRIBUTING.md`
- the feature-specific document relevant to the current task

## Working rules
- Preserve the existing architecture and Script Sync roots unless the user explicitly asks to reorganize them.
- Roblox Studio is the source of truth for non-code game content; Git is the source of truth for synchronized Luau source.
- Prefer the Roblox Studio MCP for questions/actions involving the live Studio place. Do not scan the user's device or unrelated files to infer Studio state.
- Keep authoritative race/game-state logic on the server. Client code handles input, camera, UI, and presentation.
- Keep tunable values in shared config modules rather than scattering magic numbers.
- Reuse existing services/controllers before creating overlapping systems.
- Follow `docs/CONTRIBUTING.md` naming/style conventions.
- Do not silently add dependencies or change the project workflow (for example, do not introduce Rojo) without approval.
- Before editing, inspect the relevant implementation and its docs so existing behavior is preserved.

## Teaching preference
The user knows general software development/OOP but is still learning Roblox-specific development.

If a task can be completed by the user in about 30 seconds and doing it themselves teaches a useful Roblox Studio concept, explain the exact steps instead of doing it for them. Automate repetitive, error-prone, or implementation-heavy work. Explain Roblox-specific architectural decisions briefly when they matter.

## Safety for agent actions
For destructive or broad changes, state what will change before doing it. Prefer small, reviewable edits. Never search the whole computer when the repository or Roblox Studio MCP already provides the needed context.
