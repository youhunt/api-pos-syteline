## 2026-09-03 — Record KACS/POS Shipment API contract

- recorded UAT/production base URLs and login/shipment paths from the supplied KACS API document;
- recorded Shipment success as HTTP 201 + body code 200 + message Success;
- recorded duplicate response as HTTP 400 + code 1010 + message data is exist;
- documented that the token header scheme is still not specified by the source document;
- explicitly kept login credentials out of Git.

## 2026-09-03 — Confirm Shipment four-method service IDO wiring

- confirmed `ue_SMK069ShipmentTransport` exposes Prepare, Complete, HTTP transport, and one-Shipment orchestration methods;
- confirmed Complete parameter order matches tenant stored procedure metadata;
- next gate is cache refresh and safe DN22 negative UAT.

## 2026-09-03 — Confirm Shipment extension assembly build in tenant

- confirmed `ue_SMK069ShipmentExtensions` compiled and updated successfully;
- recorded tenant evidence for the Mongoose IDO Invoke implementation;
- next step is service IDO + method metadata wiring, then DN22 negative UAT.

## 2026-09-03 — Replace Shipment direct DB calls with Mongoose IDO Invoke

- removed the Shipment extension class dependency on `System.Data` and `ApplicationDB`;
- switched Prepare/Complete orchestration to `Context.Commands.Invoke`;
- documented two Stored Procedure methods on `ue_SMK069ShipmentTransport`;
- preserved the stable SQL stored procedures and Site-context behavior;
- retired the tenant workaround requiring `System.Data.dll`.

## 2026-09-03 — Document Shipment extension System.Data build dependency

- recorded the tenant Build From Source compiler failure caused by a missing `System.Data.dll` reference;
- updated the Shipment one-sender deployment guide to preserve default references and append `System.Data.dll`;
- no Shipment business/source logic changed.

## 2026-09-03 — Shipment one-Shipment server-side orchestration

- confirmed exact tenant signatures for Shipment Build, Prepare and Complete;
- confirmed Shipment view `site_ref` and DN22 four-lot detail;
- added `SMK069SendOneShipment` orchestration: Prepare -> HTTP -> Complete;
- kept the IDO method non-transactional by design for the external HTTP boundary;
- ensured handled HTTP/business failures still execute Complete with failure;
- preserved the rule that only Complete may set Shipment `api_post=1`.

## 2026-09-03 — Shipment readiness audit Query Execution variant

- added a read-only Query Execution version of the Shipment readiness audit;
- documented that Apply Database does not show SELECT result grids like SSMS;
- split the audit into numbered result queries, including active Site, SP metadata,
  view columns, pending Shipment snapshot, DN22 lot detail, and log collision checks.

## 2026-09-03 — Shipment server-side transport foundation

- added `SMK069ShipmentSenderExtension.cs` for server-side POS Shipment HTTP POST;
- kept transport separate from the stable Build/Prepare/Complete SQL lifecycle;
- added conservative `UNCONFIRMED` response mode so HTTP 2xx does not automatically mean posted;
- added runtime auth-header inputs without committing credentials;
- added a read-only production-readiness audit for Site context, SP parameters, Shipment view, pending data, and log key collisions;
- added the current DN22 lot-level UAT payload;
- updated the current handoff with the next orchestration step.

# Changelog

All notable changes to this repository will be documented in this file.

## [Unreleased]

### SMK069 Handoff — 2026-09-03

- Added current continuation document:
  `docs/24-smk069-current-handoff-2026-09-03.md`.
- Recorded POS inbound as the stable baseline and preserved the existing `POS-xxx` result-code contract.
- Recorded the current site-aware standard using `CONTEXT_INFO()` + `SetSiteSp` and active-site filtering for SMK069 `_mst` access.
- Recorded the 3-Sep POS site-aware hardening V2 patch basis:
  Core V2.4.8, Public V2.4.8, Process V2.8.3, CSV V2.8.1, E2E V1.3.
- Recorded current Shipment outbound objects:
  `SMK069_ShipmentAPI_mst`,
  `SMK069BuildShipmentJsonSp`,
  `SMK069PrepareShipmentSendSp`,
  `SMK069CompleteShipmentSendSp`,
  and `ue_SMK069_shipment_api_log_mst`.
- Recorded Shipment lot-level JSON behavior, multiple-DOC_NO rejection, and `SiteRef + ShipmentId` logical idempotency.
- Clarified that `SMK SHIPMENT API TEST` is UAT/debug only.
- Reconfirmed production Shipment requirement:
  automatic server-side execution every 1 hour by default, with adjustable interval.
- Open items remain the actual POS Shipment endpoint/auth/response contract,
  final WHS_CODE / STORE_CODE mapping, server-side HTTP sender, retry orchestration,
  scheduler, and final UAT.


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
