# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview       : COMPLETED
process_status display      : VERIFIED
process_status read-only    : VERIFIED
Customer validation SP      : CREATED IN TENANT
IDO method attributes       : CONFIGURED
Generated parameters        : VERIFIED
IDO method persisted        : VERIFIED
Invalid test customer       : VERIFIED — TEST000002 / TST0002 NOT FOUND
Stored-procedure logic test : VERIFIED
IDO REST invocation test    : VERIFIED
Valid customer candidate    : C000001 — EXISTENCE NOT YET VERIFIED
Valid-customer test         : NOT STARTED
Process/Reprocess            : NOT STARTED
Customer Order creation     : NOT STARTED
API receive implementation  : NOT STARTED
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

Customer validation is implemented once as reusable server-side logic. It will later be called by:

```text
Error Processing form
CSV import
REST API ingestion
Process/Reprocess action
```

Do not duplicate customer lookup logic inside the form.

The successful IDO REST invocation proves that the validation method can be called through Mongoose. It does not replace the future controlled service IDO receive method required for the final POS integration API.

## Confirmed Tenant Method Configuration

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

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

| Sequence | Parameter Name | User Data Type | Direction |
| ---: | --- | --- | --- |
| 1 | `SiteRef` | `VARIANT` | Input |
| 2 | `CoNum` | `VARIANT` | Input |
| 3 | `Infobar` | `VARIANT` | Output |

Direction follows the stored-procedure definition:

```sql
@SiteRef dbo.SiteType,
@CoNum   dbo.CoNumType,
@Infobar dbo.InfobarType OUTPUT
```

The **Custom Load Method Output Properties** area is blank. This is correct because `ue_SMK069ValidateCustomerSp` is a Stored Procedure Standard Method, not a custom load method.

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

```text
SiteRef       : DEFAULT
co_num        : TEST000002
cust_num      : TST0002
CustomerCheck : NOT FOUND
```

Therefore, `DEFAULT + TEST000002` is the controlled invalid-customer case.

## Stored-Procedure Logic Test Evidence

Direct application-database execution returned:

```text
ReturnCode     : 0
Infobar        : Customer TST0002 tidak ditemukan di customer_mst.
process_status : E
validation_msg : Customer TST0002 tidak ditemukan di customer_mst.
```

This confirms that the stored-procedure business logic works correctly for an invalid customer.

## IDO REST Invocation Evidence

The method was invoked through the Mongoose IDO REST layer using:

```text
IDO    : ue_SMK069TempSales
Method : ue_SMK069ValidateCustomerSp
Parms  : DEFAULT, TEST000002, <blank Infobar output placeholder>
```

Observed response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    "Customer TST0002 tidak ditemukan di customer_mst."
  ],
  "ReturnValue": "0"
}
```

This proves that the saved custom method is callable through Mongoose and returns the expected output parameter.

Detailed evidence:

```text
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
```

## Parameter Semantics Correction

The IDO method parameters are positional:

```text
Parameter 1 : SiteRef
Parameter 2 : CoNum
Parameter 3 : Infobar output placeholder
```

`cust_num` is not passed directly to this validation method. The procedure reads `cust_num` from the staged rows selected by `SiteRef + co_num`.

An attempted call used:

```text
DEFAULT, C000001, <blank Infobar>
```

and returned:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "C000001",
    "Data staging tidak ditemukan untuk SiteRef DEFAULT dan CO Number C000001."
  ],
  "ReturnValue": "16"
}
```

This response is correct because `C000001` was interpreted as `CoNum`, not as `cust_num`. No staging order exists with `co_num = C000001`.

For the valid-customer test, the correct pattern will be:

```text
1. put a real cust_num such as C000001 into staged order TEST000001;
2. call the method with DEFAULT, TEST000001, <blank Infobar>;
3. let the stored procedure read C000001 from the staging row.
```

## Current Small Step — Verify Candidate Customer

Do not modify staging yet. First confirm that candidate customer `C000001` exists for site `DEFAULT`:

```sql
SELECT
    c.site_ref,
    c.cust_num,
    c.cust_seq,
    c.name
FROM dbo.customer_mst AS c
WHERE c.site_ref = N'DEFAULT'
  AND c.cust_num = N'C000001'
  AND c.cust_seq = 0;
```

Expected result:

```text
Exactly one customer row for DEFAULT / C000001 / cust_seq 0
```

Do not update `TEST000001` or invoke the method in this same step.

## Next Step After Customer Confirmation

After `C000001` is confirmed:

```text
1. assign C000001 temporarily to all TEST000001 staging lines;
2. reset TEST000001 process_status to N and clear validation_msg;
3. invoke ue_SMK069ValidateCustomerSp with DEFAULT, TEST000001, blank Infobar;
4. verify process_status becomes V;
5. verify validation_msg becomes NULL.
```

These actions will be performed separately, one small step at a time.

## Stop Point

Do not create the Process button, Customer Order, CSV importer, controlled receive service method, or final external POS API endpoint during this step.