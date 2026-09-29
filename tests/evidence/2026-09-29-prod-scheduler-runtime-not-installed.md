# PROD scheduler SQL runtime verification — no objects installed

Date: 2026-09-29
Environment: PROD

Verification result:

```text
GetConfigSp          FAIL
GetPendingSp         FAIL
RecordAttemptSp      FAIL
DashboardSp          FAIL
SaveScheduleSp       FAIL
SetSchedulerSp       FAIL
RunNowSp             FAIL
ResetRetrySp         FAIL
ClaimScheduleSp      FAIL
CompleteScheduleSp   FAIL
DashboardView        FAIL
QueueView            FAIL
RunOnceBypass        FAIL
ManualClaimBypass    FAIL
```

Interpretation:

All runtime object checks failed, including both views and the Run Once markers.
Treat this as the scheduler runtime files not being installed in PROD yet (or not
installed in the current database/site context). Do not proceed to config 080,
RUN ONCE, IDO runtime testing, or scheduler START.

Recovery sequence:

1. Apply only 020-get-shipment-config-sp.sql.
2. Verify dbo.SMK069GetShipmentConfigSp exists.
3. If PASS, continue one file at a time through the clean PROD run list.
4. If 020 Apply Database reports success but the object remains missing, stop
   and verify the Apply Database target/database context before applying more.
