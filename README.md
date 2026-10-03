# Mini Job template

Python jobs that need residential networking, Apple data or local hardware.
The application is a Nix package, with an optional nix-darwin launchd module and
signed app wrapper for TCC-protected data.

Use `just run`, `just test`, `just check`, `just fmt` and `just logs`.
`nix build` builds the locked application. `nix-build tests/runner.nix --no-out-link`
tests the credential seam without provider access.

State and logs belong in the configured application-support directory, exported
as `JOB_STATE_DIR`. The installed job runs packaged code, never a checkout.

Consumer credentials come from supported native enrollment or caller-prepared
environment variables. The optional `credentialCommands` module setting maps each
variable name to a command returning its credential. Failed commands prevent the
job from starting. Keep credential values out of Nix and source control. No
provider account or machine-vault token is required by the template.

The signed wrapper is for jobs needing Full Disk Access. Document the manual TCC
grant and any native sign-in in the generated project's README. A networking-only
job can instead use a plain packaged home-manager service.

See the checklist in [AGENTS.md](AGENTS.md) before generating a project.
