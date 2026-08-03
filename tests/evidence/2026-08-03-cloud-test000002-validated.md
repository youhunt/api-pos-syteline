# Evidence — Cloud TEST000002 Validated

Date: 3 August 2026
Environment: Infor SyteLine Cloud REST / Postman
IDO: `ue_SMK069TempSales`

## Insert result

A single staging row for `DEFAULT / TEST000002 / line 1` was inserted successfully through the REST `additem` endpoint.

```text
Message     : Insert succeeded
MessageCode : 200
```

Confirmed row values:

```text
SiteRef        : DEFAULT
cust_num       : C000001
order_date     : 2026-08-03
terms_code     : CBD
co_num         : TEST000002
co_line        : 1
unit_price     : 10000
Tax code       : PPN11%
warehouse      : MAIN
item           : AA00001
quantity       : 1
U/M            : KG
initial status : N
```

## Validation method result

Cloud method call:

```text
/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
```

Response:

```text
MessageCode : 0
ReturnValue : 0
Infobar     : empty
```

A follow-up GET confirmed:

```text
process_status : V
validation_msg : NULL
error_msg      : NULL
```

## Confirmed interpretation

```text
REST authentication             : working
IDO additem                      : working
Staging persistence             : working
Validation method exposure      : working
Customer C000001 validation     : passed
Staging status transition N → V : confirmed
```

The order is now ready for the controlled Customer Order processing method, subject to that stored procedure being exposed as an IDO method with the confirmed parameter order.
