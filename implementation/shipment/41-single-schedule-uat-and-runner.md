# SMK069 Shipment Scheduler — Single Schedule UAT and Runner

Date: 2026-09-08

This document records the simplified decision for the current tenant rollout.

## Scope decision

The first operational version uses one fixed schedule row:

```text
ScheduleCode = HOURLY
```

The form does **not** expose New/Delete Schedule. The operator may:

- view the schedule;
- change the interval/max shipment if later required;
- activate/deactivate the schedule;
- activate/deactivate the master scheduler;
- see dashboard status;
- see the current Shipment queue;
- request Run Now after the secure background runner is installed.

The current queue is Site-level. READY rows are not owned by a schedule until a run claims/processes them.

## Form layout

Keep the current single-screen form:

```text
Shipment Scheduler Control Center

SCHEDULE
Code / Name / Interval / Max Shipments / Enabled / Run State / Last Status

DASHBOARD
Master Scheduler / API Active / Ready / Waiting Retry / Exhausted / Default Max

SHIPMENT QUEUE
ShipmentId / Queue Status / Attempt / Max Attempts / Next Attempt / HTTP / Error
```

No Schedule selector grid is required in the single-schedule rollout.

## Loading Dashboard and Queue

Current primary collection:

```text
ue_SMK069ShipmentSchedules
```

Do not rely on F5 to refresh independent secondary collections.

For this single-schedule form, configure the two display collections as subcollections of the primary collection using only `SiteRef` as the UI link:

```text
Parent collection: ue_SMK069ShipmentSchedules
Parent property  : SiteRef
Child property   : SiteRef
```

Children:

```text
ue_SMK069ShipmentSchedulerDashboard
ue_SMK069ShipmentSchedulerQueue
```

Important:

- This LinkBy is only a Mongoose data-loading relationship.
- It does not mean Queue is business-owned by HOURLY.
- Do not link using ScheduleCode.
- Dashboard and Queue remain read-only.
- UAT Site remains `Default` until the current-Site expression is finalized.

Expected baseline:

```text
MasterEnabled       = 0
ApiActive           = 1
ReadyCount          = 2
WaitingBackoffCount = 0
ExhaustedCount      = 0
DefaultMaxBatchSize = 50

P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

## Runner prerequisite

Patch 08 Rev.2 and Patch 09 are already applied in the tenant.

The existing extension class bound to:

```text
ue_SMK069ShipmentTransport
```

must contain `SMK069SendPendingShipments` from revision 3 before installing the scheduler runner.

The scheduler runner snippet is stored at:

```text
extension-classes/SMK069ShipmentSchedulerRunner.snippet.cs
```

Paste its members **inside** the existing `SMK069ShipmentTransportExtension` class. Do not create a second extension class bound to the same IDO.

## Required stored-procedure IDO methods

Register on `ue_SMK069ShipmentTransport` if not already present.

### SMK069ClaimDueShipmentScheduleSp

```text
1 ScheduleCode OUT String
2 MaxShipments  OUT Int32
3 HasWork       OUT Int32
4 Infobar       OUT String
```

### SMK069CompleteShipmentScheduleSp

```text
1 ScheduleCode IN  String
2 ResultCode   IN  Int32
3 Candidates   IN  Int32
4 Succeeded    IN  Int32
5 Failed       IN  Int32
6 Exhausted    IN  Int32
7 Message      IN  String
8 Success      OUT Int32
9 Infobar      OUT String
```

## Register extension method

Method:

```text
SMK069RunDueShipmentSchedule
```

Type:

```text
Extension Class - Standard Method
Transactional = OFF
```

Parameters:

```text
1 Username     IN  String
2 Password     IN  String
3 ScheduleCode OUT String
4 Candidates   OUT Int32
5 Succeeded    OUT Int32
6 Failed       OUT Int32
7 Exhausted    OUT Int32
8 Infobar      OUT String
```

Do not invoke this method interactively using production credentials because IDO input parameters can be echoed in the response.

## TaskMan heartbeat

TaskMan owns only the polling heartbeat. The business interval remains on the HOURLY schedule row.

Initial UAT configuration:

```text
Heartbeat : every 5 minutes
Method    : SMK069RunDueShipmentSchedule
Username  : POS runtime credential in TaskMan parameter
Password  : POS runtime credential in TaskMan parameter
```

## First send UAT

Before enabling automatic sending:

1. Keep only the single `HOURLY` schedule.
2. Set `MaxShipments = 1` for the first send.
3. Enable the schedule.
4. Enable Master Scheduler.
5. Request Run Now or make NextRunDate due.
6. Let TaskMan heartbeat call `SMK069RunDueShipmentSchedule`.
7. Verify exactly one READY DN was attempted.
8. Verify API log and retry state.
9. Refresh Dashboard/Queue and confirm counts changed correctly.
10. Only then increase MaxShipments from 1 to the desired parameter value.

Expected current READY candidates before the first UAT send:

```text
P96327
P96328
```

The first UAT should attempt only one of them because `MaxShipments = 1`.
