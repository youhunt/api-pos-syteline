# 16 — Alignment with SMK069 Temporary Sales Specification

## Source Requirement

The requirement dated 20 July 2026 defines this target flow:

```text
Pizza Hut POS
→ POS Sales Data
→ Summarize Sales Data
→ Integration API
→ SyteLine ERP Sales Data
→ SyteLine ERP Sales Order Processing
```

The requested deliverables are:

1. temporary table `SMK069_temp_sales_mst`;
2. UI `SMK API SALES ERROR PROCESSING`;
3. validation that `cust_num` exists in `customer_mst`;
4. Preview by Order Date / CO Number;
5. Process button for posting or reprocessing;
6. creation of Customer Order header and lines in standard SyteLine tables `co_mst` and `coitem_mst`.

## Phase-1 Input Decision

The official POS file layout is not yet available. The agreed first development phase uses a CSV file to load data into the temporary table.

```text
POS sample CSV
→ load into SMK069_temp_sales_mst
→ validate
→ review errors
→ process to Customer Order
```

The final API contract and POS field mapping will be adapted later when the official POS file is received. The staging, validation, form, and Customer Order processing developed now remain reusable.

## Confirmed Corrections

The specification author confirmed two corrections on 28 July 2026:

```text
1. Header total must use SUM(unit_price * qty_ordered)
2. cost must be obtained from item_mst
```

Implementation consequences:

```text
- remove cost from SMK069_temp_sales_mst
- retain unit_price as source sales price
- obtain item cost during Customer Order processing
```

## Target Architecture for Current Phase

```text
Pizza Hut POS sample CSV
        ↓
CSV import / integration process
        ↓
dbo.ue_SMK069_temp_sales_mst
        ↓
ue_SMK069TempSales IDO
        ↓
ue_SMK069APISalesErrorProcessing form
        ↓
Customer validation and error review
        ↓
Controlled Customer Order processing
        ↓
co_mst + coitem_mst
```

The standard `co_mst` and `coitem_mst` tables are the intended result. The implementation should use supported SyteLine Customer Order business processing instead of uncontrolled direct SQL insertion wherever the tenant provides a suitable standard IDO or business method.

## Implemented Staging Fields

The implemented business fields are:

```text
SiteRef
cust_num
order_date
terms_code
co_num
co_line
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
```

`SiteRef` is used for the source requirement `site_ref` and the Mongoose site context. A separate `site_ref` column is not created.

## Technical Control Fields

The following fields were added because the requirement asks for error control and reprocessing:

```text
process_status
validation_msg
error_msg
retry_count
processed_date
processed_by
```

Status values:

```text
N = New
V = Valid
E = Error
P = Processed
C = Cancelled
```

## Current Object Names

```text
Metadata table : SMK069_temp_sales_mst
Physical table : dbo.ue_SMK069_temp_sales_mst
Entity IDO     : ue_SMK069TempSales
Planned form   : ue_SMK069APISalesErrorProcessing
Form caption   : SMK API SALES ERROR PROCESSING
```

## Current Progress

```text
[COMPLETED] table created
[COMPLETED] cost removed from implemented design
[COMPLETED] six process-control columns added
[COMPLETED] ue_SMK069TempSales IDO created
[COMPLETED] IDO updated/resynchronized after table changes
[NEXT]      create ue_SMK069APISalesErrorProcessing form
[PENDING]   Order Date / CO Number Preview filters
[PENDING]   customer validation
[PENDING]   Process/reprocess method
[PENDING]   Customer Order header and line creation
[PENDING]   official POS CSV mapping
[PENDING]   final API documentation based on the Nava_TempJournal format
```

## Development Order

```text
1. Create SMK069_temp_sales_mst                           COMPLETED
2. Add process-control columns                            COMPLETED
3. Create and update ue_SMK069TempSales IDO              COMPLETED
4. Create ue_SMK069APISalesErrorProcessing form          NEXT
5. Add Order Date / CO Number Preview filters            PENDING
6. Add customer validation                               PENDING
7. Add Process / Reprocess method                        PENDING
8. Create Customer Order header and lines                PENDING
9. Prepare sample CSV and import process                 PENDING
10. Prepare technical API document and Postman examples  PENDING
```

## Scope Control

Item mapping and broader item-level validation remain postponed. Initial validation follows the source specification and starts with:

```text
cust_num must exist in customer_mst
```

Further validations will be added incrementally after the first Customer Order flow is working.