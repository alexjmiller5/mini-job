set shell := ["bash", "-cu"]
export PYTHONPATH := "src"

default:
    @just --list

# Run the job locally with secrets injected
run:
    op run --env-file=.env.tpl -- uv run python -m job.main

test:
    uv run pytest

lint:
    uv run ruff check . && uv run ruff format --check .

fmt:
    uv run ruff format . && uv run ruff check --fix .

# One-time per machine: put the 1Password SA token in the login Keychain
store-op-token:
    ./scripts/store_op_token.sh CHANGEME-op-token
