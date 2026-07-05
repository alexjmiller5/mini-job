# mini-job (template)

Template for scheduled jobs on the mac mini — the tier for work needing a
residential IP, Apple data, or local hardware. Pattern extracted from
`notion-finance-sync`.

## Layout

```
src/job/          the job (plain Python)
scripts/run.sh    launchd entrypoint (Keychain op token → op run → uv run)
nix/darwin.nix    nix-darwin module (launchd user agent, schedule options)
flake.nix         exposes darwinModules.default for nix-config to consume
.env.tpl          secrets manifest (1Password op:// refs, committed)
justfile          run / test / store-op-token
```

## Bootstrap

See the `new-project` skill, or the checklist in CLAUDE.md.

Manual one-time steps per machine (cannot be codified — keep documented here):
- `just store-op-token` — 1Password SA token → login Keychain
- Grant Full Disk Access if the job reads protected data (TCC is SIP-protected)
