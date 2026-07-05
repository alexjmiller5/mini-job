# CLAUDE.md

Scheduled job that runs on the mac mini — for work that needs a residential
IP (scraping), Apple data (Messages, Screen Time, Contacts), or local
hardware. Cloud-safe jobs do NOT belong here (see the `personal-infra` skill).

## How it runs

nix-darwin launchd user agent (`nix/darwin.nix`) → `scripts/run.sh` →
`op run --env-file=.env.tpl -- uv run python -m job.main`.

The module is consumed by the mac mini's nix-config
(github.com/alexjmiller5/nix-config) as a flake input — deploying means:
add this repo as an input there, enable `services.<name>`, `just switch`.

Secret zero: the 1Password service-account token lives in the login Keychain
(`just store-op-token`, one-time per machine). run.sh reads it with
`security find-generic-password`. No plaintext secrets on disk, ever.

## Stack

uv · pydantic-settings (env config) · httpx · structlog · pytest · ruff.
Logs land in `data/launchd.log` / `data/launchd.err.log` (gitignored).
Instantiate `Settings()` inside `main()`, never at import time.

## Commands

| Command | Purpose |
|---|---|
| `just run` | Run the job locally with secrets injected |
| `just test` | pytest |
| `just store-op-token` | One-time Keychain setup per machine |

## TDD

Write the test in `tests/` first, then the `src/job/` code.

## New-project checklist (delete this section after setup)

1. Replace every `CHANGEME` (pyproject, flake description, darwin.nix service
   name/label/keychainService, justfile token name).
2. Fill `.env.tpl`; add matching fields to `src/job/config.py`.
3. `uv sync && just test`.
4. On the mini: clone repo, `just store-op-token`, add flake input to
   nix-config, enable the service, `just switch`.
5. Manual steps that can't be codified (Full Disk Access, first interactive
   login for scrapers) go in this repo's README.
