# Evidence — Cloud Staging Insert and Customer Validation Success

Date: 3 August 2026
Environment: SyteLine/Mongoose Cloud
IDO: `ue_SMK069TempSales`
Source order: `TEST000002`
Site: `DEFAULT`

## Staging insert

The REST `additem` call returned:

```json
{
  "Message": "Insert succeeded",
  "MessageCode": 200,
  "UpdatedItems": [
    {
      "ItemID": null,
      "ItemNo": 0,
      "Properties": null
    }
  ]
}
```

## Read-back confirmation

A subsequent GET returned one staging row with:

```text
SiteRef       : DEFAULT
cust_num      : C000001
order_date    : 2026-08-03
terms_code    : CBD
co_num        : TEST000002
co_line       : 1
unit_price    : 10000
 tax_code1    : PPN11%
exch_rate     : 1
whse          : MAIN
item          : AA00001
qty_ordered   : 1
due_date      : 2026-08-03
u_m           : KG
process_status: N
```

The returned RowPointer was:

```text
636f7dc2-047f-4408-a8c9-bb5923f6afdd
```

## Customer validation

Cloud method call:

```text
/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
```

returned:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    ""
  ],
  "ReturnValue": "0"
}
```

## Confirmed interpretation

```text
Cloud REST access       : working
IDO additem             : working
Staging persistence     : confirmed
IDO custom method       : callable
Customer validation     : passed
Validation return code  : 0
Validation infobar      : empty
```

## Next controlled step

Read back `process_status`, `validation_msg`, and `error_msg` for `TEST000002` to confirm whether customer validation moved the record from `N` to `V` before invoking the Customer Order processing method.
