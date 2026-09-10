# Shipment RUN ONCE independent of recurring scheduler

Date: 2026-09-10

## User-facing contract

`RUN ONCE` is a manual one-time execution and must not require the recurring scheduler to be active.

Desired behavior:

```text
START SCHEDULER
  -> recurring / automatic execution

RUN ONCE
  -> allowed while Master Control = OFF
  -> allowed while Business Schedule = DISABLED
  -> submits exactly one READY TaskMan invocation
  -> does not create a recurring heartbeat
  -> does not permanently enable Master/Schedule
```

## Why the old form showed "Master Scheduler still OFF"

The popup was raised by `dbo.SMK069RequestShipmentRunNowSp`, not by the button itself. The runtime procedure still contained the original recurring-scheduler guard:

```text
Master Shipment Scheduler masih OFF. Aktifkan master switch lebih dulu.
```

A second gate also exists in `dbo.SMK069ClaimDueShipmentScheduleSp`: when the master is OFF, the claim procedure returned no work. Therefore removing only the popup/form validation would not make RUN ONCE work.

## Patch 19

Patch:

```text
database/patches/shipment/2026-09-10-smk069-19-run-once-bypass-scheduler-switches.sql
```

Patch 19 uses guarded `OBJECT_DEFINITION` surgery against the installed tenant procedures.

It changes the runtime contract so:

```text
Master ON:
  RunRequested=1 OR normal due IsEnabled schedule may be claimed.

Master OFF:
  ONLY RunRequested=1 may be claimed.
```

A `RunRequested=1` manual row may be claimed even if `IsEnabled=0`.

Therefore Master OFF cannot accidentally release automatic due schedules. Only an explicit RUN ONCE request can pass.

Patch 19 does NOT:

- enable `SchedulerEnabled`;
- enable `IsEnabled`;
- submit TaskMan;
- make an HTTP call;
- reset Shipment retries;
- change endpoint, credentials, Build, Prepare, or Complete.

## Form behavior

The form still performs the explicit one-time TaskMan submission with native Mongoose `ResponseType 19`:

```text
TASKNAME(SMK069ShipmentScheduler)
TASKSTATUS(READY)
```

The REV4 form labels this action as:

```text
RUN ONCE (MANUAL)
```

The actual TaskMan collection remains:

```text
ActiveBGTasks
FILTERPERM(TaskName = 'SMK069ShipmentScheduler')
```

Runtime text differentiates a manual run from the recurring scheduler:

```text
RUN ONCE - QUEUED
RUNNING ONCE
```

When the one-time task completes and Master/Schedule were OFF before the run, they remain OFF.

## Apply / verify

Apply Patch 19 through Infor Apply Database as one batch. No `GO`.

Expected output:

```text
OK - Patch 19 applied.
RUN ONCE sekarang boleh saat Master Scheduler OFF.
RUN ONCE sekarang boleh saat Business Schedule DISABLED.
Master OFF hanya boleh claim row dengan RunRequested=1; automatic due schedule tetap diblok.
Patch ini TIDAK enable scheduler dan TIDAK melakukan HTTP/TaskMan submit.
```

Verification through Query Select, without trailing semicolon:

```sql
SELECT
    CASE WHEN CHARINDEX(
        N'SMK069-RUNONCE-BYPASS-MASTER-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp', N'P')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS RequestBypass,
    CASE WHEN CHARINDEX(
        N'SMK069-RUNONCE-CLAIM-MANUAL-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp', N'P')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS ClaimManual,
    CASE WHEN CHARINDEX(
        N'AND (ISNULL(@MasterEnabled, 0) = 1 OR RunRequested = 1)',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp', N'P')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS AutoGateProtected
```

Target:

```text
RequestBypass  ClaimManual  AutoGateProtected
PASS           PASS         PASS
```

## Controlled UAT

For the current UAT keep `Max / Run = 1`.

With Master OFF and Business Schedule DISABLED:

1. press `RUN ONCE (MANUAL)` once;
2. the form should briefly see the TaskMan row as `READY/RUNNING`;
3. verify only the first eligible Shipment candidate was attempted;
4. after completion, Master/Schedule remain OFF;
5. review HTTP response, API log, retry state, and Shipment `Api_post` before any second run.
