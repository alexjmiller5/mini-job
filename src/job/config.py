"""Settings from the caller environment (JOB_*), resolved when the job starts.

The credential seam: JOB_TOKEN (a literal, for tests and env-injecting callers)
or JOB_TOKEN_COMMAND (a JSON argv whose stdout is the token, e.g. a secure-storage
lookup). The job never knows which secret store its caller uses.
"""

import os
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

APP = "mini-job"  # CHANGEME: the job's slug (state dir name)


class CredentialError(Exception):
    pass


def default_state_dir() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / APP


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="JOB_", hide_input_in_errors=True)  # CHANGEME

    service_url: str
    subscription_id: str
    token: SecretStr | None = None
    token_command: list[str] | None = None
    state_dir: Path = Field(default_factory=default_state_dir)
    hold_seconds: int = Field(default=30, ge=0, le=30)

    @field_validator("service_url")
    @classmethod
    def https_origin(cls, value: str) -> str:
        url = urlsplit(value)
        if (
            url.scheme != "https"
            or not url.hostname
            or url.username is not None
            or url.password is not None
            or url.path not in ("", "/")
            or url.query
            or url.fragment
        ):
            raise ValueError("service_url must be an HTTPS origin without credentials")
        return value.rstrip("/")


def resolve_token(settings: Settings) -> str:
    if settings.token:
        return settings.token.get_secret_value()
    if not settings.token_command:
        raise CredentialError("no credential: set JOB_TOKEN or JOB_TOKEN_COMMAND")
    try:
        result = subprocess.run(
            settings.token_command, capture_output=True, text=True, timeout=30, check=False
        )
    except (OSError, subprocess.TimeoutExpired):
        raise CredentialError("token command could not run") from None
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        raise CredentialError("token command failed")
    return token
