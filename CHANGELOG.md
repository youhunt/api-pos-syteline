## 2026-09-08 — Shipment scheduler: config, retry state, backoff

- Shipment send confirmed working end to end from Postman against `infor_dn`, so the transport investigation is closed;
- withdrew patches 05 and 06 without applying them: `SMK069_ShipmentAPI_mst` now emits `UOM` as a number and `DN_No` as a prefixed string (`P96325`), so the UOM mapping table is unnecessary and the patch would have reverted `@DN_No` to `BIGINT`; both files carry a "DITARIK" header and are kept only as a record of the path taken;
- added `database/patches/2026-09-08-smk069-07-shipment-scheduler-tables.sql`: `ue_SMK069_shipment_config_mst` (endpoint, timeout, batch size, retry policy, master switch) and `ue_SMK069_shipment_retry_mst` (per-shipment attempt state keyed on `SiteRef + ShipmentId`);
- established that `ue_SMK069_shipment_api_log_mst.RetryCount` cannot drive a backoff, because Prepare creates a new log row whenever the previous one is in error, so the counter never grows past 1 for a repeatedly failing shipment;
- added `database/patches/2026-09-08-smk069-08-shipment-scheduler-procs.sql`: `SMK069GetShipmentConfigSp`, `SMK069GetPendingShipmentsSp`, `SMK069RecordShipmentAttemptSp`;
- retry policy is exponential backoff with an attempt budget — default 5 attempts at 15, 30, 60 and 120 minutes, then state `X` and no further automatic sends, so a malformed DN can no longer hit the POS API 24 times a day indefinitely;
- credentials are TaskMan task parameters, not config columns, so no `SELECT` on the config table reveals them; recorded that Mongoose echoes input parameters back in the IDO response, so the method must not be invoked interactively with production credentials;
- kept the scheduling interval out of the stored procedures entirely, per `docs/24` §2 — it belongs to the task schedule;
- did not rewrite `SMK069ShipmentSenderExtension.cs`: `SMK069SendPendingShipments` must live in the same class because Mongoose binds one extension class per IDO, so `docs/29` §5 carries the method to paste in;
- flagged two things to verify before building the task: that the `DN_No` type is `String` end to end after the 7 Sep change, and that `ue_SMK069_shipment_api_log_mst.ShipmentId` can hold `P96325` — if it is an integer, `SiteRef + ShipmentId` stops working as an idempotency key;
- flagged that whether TaskMan can invoke an IDO method directly is unverified in this tenant; if it can only run a stored procedure, the HTTP call needs a different host;
- new document: `docs/29-shipment-scheduler.md`.

## 2026-09-07 — Shipment endpoint corrected to infor_dn; UOM mapping

- POS team confirmed the Shipment endpoint for the Infor direction is `infor_dn`, not `kacs_dn`; every `1009 Invalid params` recorded between 3 and 7 September was a request to the wrong route;
- POS team confirmed `UOM` must be a JSON integer, not a numeric string;
- established that `1010 data is exist` proves the payload passed field validation, since a malformed payload answers `1009`;
- therefore closed the theory that `CUST_CODE`, `WHS_CODE` and `STORE_CODE` needed translating into POS-side codes: the accepted payload carried the SyteLine values `PHD0001`, `P963`, `DEV4` and `R260902058` and all were accepted;
- proposed closing `docs/24` §17 (WHS_CODE not finalized) and §18 (STORE_CODE source) on that evidence;
- confirmed eight-decimal `SHIPMENT_QTY` and `PRICE` are accepted, so they are deliberately left unchanged;
- added `database/patches/2026-09-07-smk069-05-create-pos-uom-map.sql`: new table `ue_SMK069_pos_uom_map_mst` mapping `SiteRef` + `syteline_um` to an integer `pos_uom_code`, seeded empty on purpose because the only value seen so far came from a hand-edited UAT payload rather than the POS team;
- added `database/patches/2026-09-07-smk069-06-shipment-uom-integer.sql`: `SMK069BuildShipmentJsonSp` now emits `UOM` as a number resolved through that table, and refuses to build a payload when any line's `u_m` is unmapped, naming the offending values;
- signature of `SMK069BuildShipmentJsonSp` unchanged, so no IDO method metadata change;
- did not rewrite `SMK069ShipmentSenderExtension.cs`: its hard-coded shipment path is wrong, but the correct base path is still disputed and the class is ~1200 lines of working code — the constant is edited in place once the path is confirmed; for UAT, `SMK069SendOneShipment` already accepts `EndpointUrl` as a parameter;
- open with the POS team: whether the base path is `/inventory/v1/` or `/inventory-phi/v1/`, and how globally unique `DN_NO` must be, given that SyteLine's `shipment_id` restarts at 1 per site while the POS sample used `DN98112`;
- new document: `docs/28-shipment-infor-endpoint-and-uom.md`.

## 2026-09-07 — Multi-error response for POS Receive

- recorded the POS team request: one API call must report every invalid material, not the first one;
- reproduced with a three-line `DEV4-202` payload where only `AA00015C` was returned and `AH00034A` surfaced only after the first item was removed;
- identified the cause: `SMK069ReceivePosSalesJsonSp` reduced the error set to `SELECT TOP (1)` before raising it;
- received the tenant source and confirmed the procedure is a pure wrapper over Core, with no additional business logic at risk from a `CREATE OR ALTER`;
- added `database/patches/2026-09-07-smk069-04-public-receive-multi-error.sql`: the message is now built with `FOR XML PATH` over every offending row, prefixed with the offending row count, and truncated with an explicit note when it exceeds the `THROW` limit;
- added a `POS-103` branch so an unregistered material reads as such instead of falling through to the generic `POS-101` text;
- excluded atomic-order sibling rows (`[POS-203]`) from the list whenever the batch has at least one real error, so valid lines do not bury the materials that actually need fixing; the filter is skipped when a batch contains nothing else;
- established that `SMK069ReceivePosSalesJsonCoreSp` needs no change: its `TOP (10)` cap governs only its own `@Infobar`, which `THROW` discards;
- kept `THROW 51069` deliberately, so the POS integrator needs no change on their side — `Parameters`/`ReturnValue` therefore stay null and the list remains capped at 2048 characters;
- signature unchanged, so no IDO method metadata change and the Postman collection keeps working;
- recorded that `[POS-101]` still cannot name the offending field, because it is raised when the mapping view returns no row at all; per-key match flags in the view would be a separate change;
- incidental finding: `whse = P963` validated successfully, so `ue_SMK069_pos_sales_inbound_mapping_view` already translates POS-side warehouse codes — a lead for the Shipment `WHS_CODE` / `1009 Invalid params` issue in `docs/24` §17;
- deferred to a later patch, pending agreement with the POS team: `RETURN 16` instead of `THROW` so the counts and an uncapped list reach the caller, plus a structured `@ErrorsJson` output;
- new document: `docs/27-pos-receive-multi-error-response.md`.

## 2026-09-04 — Partial success + CSV to Customer Order in one call

- added `SMK069ProcessBatchCustomerOrdersSp`: the order loop shared by the JSON and CSV paths;
- the loop now skips orders already at `process_status = 'P'`, so a retry no longer counts
  pre-existing Customer Orders as newly created;
- added `@CreatedCoNums` output to all three procedures, appended with a default so existing
  IDO method metadata keeps binding by position;
- reduced both wrapper validation gates to `@TransferredRows = 0`;
- fixed the defect where a batch with one invalid order left every valid order stranded in
  `ue_SMK069_temp_sales_mst` at status `V`, unreachable by retry under the same or a new
  `batch_id` (`[POS-204]`);
- removed `THROW 51071`; per-order Process failures are reported through the OUTPUT
  parameters instead of aborting the T-SQL batch and discarding them;
- kept `THROW 51070` for total failure only;
- `SMK069RunCsvTestBatchSp` now calls Process and persists real `processed_orders` /
  `process_error_orders`, which were previously written as literal zeros;
- added `batch_status = 'P'` for partial batches; `upload_status` is now per row;
- documented the new result contract: a partial batch returns `0` with the marker `PARTIAL`
  in the Infobar, so callers must branch on `ProcessErrors` / `ValidationErrorOrders` rather
  than on `ReturnValue` alone;
- confirmed `ue_SMK069TempSales.SMK069ReceiveAndProcessPosSalesJsonSp` is NOT Transactional,
  which is required because `SMK069ProcessCustomerOrderSp` issues an unqualified
  `ROLLBACK TRANSACTION` in its CATCH block;
- `SMK069ReceivePosSalesJsonCoreSp`, `SMK069ProcessCustomerOrderSp` and
  `SMK069ImportCsvFileSp` were not modified;
- new documents: `docs/26-partial-success-and-csv-to-customer-order.md`,
  `implementation/25-deploy-partial-success-and-csv-to-co.md`.

## 2026-09-03 — Add KACS Shipment success contract mode

- confirmed Shipment auth header is `Authorization: Bearer <token>`;
- kept the actual bearer token out of source control;
- added `KACS_V1` success mode requiring HTTP 201 + JSON code 200 + message Success;
- documented controlled positive DN22 UAT inputs;
- duplicate HTTP 400 / code 1010 remains an error pending explicit reconciliation policy.

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
