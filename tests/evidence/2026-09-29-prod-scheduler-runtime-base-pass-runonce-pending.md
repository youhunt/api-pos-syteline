# PROD scheduler runtime — base objects PASS, Run Once patch pending

Date: 2026-09-29
Environment: PROD

Verification:

```text
GetConfigSp          PASS
GetPendingSp         PASS
RecordAttemptSp      PASS
DashboardSp          PASS
SaveScheduleSp       PASS
SetSchedulerSp       PASS
RunNowSp             PASS
ResetRetrySp         PASS
ClaimScheduleSp      PASS
CompleteScheduleSp   PASS
DashboardView        PASS
QueueView            PASS
RunOnceBypass        FAIL
ManualClaimBypass    FAIL
```

Interpretation:

- scheduler procedures and read views are installed in PROD;
- only Patch 19 / file 070 (manual RUN ONCE bypass while recurring scheduler is OFF) is not yet present;
- do not run 080, RUN ONCE, or START scheduler until 070 is applied and verified.
