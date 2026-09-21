# Contributing

## Normal workflow

1. Pull the latest `main`.
2. Create a short-lived branch such as `feat/checkpoints` or `fix/vehicle-respawn`.
3. Open the development place in Roblox Studio and allow Script Sync to resume.
4. Make one focused change and test it in Studio.
5. Review `git status` and the diff.
6. Commit with a concise message, push the branch, and open a pull request.
7. Merge only after the change works in Studio, then delete the branch.

Do not work directly on `main`. Keep one issue or closely related change per branch.

## Script Sync safety

- Avoid having two people edit the same synced script at the same time.
- If Studio reports a sync conflict, read the proposed additions, changes, and deletions before choosing either side.
- Do not delete a top-level synced folder from disk. Stop its sync in Studio first.
- Keep non-script Roblox instances outside the three synced code folders.

## Never commit

Do not commit place files, Studio lock files, generated sourcemaps, editor caches, build output, API keys, authentication cookies, passwords, tokens, or `.env` files. The repository's `.gitignore` blocks the common cases, but always review staged changes before committing.
