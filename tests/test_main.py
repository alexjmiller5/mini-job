import json

import httpx
import pytest
from pydantic import ValidationError

from job.config import CredentialError, Settings, resolve_token
from job.hub import Hub, HubError
from job.main import pass_once, watch

SUB = "1521a54f-65ac-47d1-832d-1a4d5959dd66"
URL = "https://hub.example"


def settings(**overrides) -> Settings:
    values = {"service_url": URL, "subscription_id": SUB, "token": "fixture-token"}
    return Settings(**{**values, **overrides})


class FakeHub:
    """durable-pull-v1: the same batch is offered until it is acknowledged."""

    def __init__(self, batches=(), *, status=200, retry_after=None):
        self.batches = list(batches)
        self.status, self.retry_after = status, retry_after
        self.acks, self.auth = [], []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.auth.append(request.headers.get("authorization"))
        if self.status != 200:
            headers = {"Retry-After": str(self.retry_after)} if self.retry_after else {}
            return httpx.Response(self.status, json={"error": "x"}, headers=headers)
        if request.url.path == f"/v1/subscriptions/{SUB}/events":
            assert request.url.params["wait"] in ("0", "30")
            if not self.batches:
                return httpx.Response(200, json=empty())
            return httpx.Response(200, json=self.batches[0])
        if request.url.path == f"/v1/subscriptions/{SUB}/ack":
            delivery = json.loads(request.content)["delivery_id"]
            assert self.batches and delivery == self.batches[0]["delivery_id"]
            self.acks.append(self.batches.pop(0))
            return httpx.Response(200, json={"acked_seq": self.acks[-1]["through_seq"]})
        return httpx.Response(404)


def empty():
    return {"subscription_id": SUB, "delivery_id": None, "through_seq": "0", "events": []}


def batch(delivery="d1", rows=("r1",)):
    events = [
        {"id": f"e-{r}", "seq": str(i + 1), "operation": "update", "source": {"row_id": r}}
        for i, r in enumerate(rows)
    ]
    return {"subscription_id": SUB, "delivery_id": delivery, "through_seq": "1", "events": events}


def hub_for(fake, token="fixture-token") -> Hub:
    return Hub(URL, lambda: token, httpx.Client(transport=httpx.MockTransport(fake)))


def test_env_literal_token_wins_over_command():
    assert resolve_token(settings(token_command=["false"])) == "fixture-token"


def test_token_command_output_is_the_credential():
    s = settings(token=None, token_command=["printf", "%s", "fixture with spaces"])
    assert resolve_token(s) == "fixture with spaces"


@pytest.mark.parametrize("command", [["false"], ["true"], ["/nonexistent/command"]])
def test_failed_or_empty_token_command_is_a_credential_error(command):
    with pytest.raises(CredentialError):
        resolve_token(settings(token=None, token_command=command))


def test_missing_credential_is_a_credential_error():
    with pytest.raises(CredentialError):
        resolve_token(settings(token=None))


@pytest.mark.parametrize(
    "url", ["http://hub.example", "https://user:pw@hub.example", "https://hub.example/v1"]
)
def test_service_url_must_be_an_https_origin(url):
    with pytest.raises(ValidationError):
        settings(service_url=url)


def test_state_dir_follows_xdg_state_home(monkeypatch, tmp_path):
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path))
    assert settings().state_dir.parent == tmp_path


def test_events_are_handled_then_acknowledged():
    fake, seen = FakeHub([batch()]), []
    assert pass_once(hub_for(fake), settings(), lambda events, _s: seen.extend(events)) is True
    assert [e["source"]["row_id"] for e in seen] == ["r1"]
    assert len(fake.acks) == 1 and fake.auth[0] == "Bearer fixture-token"


def test_empty_poll_acknowledges_nothing():
    fake = FakeHub()
    assert pass_once(hub_for(fake), settings(), lambda *_: pytest.fail("no events")) is False
    assert fake.acks == []


def test_failed_handler_leaves_the_batch_for_redelivery():
    fake = FakeHub([batch()])

    def boom(events, _settings):
        raise RuntimeError("handler failed")

    with pytest.raises(RuntimeError):
        pass_once(hub_for(fake), settings(), boom)
    assert fake.acks == [] and len(fake.batches) == 1


def test_rejected_credential_is_a_credential_error_and_rereads_the_token():
    reads = []
    fake = FakeHub(status=401)
    hub = Hub(
        URL, lambda: reads.append(1) or "t", httpx.Client(transport=httpx.MockTransport(fake))
    )
    for _ in range(2):
        with pytest.raises(HubError) as error:
            hub.poll(SUB, 0)
        assert error.value.credential
    assert len(reads) == 2


def test_watch_honors_retry_after_and_keeps_running():
    sleeps = []
    fake = FakeHub(status=429, retry_after=120)
    watch(hub_for(fake), settings(), lambda *_: None, sleep=sleeps.append, iterations=2)
    assert sleeps == [120, 120]


def test_watch_waits_an_hour_on_a_rejected_credential():
    sleeps = []
    watch(
        hub_for(FakeHub(status=403)), settings(), lambda *_: None, sleep=sleeps.append, iterations=1
    )
    assert sleeps == [3600]


def test_watch_survives_handler_errors_and_redelivers():
    fake, calls, sleeps = FakeHub([batch()]), [], []

    def flaky(events, _settings):
        calls.append(1)
        if len(calls) == 1:
            raise RuntimeError("transient")

    watch(hub_for(fake), settings(), flaky, sleep=sleeps.append, iterations=2)
    assert len(calls) == 2 and len(fake.acks) == 1 and sleeps == [30]
