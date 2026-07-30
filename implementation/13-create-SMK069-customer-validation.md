# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview       : COMPLETED
process_status display      : VERIFIED
process_status read-only    : VERIFIED
Method type                 : CONFIRMED — Stored Procedure - Standard Method
Customer validation SP      : CREATED IN TENANT
IDO method attributes       : CONFIGURED
Generated parameters        : VERIFIED
IDO method persisted        : VERIFIED
Invalid test customer       : VERIFIED — TEST000002 / TST0002 NOT FOUND
Stored-procedure logic test : VERIFIED
IDO-layer invocation test   : NOT STARTED
Valid-customer test         : NOT STARTED
Process/Reprocess            : NOT STARTED
Customer Order creation     : NOT STARTED
API ingestion               : NOT STARTED
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

| Sequence | Parameter Name | User Data Type |
| ---: | --- | --- |
| 1 | `SiteRef` | `VARIANT` |
| 2 | `CoNum` | `VARIANT` |
| 3 | `Infobar` | `VARIANT` |

Direction follows the stored procedure definition:

```text
SiteRef : input
CoNum   : input
Infobar : output
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

The procedure was executed directly in the application database with:

```text
SiteRef : DEFAULT
CoNum   : TEST000002
```

Observed result:

```text
ReturnCode     : 0
Infobar        : Customer TST0002 tidak ditemukan di customer_mst.
process_status : E
validation_msg : Customer TST0002 tidak ditemukan di customer_mst.
```

This confirms that the stored-procedure business logic works correctly for an invalid customer. It does not yet prove IDO or REST invocation.

## Current Small Step — Invoke Through the IDO REST Layer

Use the Mongoose `InvokeMethod` REST operation with the existing Mongoose API base URL and security token:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
Authorization: {{mongooseSecurityToken}}
```

Parameter order:

```text
1. DEFAULT
2. TEST000002
3. blank output placeholder for Infobar
```

Expected response:

```text
ReturnValue = 0
returned Infobar = Customer TST0002 tidak ditemukan di customer_mst.
```

After the request, confirm the staging row remains:

```text
process_status = E
validation_msg = Customer TST0002 tidak ditemukan di customer_mst.
```

Do not test a valid customer in the same step.

## Next Step After IDO Invocation Confirmation

After the IDO method is proven callable through Mongoose:

```text
- prepare one staged order using a real customer_mst customer;
- execute the same method separately;
- verify process_status becomes V;
- verify validation_msg becomes NULL.
```

## Stop Point

Do not create the Process button, Customer Order, CSV importer, service receive method, or final external REST endpoint during this step.