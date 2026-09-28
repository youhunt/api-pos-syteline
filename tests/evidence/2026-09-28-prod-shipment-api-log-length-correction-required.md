# PROD API log physical verification — correction required

Date: 2026-09-28
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_log_mst

Verification result after creation through SQL Tables:

```text
ShipmentIdBytes     40
RequestJsonBytes    -1
ResponseJsonBytes   -1
ProcessStatusBytes  2
ErrorMessageBytes   8
EndpointUrlBytes    2
TotalColumns        18
EnabledTriggers     3
```

Interpretation:

- standard Mongoose trigger generation succeeded (3 enabled user triggers);
- total column count is correct (18);
- ShipmentId / JSON / ProcessStatus physical lengths are correct;
- ErrorMessage and EndpointUrl are too short in PROD:
  - ErrorMessage bytes 8 = nvarchar(4), expected bytes 8000 = nvarchar(4000)
  - EndpointUrl bytes 2 = nvarchar(1), expected bytes 2000 = nvarchar(1000)

Required correction path:

Use SQL Tables / Mongoose metadata, not raw ALTER TABLE:

```text
ErrorMessage Length = 4000
EndpointUrl  Length = 1000
```

Apply/update current table, then re-run physical verification. Do not proceed to dependent Shipment procedures until these two columns match UAT.
