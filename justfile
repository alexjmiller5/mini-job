set shell := ["bash", "-cu"]
export PYTHONPATH := "src"

default:
    @just --list

# Execute the job locally with secrets injected
run:
    op run --env-file=.env.tpl -- uv run python -m job.main

alias dev := run

test:
    uv run pytest

# All static analysis (read-only, CI-safe)
check:
    uv run ruff check . && uv run ruff format --check .

fmt:
    uv run ruff format . && uv run ruff check --fix .

# Tail the launchd logs (on the mini)
logs:
    tail -F "$HOME/Library/Application Support/CHANGEME/launchd.log" "$HOME/Library/Application Support/CHANGEME/launchd.err.log"

# Fallback (preferred: agenix tokenFile in nix-config): put the 1P SA token in the login Keychain
store-op-token:
    ./scripts/store_op_token.sh CHANGEME-op-token

# --- project-specific recipes below (one-offs live in scripts/, run directly) ---
