# 17 — Current Status and New Chat Handoff

## Project

```text
Repository : youhunt/api-pos-syteline
Project    : Pizza Hut POS / SMK069 Sales Integration to Infor SyteLine Mongoose
Updated    : 30 July 2026
```

## Target Flow

```text
POS sample CSV / REST payload
→ controlled service IDO receive method
→ dbo.ue_SMK069_temp_sales_mst
→ reusable validation
→ Error Processing form
→ supported Customer Order business process
→ co_mst + coitem_mst
```

The official POS payload/file format is not yet available. Development remains incremental, but the final target is still a controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is not stored in the staging table.

## Current Objects

```text
Metadata table        : SMK069_temp_sales_mst
Physical table        : dbo.ue_SMK069_temp_sales_mst
Entity IDO            : ue_SMK069TempSales
Error form            : ue_SMK069APISalesErrorProcessing
Validation procedure  : dbo.SMK069ValidateCustomerSp
Validation IDO method : ue_SMK069ValidateCustomerSp
Primary key           : SiteRef + co_num + co_line
```

Do not create a separate `site_ref`; standard `SiteRef` fulfills the source requirement and Mongoose site context.

## Current Progress

```text
[COMPLETED] SMK069_temp_sales_mst and six process-control columns
[COMPLETED] ue_SMK069TempSales IDO and resynchronization
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and smoke test
[COMPLETED] Preview controls and all filter behaviors
[COMPLETED] process_status display mapping and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp
[COMPLETED] ue_SMK069ValidateCustomerSp transactional IDO method
[COMPLETED] parameter review: SiteRef, CoNum, Infobar
[COMPLETED] invalid-customer SQL test
[COMPLETED] invalid-customer Mongoose IDO REST test
[COMPLETED] valid-customer Mongoose IDO REST response
[NEXT]      verify valid-customer staging status is V and validation_msg is NULL
[NOT STARTED] Process/reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] final external REST API contract and Postman collection
```

## Verified Form Behavior

```text
Order Date only → order_date
CO Number only  → co_num
Both entered    → order_date AND co_num
Both blank      → validation message; no unrestricted load
```

Status mapping:

```text
INLINE ENTRIES(N\New,V\Valid,E\Error,P\Processed,C\Cancelled) DISPLAY(2) VALUE(1)
```

The grid displays descriptions while the database stores `N`, `V`, `E`, `P`, or `C`. Status is read-only.

## Customer Validation Method

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
```

Tenant naming behavior:

```text
Stored Procedure : no ue_ prefix
IDO Method       : ue_ prefix added automatically
```

Parameters:

```text
1. SiteRef : input
2. CoNum   : input
3. Infobar : output
```

The procedure reads `cust_num` from staging. `cust_num` is not passed directly as a method argument.

## Invalid-Customer Evidence

Original controlled case:

```text
DEFAULT | TEST000002 | TST0002 | NOT FOUND
```

Direct SQL and IDO REST tests returned:

```text
ReturnValue     = 0
process_status  = E
validation_msg  = Customer TST0002 tidak ditemukan di customer_mst.
returned Infobar= Customer TST0002 tidak ditemukan di customer_mst.
```

Evidence:

```text
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
```

## Parameter Semantics Correction

The correct REST call shape is:

```text
SiteRef, CoNum, blank Infobar placeholder
```

A call using `DEFAULT,C000001,` returned `16` because `C000001` was interpreted as a `CoNum`, not as `cust_num`.

## Valid-Customer Evidence

The staging customers were changed to real customer values:

```text
DEFAULT | TEST000001 | C000001 | line 1
DEFAULT | TEST000001 | C000001 | line 2
DEFAULT | TEST000002 | C000002 | line 1
```

The method was invoked for:

```text
DEFAULT, TEST000002, <blank Infobar>
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

This is the expected valid-customer API response: execution succeeded and no validation message was returned. Final staging status still requires direct verification.

Evidence:

```text
tests/evidence/2026-07-30-smk069-valid-customer-ido-rest-response.md
```

## Immediate Next Step

Run only:

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
cust_num       = C000002
process_status = V
validation_msg = NULL
```

Do not create Process, Customer Order, CSV import, or the controlled receive API method in the same step.

## Development Rules

1. Work one small step at a time.
2. Use tenant screenshots and actual options as the authority.
3. Distinguish metadata object names from physical SQL names.
4. Do not mark a step completed until tenant evidence confirms it.
5. Keep validation and processing reusable by form, CSV, and REST API paths.
6. Do not perform direct SQL insert into `co_mst` or `coitem_mst`.
7. Item mapping and broader item validation remain postponed.

## Repository Documents to Read First

```text
docs/16-smk069-sales-spec-alignment.md
docs/17-current-status-and-new-chat-handoff.md
database/tables/SMK069_temp_sales_mst.md
database/stored-procedures/SMK069ValidateCustomerSp.sql
implementation/11-create-SMK069-temp-sales-table.md
implementation/12-create-ue_SMK069APISalesErrorProcessing-form.md
implementation/13-create-SMK069-customer-validation.md
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
tests/evidence/2026-07-30-smk069-valid-customer-ido-rest-response.md
CHANGELOG.md
```

## Ready-to-Paste New-Chat Prompt

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Current status:
- staging table, IDO, Error Processing form, Preview, and process_status mapping are complete;
- dbo.SMK069ValidateCustomerSp and ue_SMK069ValidateCustomerSp are complete;
- invalid-customer SQL and IDO REST tests passed;
- staging customers were changed to C000001 for TEST000001 and C000002 for TEST000002;
- IDO REST call DEFAULT,TEST000002, returned MessageCode 0, ReturnValue 0, and blank Infobar;
- valid-customer staging status still needs verification;
- Process, Customer Order creation, controlled service receive method, and final POS API are not started.

The next step is only to query TEST000002 and confirm process_status = V and validation_msg = NULL.
```