set shell := ["bash", "-cu"]
export UV_PROJECT_ENVIRONMENT := env_var("HOME") + "/.cache/uv-venvs/mini-job-template"

default:
    @just --list

# The long-poll daemon with the caller's environment (JOB_* variables)
dev:
    uv run job watch

# One poll pass, no hold
run:
    uv run job once

test:
    uv run pytest

# All static analysis (read-only, CI-safe)
check:
    uv run ruff check . && uv run ruff format --check . && nix flake check

fmt:
    uv run ruff format . && uv run ruff check --fix .

# Tail the installed agent's log (on the mini)
logs:
    tail -F "${XDG_STATE_HOME:-$HOME/.local/state}/mini-job/job.log"

# --- project-specific recipes below (one-offs live in scripts/, run directly) ---
