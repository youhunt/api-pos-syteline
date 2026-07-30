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

The official POS payload/file format is not yet available. The final target remains controlled API integration.

## Confirmed Requirement Corrections

```text
Header total = SUM(unit_price * qty_ordered)
Cost         = obtained from item_mst
```

`cost` is not stored in staging. Standard `SiteRef` is used; no separate `site_ref` column is created.

## Current Objects

```text
Metadata table                     : SMK069_temp_sales_mst
Physical table                     : dbo.ue_SMK069_temp_sales_mst
Entity IDO                         : ue_SMK069TempSales
Error form                         : ue_SMK069APISalesErrorProcessing
Validation procedure               : dbo.SMK069ValidateCustomerSp
Validation IDO method              : ue_SMK069ValidateCustomerSp
Standard Customer Order header IDO : SL.SLCos
Standard Customer Order line IDO   : SL.SLCoitems
Primary key                        : SiteRef + co_num + co_line
```

## Current Progress

```text
[COMPLETED] SMK069_temp_sales_mst and six process-control columns
[COMPLETED] ue_SMK069TempSales IDO and resynchronization
[COMPLETED] ue_SMK069APISalesErrorProcessing base form and Preview
[COMPLETED] process_status display mapping and read-only verification
[COMPLETED] dbo.SMK069ValidateCustomerSp
[COMPLETED] ue_SMK069ValidateCustomerSp transactional IDO method
[COMPLETED] invalid-customer SQL and Mongoose REST tests
[COMPLETED] valid-customer Mongoose REST and persisted staging tests
[COMPLETED] mandatory customer validation requirement
[CONFIRMED] standard Customer Order header IDO = SL.SLCos
[CONFIRMED] standard Customer Order line IDO = SL.SLCoitems
[REVIEWED]  SL.SLCos method-name list
[CONFIRMED] CreateCoAndLines is Extension Class - Standard Method, not SP
[CONFIRMED] CreateCoAndLines parameters = CoAndLineInfoJson, CoResult
[CONFIRMED] IdoMethodParameters exposes InputFlag, OutputFlag, MessageFlag
[NEXT]      load parameter rows for SLCos / CreateCoAndLines
[NOT STARTED] custom Process/Reprocess method
[NOT STARTED] Customer Order creation
[NOT STARTED] sample CSV import
[NOT STARTED] controlled service IDO receive method
[NOT STARTED] final external REST API contract and Postman collection
```

## Verified Customer Validation

```text
IDO Name      : ue_SMK069TempSales
Method Type   : Stored Procedure - Standard Method
Stored Proc.  : SMK069ValidateCustomerSp
Method Name   : ue_SMK069ValidateCustomerSp
Transactional : checked
Parameters    : SiteRef, CoNum, Infobar
```

Verified outcomes:

```text
Invalid customer → process_status E + validation_msg
Valid customer   → process_status V + validation_msg NULL
```

The method is reusable by the form, CSV/import path, controlled API receive method, and Process/Reprocess action.

## Standard Customer Order Entity Discovery

```text
Header primary collection : SL.SLCos
Line primary collection   : SL.SLCoitems
Collection Name           : blank / not assigned on both forms
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

The earlier `SL.SLCustomers / oCustomers` screenshot belonged to the Customers form and is not a Customer Order IDO.

## SL.SLCos Method Discovery

Creation-related candidates found in tenant metadata:

```text
CreateCoAndLines
NewCustomerOrderValidSp
CreateCoColSp
CoCustomerValidSp
CoCustomerValid2Sp
CoCustSeqValidSp
VerifyCoCustNumSp
CoNextKeyDelSp
SumCoSp
```

`CreateCoAndLines` was selected for first contract inspection because its name explicitly references both header and lines.

Evidence:

```text
tests/evidence/2026-07-30-slcoss-header-method-list.md
```

## Confirmed CreateCoAndLines Metadata

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

Parameters:

| Sequence | Parameter | Tenant Type |
| ---: | --- | --- |
| 1 | `CoAndLineInfoJson` | `VARIANT` |
| 2 | `CoResult` | `VARIANT` |

Custom Load Method Output Properties is blank because this is a standard method.

Evidence:

```text
tests/evidence/2026-07-30-create-co-and-lines-parameters.md
```

Current inference, not yet final contract:

```text
CoAndLineInfoJson : likely JSON input for header and lines
CoResult          : likely result/status output
```

The exact JSON schema and creation behavior remain unconfirmed.

## IdoMethodParameters Metadata Discovery

The first read-only route failed:

```text
/IDORequestService/ido/info/IdoMethodParameters
→ HTTP 500 generic ASP.NET Runtime Error
```

The REST v1 IDOInfo fallback succeeded and confirmed these relevant properties:

```text
CollectionName
MethodName
ParameterName
Sequence
DataType
InputFlag
OutputFlag
MessageFlag
```

Evidence:

```text
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md
```

No business method was executed and no Customer Order was created.

## Immediate Next Step

Perform only this read-only request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Expected parameter rows:

```text
CoAndLineInfoJson
CoResult
```

Returned property order:

```text
1. CollectionName
2. MethodName
3. ParameterName
4. Sequence
5. DataType
6. InputFlag
7. OutputFlag
8. MessageFlag
```

Do not invoke `CreateCoAndLines`, inspect another business method, create Process logic, create Customer Orders, import CSV, or create the receive API method during this step.

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

Direct SQL insertion into `co_mst` or `coitem_mst` remains prohibited.

## Development Rules

1. Work one small step at a time.
2. Use tenant screenshots and actual metadata as authority.
3. Distinguish metadata object names from physical SQL names.
4. Do not mark a step completed until tenant evidence confirms it.
5. Keep validation and processing reusable by form, CSV, and REST API paths.
6. Never direct-insert into `co_mst` or `coitem_mst`.
7. Item mapping and broader item validation remain postponed.
8. Distinguish Stored Procedure methods from Extension Class methods.

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
implementation/15-idomethodparameters-metadata-fallback.md
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
tests/evidence/2026-07-30-slcoss-header-method-list.md
tests/evidence/2026-07-30-create-co-and-lines-parameters.md
tests/evidence/2026-07-30-idomethodparameters-info-endpoint-500.md
tests/evidence/2026-07-30-idomethodparameters-idoinfo-properties.md
CHANGELOG.md
```

## Ready-to-Paste New-Chat Prompt

```text
Lanjutkan repository private youhunt/api-pos-syteline sebagai source of truth.

Current status:
- staging, IDO, Error Processing form, Preview, process_status mapping, and customer validation are complete;
- standard Customer Order header IDO = SL.SLCos;
- standard Customer Order line IDO = SL.SLCoitems;
- CreateCoAndLines is an Extension Class - Standard Method, Transactional unchecked, and is not a Stored Procedure;
- its parameters are CoAndLineInfoJson sequence 1 VARIANT and CoResult sequence 2 VARIANT;
- IdoMethodParameters metadata exposes CollectionName, MethodName, ParameterName, Sequence, DataType, InputFlag, OutputFlag, and MessageFlag;
- no standard business method has been executed;
- custom Process/Reprocess, Customer Order creation, controlled service receive method, and final POS API are not complete.

Target remains:
POS/Postman/CSV → controlled service IDO → staging → validation → reusable processing → standard Customer Order processing.

Next step only:
Use the REST v1 Advanced LoadCollection route on IdoMethodParameters, filtered to CollectionName = SLCos and MethodName = CreateCoAndLines, returning the direction flags. Do not invoke CreateCoAndLines or create a Customer Order.
```
