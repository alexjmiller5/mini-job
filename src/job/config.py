"""Settings from the caller environment, resolved when the job starts."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # CHANGEME: add generic application settings. Keep provider-specific
    # credential lookup in the caller's environment preparation.
    pass
