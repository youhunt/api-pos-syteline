# PROD Shipment extension assembly missing

Date: 2026-09-30
Environment: PROD

Observed in **IDO Extension Class Assemblies**:

- no named Shipment assembly is visible/selected;
- current row is blank/new;
- the service IDO `ue_SMK069ShipmentTransport` already contains extension-method metadata, but that metadata alone does not install the compiled custom assembly.

Expected current tenant assembly contract:

```text
Assembly      ue_SMK069ShipmentExtensions
Namespace     SMK069Shipment
Class         SMK069ShipmentTransportExtension
IDO           ue_SMK069ShipmentTransport
Full type     SMK069Shipment.SMK069ShipmentTransportExtension
```

Required action:

Export/import the exact current TRN Shipment extension assembly/source into PROD,
then build/compile it successfully. It must include the current scheduler runner
and the Shipment duplicate-idempotent success behavior before any real PROD send.
