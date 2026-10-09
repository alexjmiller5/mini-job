"""Outbound client for a durable-pull-v1 subscription (the Soma hub's outbox).

GET  /v1/subscriptions/<id>/events?wait=N  holds up to 30 s; the same batch is
                                           offered until it is acknowledged
POST /v1/subscriptions/<id>/ack            {delivery_id} advances the cursor
"""

from collections.abc import Callable

import httpx


class HubError(Exception):
    def __init__(self, message: str, *, retry_after: float | None = None, credential=False):
        super().__init__(message)
        self.retry_after, self.credential = retry_after, credential


class Hub:
    def __init__(self, url: str, token: Callable[[], str], http: httpx.Client | None = None):
        self.url, self._read_token, self._token = url, token, None
        self.http = http or httpx.Client(timeout=httpx.Timeout(60, connect=10))

    def request(self, method: str, path: str, **kwargs) -> httpx.Response:
        # The credential is read once and held in memory; a rejection rereads it
        # next time, so rotating the stored token needs no restart.
        self._token = self._token or self._read_token()
        headers = {"Authorization": f"Bearer {self._token}", **kwargs.pop("headers", {})}
        try:
            response = self.http.request(method, self.url + path, headers=headers, **kwargs)
        except httpx.HTTPError as error:
            raise HubError(f"{method} {path}: {type(error).__name__}") from None
        if response.status_code in (401, 403):
            self._token = None
            raise HubError(f"{method} {path}: {response.status_code}", credential=True)
        if response.status_code == 429 or response.status_code >= 500:
            retry = response.headers.get("Retry-After", "")
            raise HubError(
                f"{method} {path}: {response.status_code}",
                retry_after=float(retry) if retry.isdigit() else None,
            )
        return response

    def poll(self, subscription: str, wait: int) -> dict:
        response = self.request(
            "GET", f"/v1/subscriptions/{subscription}/events", params={"wait": wait}
        )
        response.raise_for_status()
        body = response.json()
        if body.get("subscription_id") != subscription or not isinstance(body.get("events"), list):
            raise HubError("invalid delivery")
        return body

    def ack(self, subscription: str, delivery_id: str) -> None:
        response = self.request(
            "POST", f"/v1/subscriptions/{subscription}/ack", json={"delivery_id": delivery_id}
        )
        if response.status_code == 409:
            raise HubError("delivery_conflict")  # already superseded; the next poll re-offers
        response.raise_for_status()
