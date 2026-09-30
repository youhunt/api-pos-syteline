# PROD Shipment config physical widths PASS

Date: 2026-09-30
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_config_mst

Final physical-width verification:

```text
EndpointUrlBytes  2000
LoginUrlBytes     2000
AuthValueBytes    4000
```

Equivalent SQL types:

```text
EndpointUrl nvarchar(1000)
LoginUrl    nvarchar(1000)
AuthValue   nvarchar(2000)
```

This closes the remaining ConfigWidths issue found during the PROD post-deploy
config verification.
