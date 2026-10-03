set shell := ["bash", "-cu"]
export PYTHONPATH := "src"
export UV_PROJECT_ENVIRONMENT := env_var("HOME") + "/.cache/uv-venvs/mini-job-template"

default:
    @just --list

# Execute the job with the caller's environment
run:
    uv run python -m job.main

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

# --- project-specific recipes below (one-offs live in scripts/, run directly) ---
