# Mini Job template

A Python job for the mac mini that holds an outbound long poll open against its
service (the Soma hub's `durable-pull-v1` subscription API) and acts on each
delivered batch. The service never connects to the mini.

- `nix build` builds the locked application; `darwinModules.default` installs it
  as a kept-alive launchd user agent (`job watch`), optionally inside a signed
  .app for Full Disk Access.
- `just dev` runs the watcher with your environment, `just run` one pass,
  `just test` / `just check` / `just fmt`, `just logs` tails the installed log.
- Configuration is `JOB_*` environment variables: `JOB_SERVICE_URL`,
  `JOB_SUBSCRIPTION_ID`, `JOB_STATE_DIR` (default `~/.local/state/<slug>`), and the
  credential as `JOB_TOKEN` or `JOB_TOKEN_COMMAND` (JSON argv printing it).
- The job's credential is its own, minted by the service. On macOS store it in
  the login Keychain from the desktop session (ssh sessions cannot write it) and
  point `credentialCommand` at `security find-generic-password ... -w`.

See [AGENTS.md](AGENTS.md) for the architecture and the new-project checklist.
