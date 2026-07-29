# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview    : COMPLETED
process_status display   : VERIFIED
process_status read-only : VERIFIED
Method type              : CONFIRMED — Stored Procedure - Standard Method
Customer validation SP   : NOT CREATED IN TENANT
IDO method               : NOT CREATED
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
Stored Proc.  : required existing stored procedure
Method Name   : required/auto-generated custom method name
Transactional : available checkbox
```

The stored procedure must exist before it can be selected in the wizard.

## Corrected Tenant Naming Rule

The user confirmed the actual tenant behavior:

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix is added automatically
```

Therefore, use:

```text
Physical stored procedure : dbo.SMK069ValidateCustomerSp
IDO                        : ue_SMK069TempSales
Base business method name  : ValidateCustomer
Actual IDO method name     : confirm the automatically generated ue_ name in the wizard
Method type                : Stored Procedure - Standard Method
Transactional              : Yes, when the method is registered
```

Do not manually add `ue_` to the stored procedure name.

Do not finalize the exact published method name until the tenant wizard displays the automatically generated value.

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

## Current Small Step

Create only this stored procedure in the tenant application database:

```text
dbo.SMK069ValidateCustomerSp
```

After creation, reopen the IDO Method Wizard and confirm it appears in the Stored Procedure dropdown.

Do not click OK to create the IDO method until the generated Method Name and parameter area have been reviewed.

## Next Step After Confirmation

Expected wizard values:

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : tenant-generated ue_ custom method name; verify from screen
Transactional : checked
```

Then review the generated parameters before saving.

## Stop Point

Do not create the Process button, Customer Order, CSV importer, or REST endpoint during this step.
