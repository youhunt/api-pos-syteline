# PROD PrepareShipment baseline PASS

Date: 2026-09-28
Environment: PROD
Object: dbo.SMK069PrepareShipmentSendSp

Verification:

```text
PrepareSp          PASS
DnParamNvarchar40  PASS
CallsBuildSp       PASS
UsesApiLog         PASS
DefinitionLength   3609
```

Interpretation:

- PrepareShipment exists in PROD;
- @DN_No is nvarchar(40);
- it calls dbo.SMK069BuildShipmentJsonSp;
- it uses dbo.ue_SMK069_shipment_api_log_mst;
- baseline is ready for CompleteShipment verification.
