# Shipment retry policy — 1 minute / 1440 attempts

Date: 2026-09-11

## Confirmed POS requirement

POS confirmed:

- retry interval: 1 minute;
- maximum attempts: 1440 per DN;
- applies to all Shipment API failure responses.

## Runtime semantics

One scheduler execution can send 0..N DNs, where N is limited by `Max / Run` (`MaxShipments`). Each DN is posted independently to the Shipment endpoint and has its own retry state.

`MaxAttempts=1440` is per DN, not per scheduler run.

Patch 21 sets:

- `MaxAttempts = 1440`;
- `BackoffBaseMinutes = 1`;
- `BackoffCapMinutes = 1`;
- business schedule `IntervalMinutes = 1`.

Base and cap are both 1 so the existing backoff formula becomes a fixed one-minute eligibility delay after every failed Shipment attempt.

## Important distinction: Max / Run

`Max / Run` remains an independent operational limit. If `Max / Run = 1` and four DNs are due, only one DN is sent in that scheduler execution; the other three wait for later scheduler executions.

Therefore "retry eligible every 1 minute" does not guarantee every failed DN is actually sent every minute unless `Max / Run` is large enough to cover the due backlog.

For UAT and moderate backlog, `Max / Run = 50` matches the current default batch capacity, but the final value should respect POS throughput/rate-limit expectations.

## TaskMan heartbeat

The one-form scheduler previously created its recurring TaskMan heartbeat every 5 minutes. A one-minute business schedule cannot execute every minute if TaskMan wakes only every 5 minutes.

The form/TaskMan heartbeat must therefore also be 1 minute. Existing recurring TaskMan rows must be stopped and recreated after the form heartbeat setting is changed.

## Login failure

POS login is performed once before the DN loop. If login fails, no Shipment is posted and per-DN attempt counters are intentionally not incremented. This prevents one credential outage from consuming 1440 attempts for every pending DN.

## History

Reset Retry does not delete API history. Retry state is current-state data; API log rows remain the audit trail for earlier attempts.
