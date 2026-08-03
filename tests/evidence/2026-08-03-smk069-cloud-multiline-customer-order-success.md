# SMK069 Cloud Multi-Line Customer Order Success — 2026-08-03

## Test Case

```text
SiteRef       : DEFAULT
SourceCoNum   : TEST000003
Customer      : C000001
Warehouse     : MAIN
Terms         : CBD
Tax Code      : PPN11%
```

Two staging rows were inserted through REST `additems`.

```text
Line 1: item AA00001, qty 1, unit price 10000, U/M KG
Line 2: item AA00001, qty 2, unit price 15000, U/M KG
```

## Staging Insert Result

```json
{
  "Message": "Insert succeeded",
  "MessageCode": 200,
  "UpdatedItems": [
    {"ItemID": null, "ItemNo": 0, "Properties": null},
    {"ItemID": null, "ItemNo": 0, "Properties": null}
  ]
}
```

## Customer Order Processing Result

Endpoint:

```text
/json/method/ue_SMK069TempSales/SMK069ProcessCustomerOrderSp?parms=DEFAULT,TEST000003,0,,,0,
```

Response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000003",
    "0",
    "",
    "CO26080002",
    "1",
    "Customer Order CO26080002 berhasil dibuat dari source order TEST000003."
  ],
  "ReturnValue": "0"
}
```

## Conclusion

```text
Multi-line staging insert : SUCCESS
Generated Customer Order  : CO26080002
Success output             : 1
ReturnValue                : 0
```

This confirms the Cloud runtime can create one Customer Order from a two-line staging source order. Final verification of exactly two Customer Order lines and staging status `P` remains pending.
