# Shipment Patch 17 — Controlled UAT arm state PASS

Date: 2026-09-09
Scope: Shipment outbound SyteLine -> POS API

Tenant verification after applying Patch 17:

```text
MasterEnabled     0
EndpointUrl       https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
ScheduleCode      HOURLY
MaxShipments      1
ScheduleEnabled   1
RunRequested      0
RunState          I
NextRunDate       Sep 10 2026 10:35AM
ShipmentId        P96331
AttemptCount      0
RetryState        P
NextAttemptDate   NULL
LastHttpCode      0
```

Interpretation:

- master scheduler remains OFF;
- corrected `/inventory-phi/v1/infor_dn` endpoint remains active;
- HOURLY is constrained to one Shipment per run;
- schedule is not requested/running;
- NextRunDate is parked in the future, so enabling master alone should not make HOURLY due;
- P96331 retry state has been reset to pending with attempt 0.

No HTTP was sent by Patch 17.

Next gate before controlled UAT: prove P96331 is the first candidate under `SMK069GetPendingShipmentsSp` ordering before enabling master / Run Now.
