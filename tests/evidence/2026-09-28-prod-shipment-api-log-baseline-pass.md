# PROD API log baseline PASS

Date: 2026-09-28
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_log_mst

Trigger verification:

```text
ue_SMK069_shipment_api_log_mstDel                is_instead_of_trigger=0  is_disabled=0
ue_SMK069_shipment_api_log_mstInsert             is_instead_of_trigger=1  is_disabled=0
ue_SMK069_shipment_api_log_mstUpdatePenultimate  is_instead_of_trigger=0  is_disabled=0
```

Physical verification:

```text
ShipmentIdBytes     40
RequestJsonBytes    -1
ResponseJsonBytes   -1
ProcessStatusBytes  2
ErrorMessageBytes   8000
EndpointUrlBytes    2000
TotalColumns        18
EnabledTriggers     3
```

Interpretation:

- physical column lengths now match current UAT;
- total column count matches UAT;
- the three standard Mongoose triggers exist and are enabled;
- Insert is INSTEAD OF, matching UAT;
- API log baseline is ready for dependent Shipment procedures;
- no UAT runtime log rows were migrated.
