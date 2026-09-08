# Keep Shipment Scheduler Form Layout Simple

Date: 2026-09-08

This document is the **final layout decision for the first usable Shipment Scheduler form**. Earlier exploratory ideas about nested splitters, moving Dashboard into the left grid, or making Queue a Schedule detail are superseded by this file.

## Final first-version layout

Keep the form that already exists. Do **not** rebuild it.

The current `SMK069ShipmentScheduler` form uses one MultiView-style split:

- left pane: Schedule grid (`ue_SMK069ShipmentSchedules`)
- right pane: Schedule detail fields
- right pane: Dashboard/status display fields
- bottom area: Shipment Queue grid

This is the approved first usable layout.

```text
+----------------------+---------------------------------------+
| SCHEDULE LIST        | SHIPMENT SCHEDULER STATUS             |
|                      | Master Scheduler : 0                   |
| HOURLY               | API Active       : 1                   |
|                      | Ready            : 2                   |
|                      | Waiting Retry    : 0                   |
|                      | Exhausted        : 0                   |
|                      | Default Max      : 50                  |
|                      +---------------------------------------+
|                      | SELECTED SCHEDULE                     |
|                      | Code       : HOURLY                   |
|                      | Name       : Every 60 Minutes         |
|                      | Interval   : 60                       |
|                      | Max / Run  : blank = default 50       |
|                      | Enabled    : 0                        |
+----------------------+---------------------------------------+
| SHIPMENT QUEUE                                               |
| P96327 | READY | Attempt 0 | Max 5                           |
| P96328 | READY | Attempt 0 | Max 5                           |
+--------------------------------------------------------------+
```

No nested splitter is required for the first version. Tabs are optional later, not a prerequisite.

## Collection semantics

The four collections are not a master-detail chain.

```text
Schedules  -> one or more schedule definitions for the Site
Dashboard  -> one summary row for the Site
Queue      -> all current eligible/retry Shipment DN for the Site
Config     -> one SHIPMENT config row for the Site
```

Only the Schedule grid and Schedule detail are two presentations of the same primary collection.

Do **not** link Queue to the selected Schedule.
Do **not** link Dashboard to the selected Schedule.
Do **not** make Config a child of Schedule.

Every active schedule consumes the same Site-level Shipment queue.

## Current UAT filters

```text
Schedules : SiteRef = 'Default'
Dashboard : SiteRef = 'Default'
Queue     : SiteRef = 'Default'
Config    : SiteRef = 'Default' AND ApiName = 'SHIPMENT'
```

Replace the hardcoded UAT Site filter with the current-Site expression before production/multi-site rollout.

## Current data-load issue

The primary Schedule collection already loads correctly when the form opens.

The current blank Dashboard and Queue are **not a layout problem**. They are the next technical wiring task: the independent secondary collections must be explicitly loaded/refreshed by the form.

Therefore the next work item is:

```text
Load Dashboard collection
Load Queue collection
```

Do not redesign the screen again until these two collections have been proven to load.

## Expected baseline after secondary collections load

Dashboard:

```text
Master Scheduler = 0
API Active       = 1
Ready            = 2
Waiting Retry    = 0
Exhausted        = 0
Default Max      = 50
```

Queue:

```text
P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

## Work order from here

1. Keep the current form and one splitter.
2. Do not change collection relationships.
3. Configure reliable form-open/refresh loading for `ue_SMK069ShipmentSchedulerDashboard`.
4. Configure reliable form-open/refresh loading for `ue_SMK069ShipmentSchedulerQueue`.
5. Verify the baseline values above.
6. Then wire configuration display if needed.
7. Then register/wire Save Schedule.
8. Then wire Master Scheduler ON/OFF.
9. Then wire Run Now.
10. Then wire retry reset and API log display.
11. Only after the visible form is stable, wire the background runner and TaskMan heartbeat.
12. First send UAT should use `MaxShipments = 1`.

This file is the reference layout decision going forward.