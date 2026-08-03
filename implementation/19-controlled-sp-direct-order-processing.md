# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                     : 31 July 2026
Cloud end-to-end success          : 3 August 2026
Processing direction              : ACTIVE
Previous CreateCoAndLines path    : PAUSED
Direct target tables              : dbo.co_mst and dbo.coitem_mst
Consolidated procedure            : COMPILED AND EXECUTED IN CLOUD
Generated Customer Order          : CO26080001
Source order                      : TEST000002
Staging final status              : P
Customer Order header             : CONFIRMED THROUGH SLCos
Customer Order line               : CONFIRMED THROUGH SLCoitems
Current blocker                   : NONE FOR SINGLE-LINE CLOUD HAPPY PATH
```

## Confirmed Cloud Flow

```text
REST additem
→ dbo.ue_SMK069_temp_sales_mst, status N
→ dbo.ue_SMK069ValidateCustomerSp
→ staging status V
→ dbo.SMK069ProcessCustomerOrderSp
→ insert dbo.co_mst
→ insert dbo.coitem_mst
→ staging status P
→ REST verification through SLCos and SLCoitems
```

Failure flow remains:

```text
validation, trigger, framework, or SQL failure
→ rollback header, lines, and success-status changes
→ update matching staging rows to E after rollback
→ store error_msg
→ increment retry_count
```

## Tenant-confirmed Procedure Contract

```sql
CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   CoNumType,
    @CustSeq       CustSeqType = 0,
    @ProcessedBy   UsernameType = NULL,
    @CreatedCoNum  CoNumType OUTPUT,
    @Success       ListYesNoType OUTPUT,
    @Infobar       InfobarType OUTPUT
```

Removed from the active contract:

```text
@Sparepart
@PickupDate
@StartTime
@EndTime
```

Generated-number pattern:

```text
COYYMM####
```

The source/POS order number remains in staging `co_num` and is stored in `co_mst.cust_po` for idempotent lookup.

## Confirmed Test Data

```text
SiteRef       : DEFAULT
SourceCoNum   : TEST000002
CustNum       : C000001
CoLine        : 1
Item          : AA00001
QtyOrdered    : 1
UM            : KG
UnitPrice     : 10000
TaxCode1      : PPN11%
Whse          : MAIN
TermsCode     : CBD
```

## Customer Validation Result

Endpoint:

```text
/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
```

Result:

```text
ReturnValue    : 0
Infobar        : empty
process_status : V
validation_msg : null
error_msg      : null
```

## Customer Order Processing Result

Endpoint:

```text
/json/method/ue_SMK069TempSales/SMK069ProcessCustomerOrderSp?parms=DEFAULT,TEST000002,0,,,0,
```

Result:

```text
ReturnValue  : 0
CreatedCoNum : CO26080001
Success      : 1
Infobar      : Customer Order CO26080001 berhasil dibuat dari source order TEST000002.
```

## Final Staging State

```text
process_status : P
validation_msg : null
error_msg      : null
processed_date : populated
processed_by   : BRONZECLEVEROX_TRN_CSI_AIO_0
```

## Standard Customer Order Header Verification

IDO: `SLCos`

```text
CoNum      : CO26080001
CustNum    : C000001
CustPo     : TEST000002
OrderDate  : 2026-08-03
Whse       : MAIN
TermsCode  : CBD
TaxCode1   : PPN11%
Stat       : P
Price      : 11100.00000000
```

The header verification IDO query does not expose a usable `SiteRef` property in this tenant and therefore does not include it in the final request.

## Standard Customer Order Line Verification

IDO: `SLCoitems`

```text
CoNum       : CO26080001
CoLine      : 1
Item        : AA00001
QtyOrdered  : 1.00000000
UM          : KG
Price       : 10000.00000000
Whse        : MAIN
SiteRef     : null in IDO response
```

`SiteRef = null` in the `SLCoitems` response is an IDO property exposure/mapping observation. It is not treated as proof that the physical `coitem_mst.site_ref` value is null.

## Price Observation Requiring Functional Confirmation

```text
Line net amount       : 10000
Header returned Price : 11100
Difference            : 1100
Tax Code              : PPN11%
```

The result is numerically consistent with 11% tax being added. The earlier technical rule stated header price as `SUM(unit_price * qty_ordered)`, while the standard header IDO returns the tax-inclusive value. Finance/functional confirmation is required on whether the expected external contract should report net amount, tax amount, and gross amount separately.

## Header-to-Line Relationship

```text
co_mst.co_num     = CO26080001
coitem_mst.co_num = CO26080001
co_mst.cust_po    = TEST000002
```

No identity lookup or follow-up number generation is required.

## Current Header Mapping

```text
co_num
cust_num
cust_po                  ← source/POS co_num
cust_seq
whse
order_date
curr_code
site_ref
contact
phone
terms_code
tax_code1
end_user_type
orig_site
include_tax_in_price
cost
matl_cost_t
price
```

## Current Line Mapping

```text
co_num
co_line
item
qty_ordered
u_m
due_date
price
site_ref
whse
qty_ordered_conv
cust_seq
co_cust_num
ship_site
co_orig_site
description
cost
cgs_total
price_conv
matl_cost
cost_conv
matl_cost_conv
```

Portal-only unavailable `Uf_*` fields are not used.

## Implemented Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit TRY / TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. No global trigger disable/enable.
4. No NOCHECK/CHECK constraint changes.
5. Staging group locked with UPDLOCK + HOLDLOCK.
6. Customer, date, warehouse, terms, tax, item, quantity, price, and U/M validation.
7. Cost, material cost, description, and fallback U/M retrieved from item_mst.
8. Concurrency-safe numbering through transaction-owned sp_getapplock.
9. Set-based insertion of all lines using one generated co_num.
10. Idempotent lookup through site_ref + cust_num + cust_po.
11. Failure status written after rollback when matching staging rows exist.
12. Output parameters return success, generated co_num, and Infobar.
13. SQL session site context is supplied in Unicode form before standard inserts and restored afterward.
14. Standard SyteLine triggers remain enabled.
```

## Resolved Runtime History

```text
1. 50003 — staging group not found
2. 50020 — dummy item TEST-ITEM-001 not found
3. DeleteRemoteNotesSp replication rule error
4. Tax-code lookup error during local/backup testing
5. Unicode site-context correction applied
6. Cloud test used valid master data and completed successfully
```

The earlier replication and tax errors are no longer blockers for the confirmed Cloud happy path.

## Remaining Controlled Tests

```text
[PENDING] idempotent reprocess of TEST000002 without duplicate Customer Order
[PENDING] multi-line source order
[PENDING] invalid warehouse, terms, U/M, and tax negative tests
[PENDING] transaction rollback test after header insertion
[PENDING] Process/Reprocess form button integration
[PENDING] controlled receive API method
[PENDING] final external POS payload and response contract
[PENDING] functional confirmation of net/tax/gross amount semantics
[PENDING] synchronize the exact final tenant SP source back into the repository SQL file
```

## Evidence

```text
tests/evidence/2026-08-03-smk069-cloud-e2e-customer-order-success.md
tests/evidence/2026-07-31-smk069-tax-master-contract.md
tests/evidence/2026-07-31-smk069-tax-code-runtime.md
tests/evidence/2026-07-31-co-mstiup-site-context-source.md
tests/evidence/2026-07-31-delete-remote-notes-call-chain.md
database/patches/2026-07-31-smk069-unicode-site-context-fix.sql
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
