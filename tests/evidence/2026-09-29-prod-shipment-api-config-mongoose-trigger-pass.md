# PROD config table Mongoose trigger repair PASS

Date: 2026-09-29
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_config_mst

Verification after SQL Tables > Update Current Table:

```text
ue_SMK069_shipment_api_config_mstDel                is_instead_of_trigger=0  is_disabled=0
ue_SMK069_shipment_api_config_mstInsert             is_instead_of_trigger=1  is_disabled=0
ue_SMK069_shipment_api_config_mstUpdatePenultimate  is_instead_of_trigger=0  is_disabled=0
```

Interpretation:

- config table is now registered/updated through the Mongoose SQL Tables path;
- all three standard table triggers exist and are enabled;
- Insert is INSTEAD OF, matching the expected Mongoose pattern;
- config baseline is now acceptable for dependent Shipment scheduler objects.
