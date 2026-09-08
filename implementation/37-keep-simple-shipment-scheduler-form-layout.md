# Keep Shipment Scheduler Form Layout Simple

Date: 2026-09-08

This note records the current tenant form state and removes the earlier idea of nested splitters/tabs as a requirement for the first usable version.

## Current tenant layout

The current `SMK069ShipmentScheduler` form already uses one MultiView-style split:

- left pane: Schedule grid (`ue_SMK069ShipmentSchedules`)
- right pane: Schedule detail fields
- right pane also contains Dashboard display fields
- bottom area in the right pane contains the Shipment Queue grid

This layout is acceptable for the first operational version.

Do **not** rebuild the form just to create nested splitters.
Do **not** make Queue a child of Schedule.
Do **not** make Dashboard a child of Schedule.

## Recommended visual order inside the existing right pane

Keep one splitter only and arrange the right pane vertically:

```text
+--------------------------------------------------------------+
| Dashboard / Status                                           |
| API Active | Master | Ready | Waiting | Exhausted | Max/Run  |
+--------------------------------------------------------------+
| Selected Schedule                                            |
| Code | Name | Interval | Max Shipments | Enabled | Status    |
+--------------------------------------------------------------+
| Shipment Queue                                               |
| DN | Queue Status | Attempt | Max | Retry | HTTP | Error      |
+--------------------------------------------------------------+
```

The left pane remains the Schedule selector/grid.

## Collection semantics

The collections remain independent at Site level:

```text
Schedules  -> one or more schedule definitions for the Site
Dashboard  -> one summary row for the Site
Queue      -> all current eligible/retry Shipment DN for the Site
Config     -> one SHIPMENT config row for the Site
```

Only the Schedule grid and Schedule detail are two presentations of the same primary collection.

Queue and Dashboard must not be linked to the selected Schedule.

## Current UAT filters

```text
Schedules : SiteRef = 'Default'
Dashboard : SiteRef = 'Default'
Queue     : SiteRef = 'Default'
Config    : SiteRef = 'Default' AND ApiName = 'SHIPMENT'
```

Replace the hardcoded UAT Site filter with the current-Site expression before production/multi-site rollout.

## Current data-load issue

The primary Schedule collection loads on form open. The Dashboard and Queue are secondary/independent collections and are currently blank until explicitly loaded/refreshed.

The next technical task is **not layout redesign**. It is to wire reliable load/refresh of the independent Dashboard and Queue collections when the form opens/refreshes.

## First usable visual target

```text
Left Schedule grid:
HOURLY

Dashboard:
Master Scheduler = 0
API Active       = 1
Ready            = 2
Waiting Retry    = 0
Exhausted        = 0
Default Max      = 50

Selected Schedule:
HOURLY | Every 60 Minutes | 60 | Max blank/default | Enabled 0

Queue:
P96327 | READY | 0 | 5
P96328 | READY | 0 | 5
```

## Next step

1. Keep the current one-splitter form.
2. Reorder Dashboard above Schedule detail if desired; this is cosmetic only.
3. Wire load/refresh for Dashboard and Queue.
4. Confirm Dashboard shows `0 / 1 / 2 / 0 / 0 / 50` baseline.
5. Confirm Queue shows `P96327` and `P96328`.
6. Only after the read model is visible, wire Save Schedule / Master ON-OFF / Run Now.
