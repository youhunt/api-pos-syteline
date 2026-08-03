# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- Staging-table, IDO, Error Processing form, validation, Customer Order discovery, and controlled runtime-probe documentation.
- Controlled Customer Order processing procedure:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

- Cloud end-to-end success evidence:

```text
tests/evidence/2026-08-03-smk069-cloud-e2e-customer-order-success.md
```

- Supporting runtime evidence and context patch:

```text
tests/evidence/2026-07-31-smk069-tax-master-contract.md
tests/evidence/2026-07-31-smk069-tax-code-runtime.md
tests/evidence/2026-07-31-co-mstiup-site-context-source.md
tests/evidence/2026-07-31-delete-remote-notes-call-chain.md
database/patches/2026-07-31-smk069-unicode-site-context-fix.sql
```

### Changed

- `CreateCoAndLines` discovery remains paused; controlled direct stored-procedure processing is active.
- The active procedure contract is:

```text
@SiteRef
@SourceCoNum
@CustSeq
@ProcessedBy
@CreatedCoNum OUTPUT
@Success OUTPUT
@Infobar OUTPUT
```

- Generated Customer Order number pattern remains `COYYMM####`.
- Source order remains stored in `co_mst.cust_po` for idempotent lookup.
- Portal-only unavailable `Uf_*` columns remain excluded.
- SQL session site context is supplied using the Unicode encoding required by `dbo.GetSiteContext()`.
- Standard SyteLine triggers and constraints remain enabled.
- Valid Cloud test master data:

```text
SiteRef  : DEFAULT
Customer : C000001
Item     : AA00001
Whse     : MAIN
U/M      : KG
Terms    : CBD
Tax Code : PPN11%
```

### Cloud End-to-End Result — 2026-08-03

```text
REST additem
→ TEST000002 inserted with status N
→ ue_SMK069ValidateCustomerSp returned 0
→ staging changed to V
→ SMK069ProcessCustomerOrderSp returned Success = 1
→ generated Customer Order CO26080001
→ staging changed to P
→ SLCos header verified
→ SLCoitems line verified
```

Confirmed header:

```text
CoNum      : CO26080001
CustNum    : C000001
CustPo     : TEST000002
Whse       : MAIN
TermsCode  : CBD
TaxCode1   : PPN11%
Stat       : P
Price      : 11100.00000000
```

Confirmed line:

```text
CoNum       : CO26080001
CoLine      : 1
Item        : AA00001
QtyOrdered  : 1.00000000
UM          : KG
Price       : 10000.00000000
Whse        : MAIN
```

The header IDO did not expose a usable `SiteRef` property in the final verification request. `SLCoitems.SiteRef` returned null; this is recorded as an IDO property exposure/mapping observation and is not treated as proof that the physical `coitem_mst.site_ref` column is null.

The returned header price `11100` is numerically consistent with line price `10000` plus 11% tax. Functional confirmation is still required on whether the external contract should expose net, tax, and gross totals separately.

### Current SMK069 Status

```text
[COMPLETED] staging table and process-control columns
[COMPLETED] ue_SMK069TempSales IDO
[COMPLETED] Error Processing base form and Preview
[COMPLETED] customer validation
[COMPLETED] Cloud REST staging insert
[COMPLETED] Cloud validation N → V
[COMPLETED] Cloud Customer Order processing V → P
[CONFIRMED] Customer Order header CO26080001 through SLCos
[CONFIRMED] Customer Order line 1 through SLCoitems
[CONFIRMED] source order TEST000002 stored as CustPo
[CONFIRMED] generated number pattern COYYMM####
[NO BLOCKER] single-line Cloud happy path
[PENDING] idempotent reprocess test
[PENDING] multi-line order test
[PENDING] negative validation and rollback tests
[PENDING] Process/Reprocess form button integration
[PENDING] controlled receive API
[PENDING] final external POS API contract
[PENDING] functional confirmation of net/tax/gross totals
[PENDING] synchronize the exact final Cloud SP source into the repository SQL file
```

### Planned

- Re-run `TEST000002` to confirm idempotent behavior and prevent duplicate Customer Orders.
- Test one source order containing multiple staging lines.
- Confirm physical `coitem_mst.site_ref` directly when tenant SQL access is available.
- Confirm whether API totals should be net, tax, and gross fields rather than one ambiguous header price.
- Connect the Process/Reprocess form button to the confirmed IDO method.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
