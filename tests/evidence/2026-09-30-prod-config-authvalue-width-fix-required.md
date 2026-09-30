# PROD config width diagnostic — AuthValue still too short

Date: 2026-09-30
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_config_mst

Observed:

```text
EndpointUrlBytes  2000
LoginUrlBytes     2000
AuthValueBytes    4
```

Interpretation:

- EndpointUrl = nvarchar(1000) PASS
- LoginUrl = nvarchar(1000) PASS
- AuthValue = nvarchar(2) FAIL

Required current TRN/UAT contract:

```text
AuthValue = nvarchar(2000)
sys.columns.max_length = 4000 bytes
```

Correct through SQL Tables, set AuthValue Length=2000, then Update Current Table and rerun the post-deploy config verification.
