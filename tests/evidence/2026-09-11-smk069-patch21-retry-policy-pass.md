# SMK069 Patch 21 — Retry Policy Verification

Date: 2026-09-11
Scope: Shipment Outbound SyteLine -> POS API

Tenant verification result after applying Patch 21:

```text
MaxAttempts         1440
BackoffBaseMinutes  1
BackoffCapMinutes   1
ScheduleName        Every 1 Minute
IntervalMinutes     1
MaxShipments        1
IsEnabled           1
```

Interpretation:

- Fixed retry interval is now 1 minute because Base=1 and Cap=1.
- Max retry attempts per DN is 1440.
- Business schedule interval is 1 minute and the schedule is enabled.
- MaxShipments remains 1, so each scheduler execution can process at most one DN.
- This does NOT by itself prove TaskMan heartbeat frequency is 1 minute; recurring TaskMan heartbeat must be checked separately.

No retry rows were reset by this verification.
No HTTP call was made by this verification.
