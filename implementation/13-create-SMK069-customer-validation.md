# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview   : COMPLETED
process_status display  : VERIFIED
process_status read-only: VERIFIED
Method type             : CONFIRMED — Stored Procedure - Standard Method
Customer validation SP  : NOT CREATED
IDO method              : NOT CREATED
Process/Reprocess        : NOT STARTED
Customer Order creation : NOT STARTED
API ingestion            : NOT STARTED
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

All lines belonging to the selected group are evaluated together. No Customer Order is created during this step.

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

Tenant screenshot dated 29 July 2026 confirms this IDO Method Wizard configuration is available:

```text
IDO Name     : ue_SMK069TempSales
Method Type  : Stored Procedure - Standard Method
Stored Proc. : required selection
Method Name  : required/auto-populated and can be adjusted
Transactional: available checkbox
```

The wizard requires the stored procedure to exist before it can be selected. Therefore, the stored procedure must be created first.

Official Mongoose behavior also confirms that a stored-procedure method is added by selecting an existing application-database stored procedure; the method name must be unique on the IDO, and the Transactional option can be enabled when the method should run in a transaction.

## Confirmed Object Names

```text
Physical stored procedure : dbo.ue_SMK069ValidateCustomerSp
IDO                        : ue_SMK069TempSales
IDO method name            : ValidateCustomer
Method type                : Stored Procedure - Standard Method
Transactional              : Yes (when the IDO method is registered)
```

The `ue_` prefix is used on the physical custom stored procedure. The published IDO method uses the concise business name `ValidateCustomer`, which is suitable for later form and REST/API invocation.

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

A missing customer is a business validation result, not a technical execution failure. Therefore, it updates the staging group to `E` and returns `0`.

## SQL Source

Repository script:

```text
database/stored-procedures/ue_SMK069ValidateCustomerSp.sql
```

The procedure only updates the custom staging table:

```text
dbo.ue_SMK069_temp_sales_mst
```

It reads `customer_mst` for validation and does not update standard Customer Order tables.

## Current Small Step

Create only this stored procedure in the application database:

```text
dbo.ue_SMK069ValidateCustomerSp
```

After creation, verify that it appears in the Stored Procedure dropdown of the IDO Method Wizard.

Do not click OK to create the IDO method until the procedure is visible in the dropdown.

## Next Step After Confirmation

When the stored procedure is visible:

```text
IDO Name     : ue_SMK069TempSales
Method Type  : Stored Procedure - Standard Method
Stored Proc. : ue_SMK069ValidateCustomerSp
Method Name  : ValidateCustomer
Transactional: checked
```

Then review the automatically generated parameters before saving.

## Stop Point

Do not create the Process button, Customer Order, CSV importer, or REST endpoint during this step.