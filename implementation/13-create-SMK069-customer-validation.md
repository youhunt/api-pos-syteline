# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview    : COMPLETED
process_status display   : VERIFIED
process_status read-only : VERIFIED
Method type              : CONFIRMED — Stored Procedure - Standard Method
Customer validation SP   : CREATED IN TENANT
IDO method attributes    : CONFIGURED; PARAMETER REVIEW PENDING
IDO method saved         : NOT YET CONFIRMED
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

Tenant screenshots dated 29 July 2026 confirm:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

The stored procedure must exist before it can be selected in the wizard. Its presence in the Stored Procedure dropdown confirms that `dbo.SMK069ValidateCustomerSp` has been created and is visible to Mongoose metadata.

## Confirmed Tenant Naming Rule

The tenant applies this naming behavior:

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

## Current Small Step — Review Generated Parameters

The Method Attributes screen is now correctly populated.

Perform only this next action:

1. keep these values unchanged:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

2. click `OK`;
3. when the generated method parameter screen appears, do not finalize or close it yet;
4. send a screenshot showing every generated parameter, its sequence, input/output direction, data type, and length if visible.

Expected stored-procedure parameters are:

```text
SiteRef   input
CoNum     input
Infobar   output
```

The wizard may also represent the SQL return value separately. Do not change any generated parameter before the tenant screen is reviewed.

## Next Step After Parameter Confirmation

After parameter mapping is verified:

```text
- save/register the IDO method;
- test the method with an invalid staged customer;
- verify process_status becomes E and validation_msg is populated;
- then test with a real customer and verify process_status becomes V.
```

These tests will be performed one at a time.

## Stop Point

Do not create the Process button, Customer Order, CSV importer, service receive method, or REST endpoint during this step.