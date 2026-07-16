# mini-job (template)

Template for scheduled jobs on the mac mini — the tier for work needing a
residential IP, Apple data, or local hardware. Pattern extracted from
`notion-finance-sync` and `screentime-backup` (both live on the mini).

## Layout

```
src/job/          the job (plain Python)
nix/darwin.nix    nix-darwin module: builds the app (uv2nix), wraps it in a
                  signed .app, installs the launchd user agent
flake.nix         packages.default (uv2nix venv) + darwinModules.default
.env.tpl          secrets manifest (1Password op:// refs, committed)
scripts/          store_op_token.sh (Keychain fallback) + one-offs
justfile          run / test / check / fmt / logs / store-op-token
```

## How it deploys

The mini never checks out this repo. nix-config adds it as a flake input,
enables `services.<name>`, and `darwin-rebuild switch` builds the venv from
`uv.lock`, installs a signed `.app` at a stable path, and creates the launchd
agent. Code changes deploy by push here + `nix flake update <input>` + switch
there. State and logs live in `~/Library/Application Support/<name>/`
(exported to the job as `JOB_STATE_DIR`).

**Secret zero:** the 1Password service-account token is age-encrypted in
nix-config (agenix) and decrypted at activation — set `tokenFile =
config.age.secrets.<name>-op-token.path`. Fallback: login Keychain via
`just store-op-token`. The runner exports it and `op run`s the job with
`.env.tpl` injected. No plaintext secrets on disk, ever.

## Manual one-time steps per machine (cannot be codified)

- **Full Disk Access** (only if the job reads TCC-protected data — Messages,
  Screen Time…): System Settings → Privacy & Security → Full Disk Access →
  the installed `.app`. Activation keeps the app's signature stable, so this
  one grant survives every rebuild.
- **First interactive login** for scraper jobs (establishes device-trust
  browser profiles).

## Bootstrap

See the `new-project` skill, or the checklist in CLAUDE.md.
