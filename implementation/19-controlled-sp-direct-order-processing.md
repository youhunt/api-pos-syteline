# Implementation 19 — Controlled Stored Procedure Customer Order Processing

## Status

```text
Decision date                  : 31 July 2026
Cloud end-to-end success       : 3 August 2026
Cloud idempotency success      : 3 August 2026
Processing direction           : ACTIVE
Previous CreateCoAndLines path : PAUSED
Direct target tables           : dbo.co_mst and dbo.coitem_mst
Procedure                      : dbo.SMK069ProcessCustomerOrderSp
Generated Customer Order       : CO26080001
Source order                   : TEST000002
Staging final status           : P
Header verification            : CONFIRMED through SLCos
Line verification              : CONFIRMED through SLCoitems
Idempotent reprocess            : CONFIRMED
Current blocker                : NONE for single-line Cloud happy path
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
→ verify through SLCos and SLCoitems
→ call processing method again
→ return existing CO26080001 without generating a new order
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

## First Customer Order Processing Result

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

The header IDO query does not expose a usable `SiteRef` property in this tenant.

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

`SiteRef = null` in the IDO response is recorded as a property exposure/mapping observation and is not treated as proof that physical `coitem_mst.site_ref` is null.

## Confirmed Idempotent Reprocess

The same processing endpoint was invoked again for `DEFAULT / TEST000002`.

Confirmed response:

```text
ReturnValue  : 0
CreatedCoNum : CO26080001
Success      : 1
Infobar      : Customer Order CO26080001 sudah pernah dibuat; staging disinkronkan menjadi Processed.
```

This proves the Cloud runtime reached the existing-order branch and returned the original Customer Order instead of generating a new number. The idempotent lookup is based on:

```text
site_ref + cust_num + cust_po/source co_num
```

A final read-only count query is still useful as independent evidence that only one header and one line exist.

## Price Observation Requiring Functional Confirmation

```text
Line net amount       : 10000
Header returned Price : 11100
Difference            : 1100
Tax Code              : PPN11%
```

The result is numerically consistent with 11% tax being added. Functional confirmation is required on whether the external contract should expose net, tax, and gross values separately.

## Implemented Controls

```text
1. SET NOCOUNT ON and SET XACT_ABORT ON.
2. Explicit TRY / TRANSACTION / COMMIT / CATCH / ROLLBACK.
3. Standard triggers and constraints remain enabled.
4. Staging group locked with UPDLOCK + HOLDLOCK.
5. Customer, date, warehouse, terms, tax, item, quantity, price, and U/M validation.
6. Cost and item data retrieved from item_mst.
7. Concurrency-safe numbering through transaction-owned sp_getapplock.
8. Set-based insertion of all lines using one generated co_num.
9. Idempotent lookup through site_ref + cust_num + cust_po.
10. Existing-order line-count, item, and quantity comparison.
11. Failure status written after rollback when staging rows exist.
12. SQL session site context supplied in Unicode form and restored afterward.
```

## Resolved Runtime History

```text
1. 50003 — staging group not found
2. 50020 — dummy item TEST-ITEM-001 not found
3. DeleteRemoteNotesSp replication rule error
4. Tax-code lookup error during local/backup testing
5. Unicode site-context correction applied
6. Cloud single-line end-to-end test completed
7. Cloud idempotent reprocess completed
```

## Remaining Controlled Tests

```text
[COMPLETED] idempotent reprocess of TEST000002
[PENDING] independent duplicate header/line count verification
[PENDING] multi-line source order
[PENDING] invalid warehouse, terms, U/M, and tax negative tests
[PENDING] transaction rollback test after header insertion
[PENDING] Process/Reprocess form button integration
[PENDING] controlled receive API method
[PENDING] final external POS payload and response contract
[PENDING] functional confirmation of net/tax/gross semantics
[PENDING] synchronize exact final tenant SP source into repository SQL
```

## Evidence

```text
tests/evidence/2026-08-03-smk069-cloud-e2e-customer-order-success.md
tests/evidence/2026-08-03-smk069-cloud-idempotent-reprocess-success.md
tests/evidence/2026-07-31-smk069-tax-master-contract.md
tests/evidence/2026-07-31-smk069-tax-code-runtime.md
tests/evidence/2026-07-31-co-mstiup-site-context-source.md
tests/evidence/2026-07-31-delete-remote-notes-call-chain.md
database/patches/2026-07-31-smk069-unicode-site-context-fix.sql
database/procedures/SMK069ProcessCustomerOrderSp.sql
```
