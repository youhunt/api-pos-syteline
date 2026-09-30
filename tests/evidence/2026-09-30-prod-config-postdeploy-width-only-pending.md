# PROD post-deploy config verification — only ConfigWidths pending

Date: 2026-09-30
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_config_mst

Observed verification:

```text
SiteRef       Default
ProdUrls      PASS
ApiActive     PASS
HttpContract  PASS
ConfigWidths  FAIL
MasterOff     PASS
RetryPolicy   PASS
Interval1Min  PASS
MaxRun1       PASS
BusinessOff   PASS
PriceRule     PASS
```

Interpretation:

All runtime/configuration gates pass except the physical width contract.
Earlier PROD SQL Tables metadata showed AuthValue length 2 while the captured
TRN/UAT physical contract requires AuthValue nvarchar(2000).

Target physical max_length values in sys.columns:

```text
EndpointUrl  2000 bytes  -- nvarchar(1000)
LoginUrl     2000 bytes  -- nvarchar(1000)
AuthValue    4000 bytes  -- nvarchar(2000)
```

Correct AuthValue through SQL Tables, then Update Current Table and rerun the
post-deploy verification.
