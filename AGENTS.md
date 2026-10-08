# Mini Job template

Python jobs that must run on the mac mini: residential networking, Apple data or
local hardware. Cloud-safe work belongs in the modal-service template.

## Architecture: an outbound long-polling client

The service never reaches into the mini: no inbound port, tunnel, Funnel,
webhook, or timer polling a table. The mini runs ONE long-lived launchd user
agent (`job watch`) that holds an outbound long poll open, so it reacts within
about a second and costs nothing while idle. screentime-dashboard's ingest
watcher is the original instance; Page Archiver and Media Center's YouTube
offline job use the shared Life Data form below.

- **Protocol: `durable-pull-v1`**, the Life Data hub's subscription outbox.
  `GET /v1/subscriptions/<id>/events?wait=30` holds up to 30 s;
  `POST /v1/subscriptions/<id>/ack {delivery_id}` advances the cursor. The hub
  records the selected columns' changes in the same transaction as the row
  write and re-offers the identical batch until it is ACKed (at-least-once).
  An operator creates the subscription (admin `POST /v1/subscriptions`
  `{label, sources:[{table, columns}], start:"now"}`); its id is consumer config.
  A project whose service is its own Worker serves the same two endpoints
  instead of inventing a third protocol.
- **Events are wake-ups; the service's rows are the truth.** The handler is
  idempotent: re-read current state, act, write results back with
  revision-checked `/v1/rows/patch` (re-read the revision right before each
  patch; a 409 means someone edited the row). On startup, reconcile from
  current service state: an ACKed batch is gone, and local state can be lost.
- **Outcomes are visible where the user looks** (status/error columns on the
  row, or the service's job record), never only in a local log.
- **Bounded retries.** Persist attempt counts and next-attempt times in the
  state dir BEFORE each attempt so a crash never resets the budget; growing
  gaps (screentime: 4 attempts, 5/15/60 min), then a visible give-up that the
  user can reset by re-requesting.
- **Never a hot loop.** 401/403 waits an hour, then rereads the credential;
  429 honors Retry-After (at most an hour); other service failures back off
  1 to 60 s; a failed handler waits 30 s and the batch is redelivered. launchd
  `KeepAlive` + `ThrottleInterval = 30` covers crashes.

## Credentials

- The job holds its OWN credential, minted by the service for this caller:
  Life Data `life token create` with exact grants (`subscriptions:consume:<id>`
  plus `tables:read:<table>` for every subscription source, column-level
  `tables:read:`/`tables:patch:` grants for result columns,
  `files:read:`/`files:write:<prefix>/`), or app-native browser enrollment
  (`screentime-ingest login`). Never an operator, admin, CI or machine-vault
  token. Rotating or revoking it touches only this job.
- **Seam:** `JOB_TOKEN` (literal) or `JOB_TOKEN_COMMAND` (a JSON argv whose
  stdout is the token). The app knows no secret store. It reads the
  credential once, holds it in memory and rereads it after a rejection, so
  rotation needs no restart.
- On macOS the credential lives in the login Keychain:
  `credentialCommand = [ "/usr/bin/security" "find-generic-password" "-s" <service> "-a" <account> "-w" ]`.
  The agent runs in the `gui/<uid>` domain and can read it. Keychain WRITES
  fail from ssh-descended shells (`User interaction is not allowed`, -25308):
  enroll from the desktop session (a GUI terminal, or a one-shot launchd job
  bootstrapped into `gui/<uid>`), passing the secret to `security -i` on stdin,
  never argv or a file. The operator's recovery copy goes in the project vault.

## Runtime and ownership

- The flake ships the package (uv2nix venv from `uv.lock`) and a nix-darwin
  module, `services.<slug>`, with generic options: `user`, `serviceUrl`,
  `subscriptionId`, `credentialCommand`, `stateDir`, `environment`, `label`,
  `fullDiskAccess`. A consumer's machine config is `enable = true` plus those
  facts; nothing personal lives in the template or the generated repo.
- Tools the job shells out to (ffmpeg, yt-dlp, ...) come from nixpkgs through
  the package wrapper, never brew or the ambient PATH.
- Deploy = push, `nix flake update <input>` in the consumer's nix-config,
  rebuild, then verify `launchctl list <label>` and the log. Never run a daemon
  from a working tree. The mini's pin version-skews from the service, so a
  protocol change is half shipped until the mini rebuilds.
- State and logs live in `$XDG_STATE_HOME/<slug>` (default
  `~/.local/state/<slug>`), exported as `JOB_STATE_DIR`; launchd writes
  `job.log` there. No current-directory-relative state.
- `fullDiskAccess.enable` runs the job inside a signed .app with a stable
  identity so one manual Full Disk Access grant survives rebuilds (details in
  `nix/darwin.nix`). Document that grant in the generated README.

## Development

uv, pydantic-settings, httpx, structlog, pytest + pytest-mock, Ruff. Construct
`Settings` inside `cli()`, never at import. `just dev` (watch), `run` (one
pass), `test`, `check` (Ruff + `nix flake check`), `fmt`, `logs`. Write
behavior tests first against an in-process fake service (`httpx.MockTransport`):
redelivery until ACK, ACK only after success, credential reread, Retry-After.

## New-project checklist

1. Choose the Title (project-naming skill) and replace every CHANGEME: package
   and executable name, `JOB_` env prefix, `APP` state-dir name, `services.<slug>`,
   launchd label `com.<owner>.<slug>[.<job>]`.
2. Implement `handle()` and its reconciliation; add generic settings only.
3. Confirm repository visibility and analytics preference with the user.
4. Create the service side: catalog the columns the job reads/writes, the
   subscription, and the job's token with exact grants. Store the operator's
   copy in the project vault; enroll the job's copy in the mini's Keychain.
5. `just test`, `just check`, `nix build`. Keep the uv environment outside the
   (iCloud) checkout via `UV_PROJECT_ENVIRONMENT`.
6. Add the flake input and `services.<slug>` to the consumer's nix-config,
   rebuild, verify the agent and a real request end to end. Document any
   desktop-only enrollment or TCC grant in the README. Delete this checklist.
