# Patch 22 — block non-positive Shipment PRICE before API

Date: 2026-09-21

## Reason

A real Shipment payload was observed with:

```json
{
  "DN_NO": "P963221",
  "DETAIL": [
    {
      "PRODUCT_CODE": "AC20003B",
      "PRICE": 0.00000000,
      "BATCH": null,
      "EXPIRY_DATE": null
    }
  ]
}
```

The current Build validated PRODUCT_CODE but did not reject PRICE NULL/0/negative before the HTTP stage.

## New rule

For pending detail rows with shipment_qty > 0:

```text
PRICE > 0       -> Build may continue
PRICE NULL      -> local validation stop
PRICE = 0       -> local validation stop
PRICE < 0       -> local validation stop
```

Local message:

```text
Terdapat detail shipment dengan PRICE kosong atau <= 0. Shipment tidak dikirim ke POS.
```

## Scope

Patch file:

```text
database/patches/shipment/2026-09-21-smk069-22-block-nonpositive-price.sql
```

The patch is tenant-preserving: it reads the current installed `dbo.SMK069BuildShipmentJsonSp` via `OBJECT_DEFINITION` and inserts one guard before the existing BUILD JSON section. It does not replace the tenant procedure with the stale repository base definition.

It does not change BATCH/EXPIRY_DATE nullability, retry policy, TaskMan, the Shipment View, or the HTTP Extension.

## Apply

Use SyteLine **Apply Database** as one executable batch. Do not add `GO`.

## Verify

Use **SMK Query Select Execution** with:

```text
tests/queries/shipment/2026-09-21-smk069-patch22-price-validation.sql
```

Expected:

```text
Patch22Marker = PASS
PriceGuard    = PASS
```

For P963221, a controlled Run Once should stop locally while PRICE remains 0; there should be no new Shipment POST for that DN.
