# Evidence — TaskMan 4600 Succeeded, Scheduler State Still Needs Verification

Date: 2026-09-08

Observed tenant result:

```text
Task Number   : 4600
Task Name     : SMK069ShipmentScheduler
Task Type     : IDOMTH
Return Status : Task Succeeded
Initiator     : Form.ue_SMK069ShipmentScheduler
```

The previous `Too few items in the invokeParameters list` error is no longer present, so TaskMan can now invoke `ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule` successfully at the IDO transport level.

Important interpretation:

`Task Succeeded` only proves the background task invocation completed without a TaskMan/runtime invocation failure. It does NOT by itself prove that a due active Shipment schedule was claimed or that any Shipment was sent.

The scheduler runner can legitimately return cleanly when there is no due work, for example when the master scheduler is OFF, the HOURLY schedule is disabled, or the schedule is not due/requested.

Verify scheduler execution from business state, not TaskMan status alone:

```text
Dashboard:
MasterEnabled
ActiveScheduleCount
NextRunDate
ReadyCount

HOURLY schedule:
IsEnabled
RunState
LastStartDate
LastRunDate
LastRunStatus
LastCandidates
LastSucceeded
LastFailed
LastExhausted
LastMessage

Queue / retry:
ShipmentId
AttemptCount
QueueStatus
NextAttemptDate
LastHttpCode
LastError
```

For first UAT, keep `MaxShipments = 1` until one Shipment attempt is confirmed.
