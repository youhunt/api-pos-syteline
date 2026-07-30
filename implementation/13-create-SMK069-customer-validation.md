# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview             : COMPLETED
process_status display/read-only  : VERIFIED
Customer validation stored proc   : CREATED IN TENANT
Customer validation IDO method    : PERSISTED
Generated parameters              : VERIFIED
Invalid-customer SQL test         : VERIFIED
Invalid-customer IDO REST test    : VERIFIED
Valid-customer IDO REST response  : VERIFIED
Valid-customer staging result     : VERIFICATION PENDING
Process/Reprocess                  : NOT STARTED
Customer Order creation           : NOT STARTED
Controlled API receive method      : NOT STARTED
```

## Validation Requirement

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

Validation scope:

```text
SiteRef + co_num
```

The method receives `SiteRef` and `CoNum`. It reads `cust_num` from every staging line belonging to that order group.

## Implemented Objects

```text
Physical procedure : dbo.SMK069ValidateCustomerSp
Entity IDO         : ue_SMK069TempSales
IDO method         : ue_SMK069ValidateCustomerSp
Method type        : Stored Procedure - Standard Method
Transactional      : checked
```

Tenant naming behavior:

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix is added automatically
```

## Method Parameters

| Sequence | Parameter | Direction | Tenant Type |
| ---: | --- | --- | --- |
| 1 | `SiteRef` | Input | `VARIANT` |
| 2 | `CoNum` | Input | `VARIANT` |
| 3 | `Infobar` | Output | `VARIANT` |

Stored-procedure contract:

```sql
@SiteRef dbo.SiteType,
@CoNum   dbo.CoNumType,
@Infobar dbo.InfobarType OUTPUT
```

Return values:

```text
0  = method executed; inspect staging process_status for business result
16 = invalid invocation or technical failure
```

## Expected Business Results

### Customer exists

```text
process_status = V
validation_msg = NULL
Infobar        = blank
```

### Customer blank or not found

```text
process_status = E
validation_msg = Customer <cust_num> tidak ditemukan di customer_mst.
Infobar        = same customer-not-found message
```

## Invalid-Customer Evidence

Initial controlled staging case:

```text
SiteRef  : DEFAULT
CoNum    : TEST000002
cust_num : TST0002
```

`TST0002` was confirmed absent from `customer_mst`.

Direct SQL and Mongoose IDO REST tests both returned the expected error result:

```text
ReturnValue     : 0
process_status  : E
validation_msg  : Customer TST0002 tidak ditemukan di customer_mst.
returned Infobar: Customer TST0002 tidak ditemukan di customer_mst.
```

Evidence:

```text
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
```

## Parameter Semantics

The method parameters are positional:

```text
1. SiteRef
2. CoNum
3. blank Infobar output placeholder
```

`cust_num` must not be passed as parameter 2.

Example of an intentionally incorrect call:

```text
DEFAULT, C000001, <blank>
```

This correctly returned `16`, because Mongoose interpreted `C000001` as `CoNum` and no staged order existed with that number.

## Valid-Customer Staging Data

The user updated the staging customer values to real customers from `customer_mst`:

```text
DEFAULT | TEST000001 | C000001 | line 1
DEFAULT | TEST000001 | C000001 | line 2
DEFAULT | TEST000002 | C000002 | line 1
```

The method was then invoked through the Mongoose IDO REST layer for:

```text
SiteRef : DEFAULT
CoNum   : TEST000002
```

Observed response:

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

Interpretation:

```text
MessageCode = 0
ReturnValue = 0
Infobar     = blank
```

This is the expected API response for a valid customer and proves the IDO method completed without returning a customer-validation error. It does not yet prove the final values stored on the staging row.

Evidence:

```text
tests/evidence/2026-07-30-smk069-valid-customer-ido-rest-response.md
```

## Current Small Step — Verify Staging Result

Run only this query:

```sql
SELECT
    SiteRef,
    co_num,
    co_line,
    cust_num,
    process_status,
    validation_msg
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = N'DEFAULT'
  AND co_num = N'TEST000002'
ORDER BY co_line;
```

Expected:

```text
cust_num         = C000002
process_status   = V
validation_msg   = NULL
```

Do not create Process logic, Customer Orders, CSV import, or the controlled POS receive API method during this verification step.

## Architecture Direction

The completed validation method is reusable by the future integration flow:

```text
POS / Postman / CSV
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ ue_SMK069ValidateCustomerSp
→ Error Processing / Process-Reprocess
→ supported Customer Order business process
→ co_mst + coitem_mst
```

Direct SQL insertion into `co_mst` or `coitem_mst` remains prohibited.