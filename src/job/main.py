"""The job: an outbound long-polling consumer, run by launchd (`job watch`).

The service never reaches into this machine. The job holds a long poll open
against its subscription, acts on each delivered batch, then acknowledges it.
"""

import sys
import time
from collections.abc import Callable

import structlog

from .config import Settings, resolve_token
from .hub import Hub, HubError

log = structlog.get_logger()
Handler = Callable[[list[dict], Settings], None]


def handle(events: list[dict], settings: Settings) -> None:
    """CHANGEME: act on one delivered batch.

    A batch is redelivered until it is acknowledged, so this must be idempotent:
    re-read the current row state rather than trusting an event's old/new values.
    """
    for event in events:
        log.info("event", operation=event.get("operation"), row=event["source"].get("row_id"))


def pass_once(hub: Hub, settings: Settings, handler: Handler = handle, wait=None) -> bool:
    batch = hub.poll(settings.subscription_id, settings.hold_seconds if wait is None else wait)
    if not batch["events"]:
        return False
    handler(batch["events"], settings)
    hub.ack(settings.subscription_id, batch["delivery_id"])
    return True


def watch(
    hub: Hub, settings: Settings, handler: Handler = handle, *, sleep=time.sleep, iterations=None
):
    backoff = 1.0
    while iterations is None or iterations > 0:
        iterations = None if iterations is None else iterations - 1
        try:
            pass_once(hub, settings, handler)
            backoff = 1.0
        except HubError as error:
            # Never a hot loop: a rejected credential waits an hour, a capped or
            # unavailable service waits its Retry-After or a growing backoff.
            delay = 3600 if error.credential else error.retry_after or backoff
            backoff = min(60.0, backoff * 2)
            log.warning("hub", error=str(error), retry_in=min(3600, delay))
            sleep(min(3600, delay))
        except Exception as error:  # noqa: BLE001 - the daemon outlives one bad batch
            log.error("batch failed", error=f"{type(error).__name__}: {error}")
            sleep(30)


def cli(argv: list[str] | None = None) -> int:
    command = (argv if argv is not None else sys.argv[1:] or ["--help"])[0]
    if command not in ("watch", "once"):
        print("usage: job watch | once", file=sys.stderr)  # CHANGEME: the executable name
        return 0 if command in ("-h", "--help") else 2
    settings = Settings()
    settings.state_dir.mkdir(parents=True, exist_ok=True)
    hub = Hub(settings.service_url, lambda: resolve_token(settings))
    if command == "once":
        pass_once(hub, settings, wait=0)
    else:
        log.info("watching", service=settings.service_url, subscription=settings.subscription_id)
        watch(hub, settings)
    return 0


if __name__ == "__main__":
    sys.exit(cli())
