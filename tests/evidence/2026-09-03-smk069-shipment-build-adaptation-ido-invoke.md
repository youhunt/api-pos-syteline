# SMK069 Shipment Build Adaptation — IDO Invoke — 2026-09-03

Repeated tenant Build From Source compilation showed that the direct
`System.Data` dependency was not available to the custom assembly build.

Decision:

```text
Retire:
ApplicationDB.Connection
IDbCommand
System.Data.dll dependency

Use:
Mongoose.IDO.Protocol
Context.Commands.Invoke
```

The existing SQL procedures remain unchanged.

Required service IDO methods:

```text
ue_SMK069ShipmentTransport.SMK069PrepareShipmentSendSp
  -> stored procedure dbo.SMK069PrepareShipmentSendSp

ue_SMK069ShipmentTransport.SMK069CompleteShipmentSendSp
  -> stored procedure dbo.SMK069CompleteShipmentSendSp
```

The extension method `SMK069SendOneShipment` now calls these methods inside
the current Mongoose caller/session context.
