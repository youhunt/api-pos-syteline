# SMK069 Shipment KACS UAT — HTTP 400 Invalid Params

Date: 2026-09-04

## Invocation

Server-side IDO method:

```text
ue_SMK069ShipmentTransport.SMK069SendOneShipment
```

Target endpoint:

```text
https://api-uat.pizzahut.co.id/inventory-phi/v1/kacs_dn
```

Success mode:

```text
KACS_V1
```

The actual bearer token is intentionally not recorded in Git.

## Tenant result

A fresh bearer token was accepted far enough for KACS to validate the Shipment request. KACS returned:

```text
HttpCode         = 400
ResponseJson     = {"code":1009,"message":"Invalid params","data":null}
TransportSuccess = 1
BusinessSuccess  = 0
Success          = 0
```

Therefore the current gate is payload contract/mapping, not DNS/network and not the previous invalid-token failure.

## Payload snapshot

DN22 request at this point contained:

```text
CUST_CODE   = C000001
WHS_CODE    = PLG
DOC_NO      = CG26080002
DN_NO       = 22
STORE_CODE  = blank
UOM         = CTN
```

Lot-level detail remained separated into four batch rows.

## KACS contract comparison

The supplied KACS API example shows:

- `STORE_CODE` populated;
- `UOM` represented as a JSON number (example `1`), not a string such as `CTN`;
- KACS-style customer/warehouse/store identifiers in the sample.

The sample does not by itself define the tenant-specific code mapping, so production code must not hardcode sample identifiers.

## Source-control gap discovered

During analysis of this UAT result it was confirmed that the tenant definitions of `dbo.SMK069_ShipmentAPI_mst` and `dbo.SMK069BuildShipmentJsonSp` were documented by behavior but were not yet stored as standalone SQL source files in Git. The tenant source was captured into the repository on 2026-09-04.

Prepare/Complete/log object source should also be kept as standalone database source when their exact tenant definitions are captured.
