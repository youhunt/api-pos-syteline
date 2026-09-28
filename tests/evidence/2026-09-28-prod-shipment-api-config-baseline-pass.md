# PROD baseline evidence — Shipment API config table

Date: 2026-09-28
Environment: PROD
SiteRef: Default

Object:
```text
dbo.ue_SMK069_shipment_api_config_mst
```

Verification result:
```text
ConfigTable       PASS
ColumnCount24     PASS
RowPointerUnique  PASS
RowPointerShape   PASS
EmptyBaseline     PASS
```

Interpretation:
- baseline config table exists in PROD;
- 24-column shape matches the captured UAT structure;
- RowPointer uniqueness matches UAT;
- RowPointer is NOT ROWGUIDCOL and is NOT NULL;
- table is empty, so no UAT endpoint/credential/config data was copied;
- scheduler remains unconfigured/inactive at this stage.
