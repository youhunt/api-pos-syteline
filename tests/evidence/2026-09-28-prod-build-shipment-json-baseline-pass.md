# PROD BuildShipmentJson baseline PASS

Date: 2026-09-28
Environment: PROD
Object: dbo.SMK069BuildShipmentJsonSp

Verification:

```text
BuildSp                 PASS
DnParamNvarchar10       PASS
DocNoNonBlocking        PASS
StoreOrderNonBlocking   PASS
PriceGuard              PASS
```

Interpretation:

- exact current UAT BuildShipmentJson procedure is installed in PROD;
- @DN_No is nvarchar(10);
- DOC_NO non-blocking R2 is present;
- STORE_ORDER_NO non-blocking R1 is present;
- PRICE positive guard R1 is present;
- historical Build SP patches 060, 071 and 073 do not need to be replayed on this clean PROD baseline.
