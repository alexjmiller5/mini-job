# Mini Job template

Scheduled Python jobs for residential networking, Apple data or local hardware.
Cloud-safe jobs belong in the cloud-service template.

## Runtime and ownership

The Nix package contains the locked application and dependencies. The app's module
owns launchd setup, installed paths and runtime behavior. Deploy by pushing the
project, updating its input in the consumer's machine configuration, then rebuilding
and verifying the job. Never run a daemon from a working tree.

Consumer credentials are independently enrolled and revocable. Runtime accepts
caller-prepared environment variables; the module's optional credentialCommands
maps variable names to commands that return their values. A failed command stops
the job. There is no required provider CLI, service-account token or machine-vault
fallback. Never put credential values in Nix settings or source control.

The signed app wrapper supports jobs requiring TCC-protected Apple data. Its stable
identity retains an explicit Full Disk Access grant across updates. Document that
grant and any native account enrollment in the consuming project's README. A job
that only needs networking can use a plain packaged home-manager service.

State and logs belong in the configured standard application-support directory,
exported as JOB_STATE_DIR. No current-directory-relative state.

## Development

uv, pydantic-settings, httpx, structlog, pytest and Ruff. Construct settings inside
main, never on import. Use just run, test, check, fmt and logs. Write behavior tests
before implementation. The credential runner has a Nix integration check in
tests/runner.nix; it executes credential-free, successful and failed-command cases.

## New-project checklist

1. Choose the project's Title and replace CHANGEME names throughout the template.
2. Add generic application settings; keep personal configuration outside the repo.
3. Confirm repository visibility and analytics preference with the user.
4. Fill .env.tpl only for operator/server/CI secrets the project actually owns.
   Native consumer enrollment does not require a provider service-account bootstrap.
5. Run just test, just check and nix build. Use a project-specific external uv
   environment path in the justfile so iCloud checkouts contain no environment.
6. Add the package/module to the consumer's declarative machine configuration when
   deployment is authorized; rebuild and verify it. Document user-only enrollment
   and TCC grants. Remove this checklist from the generated project.
