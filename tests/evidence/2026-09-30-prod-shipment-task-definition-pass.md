# PROD Shipment Background Task Definition PASS

Date: 2026-09-30
Environment: PROD

Observed Background Task Definition:

```text
Task Name       : SMK069ShipmentScheduler
Executable Type : IDOMTH
Executable Name : ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule
Max Concurrent  : 1
Exclusive       : unchecked
```

The definition matches the current Shipment scheduler contract.

`Max Concurrent Cross-Site = -1` is left as the tenant/default value and is not
changed as part of this Shipment cutover.

No ActiveBGTasks runtime instance / TaskNumber was migrated from TRN. The
recurring PROD instance must remain unregistered until controlled smoke testing
is complete.
