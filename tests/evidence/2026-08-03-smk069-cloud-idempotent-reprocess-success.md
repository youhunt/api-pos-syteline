# SMK069 Cloud Idempotent Reprocess Success

## Date

2026-08-03

## Source Order

```text
SiteRef     : DEFAULT
SourceCoNum : TEST000002
Existing CO : CO26080001
```

## Reprocess Endpoint

```text
/json/method/ue_SMK069TempSales/SMK069ProcessCustomerOrderSp?parms=DEFAULT,TEST000002,0,,,0,
```

## Confirmed Response

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    "0",
    "",
    "CO26080001",
    "1",
    "Customer Order CO26080001 sudah pernah dibuat; staging disinkronkan menjadi Processed."
  ],
  "ReturnValue": "0"
}
```

## Interpretation

The second execution returned the same generated Customer Order number `CO26080001`, reported `Success = 1`, and followed the existing-order synchronization path. The procedure did not attempt to generate a new Customer Order number in the returned contract.

This confirms the tenant runtime reached and successfully executed the idempotent branch based on the existing Customer Order lookup using the source order stored in `co_mst.cust_po`.

A final read-only count check remains useful to independently confirm that no second header or duplicate line exists, although the returned method contract already confirms reuse of `CO26080001`.
