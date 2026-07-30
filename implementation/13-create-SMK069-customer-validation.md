# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview    : COMPLETED
process_status display   : VERIFIED
process_status read-only : VERIFIED
Method type              : CONFIRMED — Stored Procedure - Standard Method
Customer validation SP   : CREATED IN TENANT
IDO method attributes    : CONFIGURED
Generated parameters     : VERIFIED
IDO method persisted     : VERIFIED
Invalid test customer    : VERIFIED — TEST000002 / TST0002 NOT FOUND
Execution test           : NOT STARTED
Process/Reprocess         : NOT STARTED
Customer Order creation  : NOT STARTED
API ingestion             : NOT STARTED
```

## Validation Requirement

The first mandatory business validation is:

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

Validation is performed for one staged Customer Order group:

```text
SiteRef + co_num
```

All lines belonging to the selected group are evaluated together. No Customer Order is created during this validation step.

## Expected Outcomes

### Customer exists

```text
process_status = V
validation_msg = NULL
```

### Customer is blank or does not exist

```text
process_status = E
validation_msg = Customer <cust_num> tidak ditemukan di customer_mst.
```

## Architecture Rule

Customer validation must be implemented once as reusable server-side logic. It will later be called by:

```text
Error Processing form
CSV import
REST API ingestion
Process/Reprocess action
```

Do not duplicate customer lookup logic inside the form.

## Confirmed Tenant Method Configuration

Tenant screenshots confirm:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

The stored procedure must exist before it can be selected in the wizard. Its presence in the Stored Procedure dropdown confirms that `dbo.SMK069ValidateCustomerSp` has been created and is visible to Mongoose metadata.

## Confirmed Tenant Naming Rule

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix is added automatically
```

Final confirmed object names:

```text
Physical stored procedure : dbo.SMK069ValidateCustomerSp
IDO                        : ue_SMK069TempSales
IDO method name            : ue_SMK069ValidateCustomerSp
Method type                : Stored Procedure - Standard Method
Transactional              : Yes
```

Do not manually add `ue_` to the physical stored procedure name.

## Stored Procedure Contract

### Inputs

```text
@SiteRef
@CoNum
```

### Output

```text
@Infobar OUTPUT
```

### Return value

```text
0  = validation executed successfully; inspect process_status for Valid/Error business result
16 = invalid invocation or technical failure
```

A missing customer is a business validation result. It updates the staging group to `E` and returns `0`.

## SQL Source

Repository script:

```text
database/stored-procedures/SMK069ValidateCustomerSp.sql
```

The procedure reads:

```text
dbo.customer_mst
```

and updates only:

```text
dbo.ue_SMK069_temp_sales_mst
```

It does not update `co_mst` or `coitem_mst`.

## Generated Parameter Evidence

| Sequence | Parameter Name | User Data Type |
| ---: | --- | --- |
| 1 | `SiteRef` | `VARIANT` |
| 2 | `CoNum` | `VARIANT` |
| 3 | `Infobar` | `VARIANT` |

The order matches the stored-procedure contract:

```text
1. SiteRef  — input
2. CoNum    — input
3. Infobar  — output
```

The tenant screen does not expose separate direction, SQL data type, or length columns in the visible parameter grid. Direction follows the stored-procedure definition:

```sql
@SiteRef dbo.SiteType,
@CoNum   dbo.CoNumType,
@Infobar dbo.InfobarType OUTPUT
```

The **Custom Load Method Output Properties** area is blank. This is correct because `ue_SMK069ValidateCustomerSp` is a Stored Procedure Standard Method, not a custom load method.

No generated parameter was manually changed.

## Persistence Evidence

After saving and reopening the IDO Methods form, the tenant still displays:

```text
IDO Method       : ue_SMK069ValidateCustomerSp
Stored Procedure : SMK069ValidateCustomerSp
Transactional    : checked
Parameter 1      : SiteRef
Parameter 2      : CoNum
Parameter 3      : Infobar
```

This confirms that the IDO method metadata was saved successfully. Do not recreate the method.

## Invalid Customer Test Case Evidence

A database query confirmed:

```text
SiteRef       : DEFAULT
co_num        : TEST000002
cust_num      : TST0002
CustomerCheck : NOT FOUND
```

Therefore, `DEFAULT + TEST000002` is the controlled invalid-customer case for the first execution test.

## Current Small Step — Execute Validation Logic Once

To isolate stored-procedure logic from any later IDO/API invocation issue, perform only the first invalid-customer execution against the application database:

```sql
DECLARE
    @ReturnCode int,
    @Infobar dbo.InfobarType;

EXEC @ReturnCode = dbo.SMK069ValidateCustomerSp
    @SiteRef = N'DEFAULT',
    @CoNum   = N'TEST000002',
    @Infobar = @Infobar OUTPUT;

SELECT
    @ReturnCode AS ReturnCode,
    @Infobar AS Infobar;

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

Expected result:

```text
ReturnCode    = 0
Infobar       = Customer TST0002 tidak ditemukan di customer_mst.
process_status = E
validation_msg populated with the same customer-not-found message
```

This is a controlled logic test of the server-side procedure. It does not replace the later IDO-method and REST/API invocation tests.

## Next Step After SQL Logic Confirmation

After the invalid result is confirmed:

```text
- invoke ue_SMK069ValidateCustomerSp through the IDO layer;
- verify the same Error result;
- then prepare and test one valid customer separately.
```

The tests must be performed one at a time.

## Stop Point

Do not create the Process button, Customer Order, CSV importer, service receive method, or REST endpoint during this step.
