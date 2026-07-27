# 16 — Alignment with SMK069 Temporary Sales Specification

## Source Requirement

The approved requirement dated 20 July 2026 defines this production flow:

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
5. Process button to retry posting;
6. creation of Customer Order header and lines in `co_mst` and `coitem_mst`.

## Development Decision

The existing integration foundation remains in use:

```text
ue_SMKRSCPosInbounds
ue_SMKRSCPosBatches
ue_SMKRSCPosProcessLogs
ue_SMKRSCPosIntegration
SMKRSCPosImportCenter
```

The item mapping work is paused until the SMK069 staging, customer validation, error UI, and Customer Order processing flow are implemented.

## Target Architecture

```text
Pizza Hut POS / Integration API
        ↓
ue_SMKRSCPosInbounds
        ↓
ue_SMKRSCPosBatches
        ↓
dbo.ue_SMK069_temp_sales_mst
        ↓
Customer validation and error processing UI
        ↓
Controlled Customer Order processing
        ↓
co_mst + coitem_mst
```

Manual CSV attachment remains available only for PoC, UAT, troubleshooting, and fallback.

## Scope Order

```text
1. Create SMK069_temp_sales_mst
2. Create ue_SMK069TempSales IDO
3. Build SMK API Sales Error Processing UI
4. Implement customer validation
5. Implement Preview
6. Implement Process / Reprocess
7. Create Customer Order header and lines
8. Resume item-level validation and mapping
```

## Source Fields

The requirement explicitly defines:

```text
site_ref
cust_num
order_date
terms_code
co_num
co_line
cost
unit_price
tax_code1
exch_rate
whse
item
qty_ordered
due_date
u_m
```

## Technical Control Fields

The requirement asks for error control and reprocessing but does not define the fields needed to support it. The implementation therefore adds clearly separated technical fields:

```text
request_id
batch_num
process_stat
validation_msg
error_msg
retry_count
processed_date
processed_by
```

These fields support filtering, audit, retry, and status tracking without changing the business mapping defined by the requirement.
