# TRN / PROD Run Once baseline parity

Date: 2026-09-29

TRN and PROD both return FAIL for the Patch 19 / Run Once bypass marker checks.

This means those marker checks are not valid readiness gates for the current exact TRN baseline.

For exact TRN -> PROD migration:
- keep SMK069RequestShipmentRunNowSp as provided by the current TRN baseline;
- keep SMK069ClaimDueShipmentScheduleSp as provided by the current TRN baseline;
- do not require Patch 19 / Run Once bypass markers;
- scheduler SQL runtime readiness is based on the existence of 020-022, 032-038, 040-041.

Observed parity:
RunOnceBypass = FAIL
ManualClaimBypass = FAIL
RequestAllowsDisabledSchedule = FAIL
ManualVsRecurringGate = FAIL
