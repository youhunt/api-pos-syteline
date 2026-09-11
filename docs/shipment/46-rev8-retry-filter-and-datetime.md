# 46 — Shipment Scheduler REV8: Retry Filter + Date/Time

Date: 2026-09-11
Scope: Shipment outbound SyteLine -> POS API only

## Goal

REV8 keeps the persistent retry state visible for audit, but prevents completed (`S`) rows from cluttering the operator's default working view.

It also changes operational timestamp components to display both date and time, because date-only output makes 1-minute retry behavior impossible to inspect reliably.

## Retry row lifecycle

`ue_SMK069_shipment_retry_mst` remains the persistent current-state table per DN:

```text
P = Pending / Retry
S = Success
X = Exhausted
```

A successful DN is **not deleted** from the retry table by REV8. It remains as history/current terminal state and can be shown with the SUCCESS or ALL filters.

API attempt history remains separately available through `ue_SMK069ShipmentApiLogs`.

No housekeeping delete policy is introduced in this revision.

## Default operator view

The RETRY / EXECUTION STATUS tab now defaults to:

```text
OPEN
```

which is implemented as:

```text
RetryState <> 'S'
```

So normal operation shows only rows still requiring attention while successful rows remain retrievable.

## Filter bar

REV8 adds these controls above the retry grid:

```text
OPEN
SUCCESS
EXHAUSTED
ALL
DN: <partial DN text>  APPLY  CLEAR DN
VIEW: <active filter>
```

The filter is applied only to secondary collection `object6` / `ue_SMK069ShipmentRetries`.

The implementation uses the standard Mongoose `IWSIDOCollection.Filter` property followed by `Refresh()`; it does not add SQL objects or alter retry data.

DN filtering is combined with the selected status filter, for example:

```text
OPEN + DN P963
SUCCESS + DN P96350
ALL + DN P963
```

## Date/time display

These components are overridden to use `DATETIME()` formatting:

```text
RetryLastAttempt
RetryNextAttempt
ApiHistDate
LastRunDateEdit
NextRunDateEdit
```

The most important result is that retry rows can now show values similar to:

```text
09/11/2026 14:31:07
09/11/2026 14:32:07
```

instead of showing the same date for both Last Attempt and Next Retry.

Actual presentation still follows the tenant/web-client localization format, but both date and time must be present.

## Runtime safety

REV8 does not change:

- retry policy (`MaxAttempts=1440`, fixed 1-minute backoff);
- Shipment selection logic;
- API endpoint;
- success contract;
- `api_post` behavior;
- START / STOP / RUN ONCE orchestration;
- TaskMan task name;
- database schema.

## Artifact generator

Tool:

```text
tools/shipment/upgrade_scheduler_rev8_filters_datetime.py
```

Usage:

```text
python tools/shipment/upgrade_scheduler_rev8_filters_datetime.py input.xml output.xml
```

The generated artifact replaces live credentials with:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Replace those locally before importing to the tenant. Never commit credentials.

## Acceptance test

1. Import the REV8 form.
2. Open the Retry tab.
3. Confirm default `VIEW = OPEN`.
4. Successful rows (`S`) should be hidden in OPEN.
5. Click `SUCCESS`; the successful DNs must appear.
6. Click `ALL`; all persistent retry rows must appear.
7. Enter a partial DN such as `P963` and click APPLY; rows must be narrowed by DN while keeping the selected status mode.
8. Click CLEAR DN; only the DN filter must be removed.
9. Confirm Last Attempt and Next Retry include time as well as date.
10. Confirm the API History response date also includes time.

## Design rationale

The retry table is operational state, not a disposable queue. Deleting success rows would remove useful evidence and complicate troubleshooting. Filtering gives the operator a clean working view without losing auditability.
