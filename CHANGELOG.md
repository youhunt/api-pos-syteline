# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### Added

- Controlled Customer Order procedure:

```text
database/procedures/SMK069ProcessCustomerOrderSp.sql
```

- Cloud runtime evidence:

```text
tests/evidence/2026-08-03-smk069-cloud-e2e-customer-order-success.md
tests/evidence/2026-08-03-smk069-cloud-idempotent-reprocess-success.md
```

- Supporting tax, site-context, and standard-trigger evidence under `tests/evidence` and `database/patches`.

### Changed

- `CreateCoAndLines` discovery remains paused; controlled direct stored-procedure processing is active.
- Active procedure contract:

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
- Source order is stored in `co_mst.cust_po` for idempotent lookup.
- SQL session site context uses the Unicode encoding required by `dbo.GetSiteContext()`.
- Standard SyteLine triggers and constraints remain enabled.

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

The header IDO did not expose a usable `SiteRef` property. `SLCoitems.SiteRef` returned null; this is treated as an IDO property exposure/mapping observation, not proof that physical `coitem_mst.site_ref` is null.

### Cloud Idempotency Result — 2026-08-03

The processing method was called again with the same source order:

```text
SiteRef     : DEFAULT
SourceCoNum : TEST000002
```

Confirmed response:

```text
ReturnValue  : 0
CreatedCoNum : CO26080001
Success      : 1
Infobar      : Customer Order CO26080001 sudah pernah dibuat; staging disinkronkan menjadi Processed.
```

The tenant runtime reused the existing Customer Order and entered the idempotent synchronization branch instead of returning a new generated number.

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
[COMPLETED] idempotent reprocess returned existing CO26080001
[NO BLOCKER] single-line Cloud happy path
[PENDING] independent duplicate header/line count verification
[PENDING] multi-line order test
[PENDING] negative validation and rollback tests
[PENDING] Process/Reprocess form button integration
[PENDING] controlled receive API
[PENDING] final external POS API contract
[PENDING] functional confirmation of net/tax/gross totals
[PENDING] synchronize exact final Cloud SP source into repository SQL file
```

### Planned

- Verify through read-only IDO queries that only one header with `CustPo = TEST000002` and one line for `CO26080001` exist.
- Test one source order containing multiple staging lines.
- Confirm physical `coitem_mst.site_ref` when tenant SQL access is available.
- Confirm external API net, tax, and gross amount semantics.
- Connect the Process/Reprocess form button to the confirmed IDO method.

## [0.1.0] — 2026-07-23

### Added

- Initial project documentation, architecture, database design, API draft, financial posting options, development roadmap, and open-questions checklist.
