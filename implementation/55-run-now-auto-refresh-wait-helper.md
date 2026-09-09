# SMK069 Shipment Scheduler - Run Now Auto Refresh

Date: 2026-09-09

## Goal

Make the dashboard `Run Now` button refresh Schedule, Dashboard, and Shipment Queue automatically **after** the one-time TaskMan run has had a chance to finish.

The original direct Collection Refresh was too early because `Run Background Task` only submits the task; TaskMan then executes it asynchronously.

## Patch 12

Apply:

```text
database/patches/2026-09-09-smk069-12-wait-run-now-completion.sql
```

This creates:

```text
SMK069WaitShipmentRunCompletionSp
```

Parameters:

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | ScheduleCode | Input | String |
| 2 | PreviousLastRunDate | Input | DateTime |
| 3 | TimeoutSeconds | Input | Int32 |
| 4 | Completed | Output | Int32 |
| 5 | Infobar | Output | String |

The procedure polls `ue_SMK069_shipment_schedule_mst.LastRunDate` once per second for up to 30 seconds. It never performs HTTP and never replaces TaskMan.

If the background run completes, `Completed=1`. If 30 seconds expires first, it returns cleanly with `Completed=0`; the form still refreshes so the operator sees the latest state.

## Required IDO method

Register on:

```text
IDO: ue_SMK069ShipmentTransport
Method Type: Stored Procedure - Standard Method
Stored Procedure: SMK069WaitShipmentRunCompletionSp
Method Name: SMK069WaitShipmentRunCompletionSp
```

Then use **Resync Parameters** and save.

## Form Rev.7 flow

Generated XML:

```text
FS_20260909_074136_autorefresh_rev7.XML
```

`RunNowOnce` event sequence:

```text
0  SMK069RequestShipmentRunNowSp
1  Run Background Task -> SMK069ShipmentScheduler / READY
2  SMK069WaitShipmentRunCompletionSp (max 30 sec)
3  Refresh object  (Schedule)
4  Refresh object2 (Dashboard)
5  Refresh object3 (Shipment Queue)
```

This preserves the required semantics:

```text
Run Now = one TaskMan execution only
```

while avoiding the misleading immediate refresh that happened before TaskMan had finished.

## Test

1. Apply Patch 12.
2. Register + Resync `SMK069WaitShipmentRunCompletionSp` on `ue_SMK069ShipmentTransport`.
3. Import Form Rev.7.
4. Enter POS UAT credentials.
5. Set `Max / Run = 1` and Save Settings.
6. Click Run Now.
7. The form may stay busy for several seconds while waiting for TaskMan.
8. After completion (or 30-second timeout), Schedule, Dashboard, and Queue refresh automatically.

Expected after a completed run:

```text
Last Run      = updated
Last Status   = S / W / E
Candidates    = updated
Succeeded     = updated
Failed        = updated
Queue         = READY / WAITING_BACKOFF / removed after success as applicable
```

## Why this approach

Mongoose supports form timers, but this tenant has already had Form Script compilation issues and we do not yet have a tenant-exported native Timer response template. The wait-helper approach uses only already-proven native Method Call + Run Background Task + Collection Refresh response types and therefore avoids introducing another unverified client-side serialization dependency.
