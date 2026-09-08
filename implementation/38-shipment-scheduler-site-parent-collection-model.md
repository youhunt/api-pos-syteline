# Shipment Scheduler Form — Site Parent Collection Model

Date: 2026-09-08

This is the authoritative collection model for `SMK069ShipmentScheduler`.

## Business hierarchy

```text
SITE
├─ 1 Dashboard summary
├─ N Schedule definitions
├─ N Shipment Queue rows
└─ 1 SHIPMENT API configuration row
```

Terminology:

- Shipment Scheduler = the whole subsystem/form for one Site.
- Dashboard = one aggregate status row for the Site.
- Schedule = a timing definition such as HOURLY.
- Queue = Shipment DN rows waiting/retrying for the Site.

There are not multiple Dashboard rows per Schedule. There is one Dashboard per Site.
There is not a separate Queue owned by each Schedule. All schedules consume the same Site-level Queue.

## Preferred form collection model

```text
Primary/Parent
ue_SMK069ShipmentSchedulerDashboard
  key: SiteRef

Child
ue_SMK069ShipmentSchedules
  LinkBy: Dashboard.SiteRef -> Schedule.SiteRef

Child
ue_SMK069ShipmentSchedulerQueue
  LinkBy: Dashboard.SiteRef -> Queue.SiteRef

Optional child
ue_SMK069ShipmentApiConfigs
  LinkBy: Dashboard.SiteRef -> Config.SiteRef
  Additional filter: ApiName = 'SHIPMENT'
```

This SiteRef relationship is the correct form loading relationship.
Queue must not be linked to the selected Schedule.

## Visual layout

One splitter is enough:

```text
+--------------------------------------------------------------+
| DASHBOARD / CONTROL CENTER                                   |
| Master | API | Ready | Waiting | Exhausted | Default Max     |
+----------------------+---------------------------------------+
| SCHEDULE LIST        | SELECTED SCHEDULE DETAIL              |
| HOURLY               | Code / Name / Interval / Max / Active |
+----------------------+---------------------------------------+
| SHIPMENT QUEUE                                               |
| DN | Status | Attempts | Max | Retry After | HTTP | Error    |
+--------------------------------------------------------------+
```

Dashboard components bind to the parent collection.
Schedule grid and schedule detail bind to the same Schedule child collection.
Queue grid binds to the Queue child collection.

## Current UAT baseline

Site Default:

```text
Dashboard: Master=0, API Active=1, Ready=2, Waiting=0, Exhausted=0, Default Max=50, Max Attempts=5
Schedule : HOURLY / Every 60 Minutes / 60 / Enabled=0
Queue    : P96327 READY; P96328 READY
```

## Current form correction

The existing form was initially created with `ue_SMK069ShipmentSchedules` as primary. Before adding event handlers only to force unrelated secondary refreshes, prefer correcting the collection structure so Dashboard is the parent and Schedule/Queue are linked children by `SiteRef`.

Do not use `StdFormRefreshCompleted` handlers merely to compensate for the old collection model unless a later tenant test proves linked child collections still need explicit refresh.

## Next step

1. Use Dashboard as parent collection.
2. Link Schedules by SiteRef.
3. Link Queue by SiteRef.
4. Keep Queue read-only.
5. Verify Dashboard and Queue auto-load with the parent Site row.
6. Then wire Save Schedule, Master ON/OFF, Run Now, Retry Reset, and background TaskMan processing.
