# CLAUDE.md

Scheduled job that runs on the mac mini — for work that needs a residential
IP (scraping), Apple data (Messages, Screen Time, Contacts), or local
hardware. Cloud-safe jobs do NOT belong here (see the `infra` skill).

## How it runs

Fully packaged deploy (`nix/darwin.nix`): `darwin-rebuild switch` in
nix-config builds the app from `uv.lock` (uv2nix venv in the store), wraps it
in a **signed .app** at a stable path, and installs a launchd user agent that
runs it. The agent's runner resolves the 1Password SA token (agenix
`tokenFile` preferred, login Keychain fallback) and execs
`op run --env-file=.env.tpl -- python -m job.main`.

The module is consumed by the mac mini's nix-config
(github.com/alexjmiller5/nix-config) as a flake input — deploying means:
add this repo as an input there, enable `services.<name>`, `just switch`.

**Code changes deploy by commit + push** (here, then `nix flake update
<input>` + `just switch` in nix-config) — the mini only ever runs pushed
commits, never a local working tree. Verify the job actually works after a
rebuild (`just logs` on the mini); never assume it did.

**Why a .app:** TCC keys Full Disk Access on code identity. Activation keeps
a stable self-signed cert and re-signs the .app every rebuild, so one manual
FDA grant survives updates. The bundle executable must be a real Mach-O stub
(a shebang script fails TCC's designated-requirement check on macOS 26).

Secret zero: the 1Password SA token lives age-encrypted in nix-config
(agenix → `tokenFile`); Keychain via `just store-op-token` is the fallback.
No plaintext secrets on disk, ever.

State/logs: `~/Library/Application Support/<name>/` (env `JOB_STATE_DIR`).
Never write CWD-relative — launchd's default CWD is `/`; the agent sets
`WorkingDirectory` to the state dir as a backstop.

## Stack

uv · pydantic-settings (env config) · httpx · structlog · pytest · ruff.
Instantiate `Settings()` inside `main()`, never at import time.

## Commands

Standard verb set (see global CLAUDE.md) — the justfile is the interface,
not a script catalog; one-offs go in `scripts/` and run directly.

| Command | Purpose |
|---|---|
| `just run` (alias `dev`) | Execute the job locally with secrets injected |
| `just test` / `just check` / `just fmt` | pytest / ruff read-only / ruff fix |
| `just logs` | Tail launchd logs (on the mini) |
| `just store-op-token` | Keychain token fallback (prefer agenix in nix-config) |

## TDD

Write the test in `tests/` first, then the `src/job/` code.

## New-project checklist (delete this section after setup)

1. Replace every `CHANGEME` (pyproject, flake, darwin.nix service
   name/label/stateDir/keychainService/bundleId/appName/appInstallPath/
   signingIdentity, justfile logs path + token name).
2. Fill `.env.tpl`; add matching fields to `src/job/config.py`.
3. `uv sync && just test`; `nix flake check` (or at least
   `nix build .#packages.aarch64-darwin.default`) to prove the package builds.
4. In nix-config: add the flake input, enable `services.<name>`, add the
   agenix `op-token` secret + `tokenFile`, `just switch`.
5. Manual steps that can't be codified go in this repo's README: FDA grant to
   the installed .app (only if the job reads TCC-protected data), first
   interactive login for scrapers.
6. Scraper needing real Chrome? Copy `installChrome` + the Xcode CLT /
   Rosetta 2 preflights from notion-finance-sync's `nix/darwin.nix`.

## Not Alex? Owner-specific assumptions

The nix-darwin module is generic (all machine-specific values are options or
CHANGEME-marked). Alex deploys it as a flake input to his private
github.com/alexjmiller5/nix-config; you'd import the module into your own
nix-darwin config. Launchd labels default to `com.alexmiller.*` — rename per
the CHANGEME comments. Secrets assume a 1Password service account
(scripts/store_op_token.sh) — swap for your own secret store if needed.
