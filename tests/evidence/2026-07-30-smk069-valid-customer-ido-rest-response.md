# SMK069 Valid-Customer IDO REST Response

## Test Context

The staging customer values were changed to existing customers from `customer_mst`:

```text
DEFAULT | TEST000001 | C000001
DEFAULT | TEST000001 | C000001
DEFAULT | TEST000002 | C000002
```

The validation method was invoked for:

```text
SiteRef : DEFAULT
CoNum   : TEST000002
```

## Mongoose IDO REST Response

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

## Interpretation

```text
MessageCode = 0
ReturnValue = 0
Infobar     = blank
```

This confirms that `ue_SMK069ValidateCustomerSp` completed successfully through the Mongoose IDO REST layer and did not return a customer-validation error for staged order `TEST000002`, whose staging row now uses `cust_num = C000002`.

The REST response alone does not prove the final staging state. Before marking the valid-customer test fully completed, verify that the selected staging group contains:

```text
process_status = V
validation_msg = NULL
```

## Parameter Reminder

```text
Parameter 1 : SiteRef
Parameter 2 : CoNum
Parameter 3 : Infobar output placeholder
```

The method reads `cust_num` from the staging rows selected by `SiteRef + CoNum`.