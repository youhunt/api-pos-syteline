# SMK069 Shipment Service IDO Four-Method Wiring Confirmed — 2026-09-03

Tenant IDO:

```text
ue_SMK069ShipmentTransport
```

Confirmed method list:

```text
SMK069CompleteShipmentSendSp
SMK069PostShipmentPayload
SMK069PrepareShipmentSendSp
SMK069SendOneShipment
```

Confirmed Complete stored-procedure method:

```text
Method Type      : Stored Procedure - Standard Method
Stored Procedure : SMK069CompleteShipmentSendSp
Transactional    : not checked
```

Parameter sequence:

```text
1 LogRowPointer
2 HttpCode
3 ResponseJson
4 IsSuccess
5 Success
6 Infobar
```

This completes the metadata wiring required for one-Shipment orchestration.

Next tenant step:

```text
Save
Check In
Discard IDO Cache
fresh session if needed
-> safe DN22 negative UAT
```
