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
→ reusable Process/Reprocess method
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
[COMPLETED] invalid-customer direct SQL test
[COMPLETED] invalid-customer Mongoose IDO REST test
[COMPLETED] valid-customer Mongoose IDO REST test
[COMPLETED] valid-customer persisted staging result
[COMPLETED] first mandatory customer validation requirement
[IN PROGRESS] standard Customer Order IDO/business-process discovery
[NOT STARTED] custom Process/reprocess method
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

Parameters:

```text
1. SiteRef : input
2. CoNum   : input
3. Infobar : output
```

The procedure reads `cust_num` from staging. `cust_num` is not passed directly as a method argument.

## Invalid-Customer Evidence

Controlled case:

```text
DEFAULT | TEST000002 | TST0002 | NOT FOUND
```

Verified result:

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

## Valid-Customer Evidence

Controlled staging case:

```text
DEFAULT | TEST000002 | line 1 | C000002
```

Mongoose IDO REST response:

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

Persisted staging result:

```text
SiteRef        : DEFAULT
co_num         : TEST000002
co_line        : 1
cust_num       : C000002
process_status : V
validation_msg : NULL
```

Evidence:

```text
tests/evidence/2026-07-30-smk069-valid-customer-ido-rest-response.md
tests/evidence/2026-07-30-smk069-valid-customer-staging-result.md
```

Customer validation is now fully completed for both valid and invalid branches.

## Current Development Object

```text
implementation/14-discover-standard-customer-order-processing.md
```

The next custom object will be a reusable Process/Reprocess server-side method called by both:

```text
Error Processing form
controlled POS/API service
```

Before designing it, the exact standard Customer Order IDO and supported business methods must be identified from this tenant.

## Immediate Next Step

Do only this discovery action:

```text
1. Open the standard Customer Orders form
2. Enter Design Mode
3. Open Collections
4. Select the primary collection
5. Capture the exact standard IDO name and collection name
6. Send a screenshot
```

Do not modify the standard Customer Orders form.

Do not create the custom Process method, Process button, Customer Order, CSV import, or controlled receive API method in this same step.

## API Direction

```text
POS / Postman / CSV
→ controlled service IDO receive method
→ custom staging
→ reusable validation
→ reusable Process/Reprocess method
→ supported Customer Order business processing
→ co_mst + coitem_mst
```

The successful validation-method REST calls prove the Mongoose API layer, but they are not the final external POS receive endpoint. Direct SQL insertion into standard Customer Order tables remains prohibited.

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
implementation/14-discover-standard-customer-order-processing.md
tests/evidence/2026-07-30-smk069-invalid-customer-ido-rest.md
tests/evidence/2026-07-30-smk069-valid-customer-ido-rest-response.md
tests/evidence/2026-07-30-smk069-valid-customer-staging-result.md
CHANGELOG.md
```

## Ready-to-Paste New-Chat Prompt

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Current status:
- staging table, IDO, Error Processing form, Preview, and process_status mapping are complete;
- dbo.SMK069ValidateCustomerSp and ue_SMK069ValidateCustomerSp are complete;
- invalid-customer direct SQL and IDO REST tests passed;
- valid-customer IDO REST response passed;
- TEST000002 persisted as C000002 / process_status V / validation_msg NULL;
- customer validation is fully completed;
- Process/Reprocess, Customer Order creation, controlled service receive method, and final POS API are not started.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Open the standard Customer Orders form in Design Mode, inspect its primary collection, and provide a screenshot showing the exact standard IDO and collection name. Do not modify the standard form or create Process logic yet.
```
