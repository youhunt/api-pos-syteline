# PROD CompleteShipment baseline PASS

Date: 2026-09-28
Environment: PROD
Object: dbo.SMK069CompleteShipmentSendSp

Verification:

```text
CompleteSp                 PASS
DnStringMarker             PASS
ShipmentDnNvarchar40       PASS
OldImplicitConvertRemoved  PASS
PrefixedDnMapping          PASS
SuccessUpdatesApiPost      PASS
DefinitionLength           4910
```

Interpretation:

- current CompleteShipment procedure exists in PROD;
- prefixed outbound DN is handled as nvarchar(40);
- legacy implicit nvarchar-to-bigint assignment is removed;
- P963/R975 + shipment_id mapping is present;
- success path updates shipment_mst.SMK069_Uf_api_post;
- core Shipment baseline (View, Config table, API Log table, Build, Prepare, Complete) is now functionally present in PROD, subject to Mongoose metadata/trigger verification for custom tables.
