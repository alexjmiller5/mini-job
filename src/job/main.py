"""The job. Plain Python — launchd runs this via scripts/run.sh."""

import structlog

log = structlog.get_logger()


def run() -> dict:
    log.info("job started")
    # CHANGEME: real work goes here
    return {"ok": True}


if __name__ == "__main__":
    run()
