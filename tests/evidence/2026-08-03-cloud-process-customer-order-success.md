# Cloud Customer Order Processing Success — 2026-08-03

## Source staging

- SiteRef: `DEFAULT`
- Source CO Number: `TEST000002`
- Customer: `C000001`
- Item: `AA00001`
- Status before processing: `V`

## REST invocation

```text
/json/method/ue_SMK069TempSales/SMK069ProcessCustomerOrderSp?parms=DEFAULT,TEST000002,0,,,0,
```

## Tenant response

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
    "Customer Order CO26080001 berhasil dibuat dari source order TEST000002."
  ],
  "ReturnValue": "0"
}
```

## Confirmed runtime result

- Method resolved successfully on IDO `ue_SMK069TempSales`.
- Stored procedure returned `ReturnValue = 0`.
- `Success = 1`.
- Created Customer Order number: `CO26080001`.
- Informational message reports successful creation from source order `TEST000002`.

## Final verification still required

Do not mark the flow fully closed until all three tenant-side records are verified:

1. `co_mst` header exists for `CO26080001` and `cust_po = TEST000002`.
2. `coitem_mst` contains the expected line(s).
3. Staging row(s) for `TEST000002` changed to `process_status = P` and contain processing audit values.
