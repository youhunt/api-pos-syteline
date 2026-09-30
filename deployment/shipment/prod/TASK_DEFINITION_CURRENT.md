# PROD Shipment Task Definition — current cutover contract

Updated: 2026-09-30
Scope: Shipment outbound only

Create/import only the Background Task Definition metadata. Do not migrate any
TRN ActiveBGTasks instance, TaskNumber, recurrence row, or runtime history.

Required definition:

```text
Task Name       : SMK069ShipmentScheduler
Executable Type : IDOMTH
Executable Name : ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule
Max Concurrent  : 1
```

Current PROD cutover heartbeat target after smoke PASS:

```text
1 minute
```

Do not START the recurring task yet. Initial PROD state remains:

```text
SchedulerEnabled = 0
Business schedule IsEnabled = 0
MaxShipments = 1
```

The recurring ActiveBGTasks instance must be created fresh in PROD after the
controlled smoke test. Never copy the TRN TaskNumber/runtime row.
