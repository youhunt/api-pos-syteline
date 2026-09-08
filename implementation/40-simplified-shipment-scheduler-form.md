# Simplified Shipment Scheduler Form

Date: 2026-09-08

This document supersedes the earlier need for a permanent Schedule selector grid on the left side of the first operational Shipment Scheduler form.

## Decision

For the first operational version, the form is simplified to three main sections:

1. Scheduler Configuration / Current Schedule
2. Dashboard / Status Summary
3. Shipment Queue Detail

The permanent Schedule grid on the left is **not required** while the tenant is operating a single active schedule definition (`HOURLY`) for UAT/initial rollout.

## Why

A READY Shipment queue row is not owned by one schedule yet. It is a Site-level queue item. A schedule only becomes traceable to a Shipment after a scheduler run claims/processes the Shipment. Therefore a left-side Schedule selector does not add useful context to the READY queue for the first version.

Current baseline:

```text
ScheduleCode     = HOURLY
ScheduleName     = Every 60 Minutes
IntervalMinutes  = 60
MaxShipments     = blank/default
IsEnabled        = 0
```

## Recommended first-version layout

```text
+------------------------------------------------------------------+
| Shipment Scheduler Control Center                                |
+------------------------------------------------------------------+
| SCHEDULER                                                        |
| Code            : HOURLY                                         |
| Name            : Every 60 Minutes                               |
| Interval        : 60 Minutes                                     |
| Max Shipments   : blank = Default Max Batch                      |
| Enabled         : No                                             |
| Next Run        : --                                             |
| Run State       : Idle                                           |
+------------------------------------------------------------------+
| DASHBOARD                                                        |
| API Active      : 1                                              |
| Master Scheduler: 0                                              |
| Ready           : 2                                              |
| Waiting Retry   : 0                                              |
| Exhausted       : 0                                              |
| Default Max     : 50                                             |
| Max Attempts    : 5                                              |
+------------------------------------------------------------------+
| SHIPMENT QUEUE                                                   |
| DN       | Status | Attempts | Max | Next Retry | HTTP | Error   |
| P96327   | READY  | 0        | 5   |            |      |         |
| P96328   | READY  | 0        | 5   |            |      |         |
+------------------------------------------------------------------+
```

## Collection behavior

The form still uses the existing IDOs:

```text
ue_SMK069ShipmentSchedules
ue_SMK069ShipmentSchedulerDashboard
ue_SMK069ShipmentSchedulerQueue
ue_SMK069ShipmentApiConfigs   (later/config section)
```

For the first version, `ue_SMK069ShipmentSchedules` is filtered to the current Site and the single `HOURLY` row. There is no need to expose a left-side multi-row selector.

Dashboard and Queue remain Site-level data. Queue is not linked by ScheduleCode.

## Future multi-schedule support

The database design continues to support multiple schedules. If the business later needs multiple active schedules such as `HOURLY`, `FAST-15`, or different batch policies, add one of these later:

- a Schedule maintenance form, or
- a Schedule dropdown/selector on this form.

Do not add a permanent left-side grid merely to anticipate a future requirement that is not yet needed.

## Run traceability

READY queue rows have no owning schedule. After a scheduler run claims/processes them, traceability must be captured through a Run Header / Run Detail model:

```text
Schedule -> Run Header -> Run Detail -> Shipment
```

This is documented in `implementation/39-shipment-scheduler-run-traceability-model.md`.

## Current next step

Keep the existing form objects but simplify the visible layout:

1. Remove/hide the left Schedule grid from the user-facing first version.
2. Keep the `HOURLY` schedule fields as the Scheduler section.
3. Load/show Dashboard values.
4. Load/show Queue rows.
5. Do not enable automatic sending yet.
6. After the visible form works, wire Save Schedule / Master ON-OFF / Run Now.
7. First UAT send uses `MaxShipments = 1`.
