# SMK069 Shipment — PROD Migration Pack

Prepared: 2026-09-24  
Scope: **Shipment outbound SyteLine -> POS API only**

This folder is the PROD cutover package. It deliberately does **not** include POS inbound / CSV-to-CO objects.

Companion operator documents:

```text
EXPORT_FROM_UAT_CHECKLIST.md
ROLLBACK.md
```

## Critical rule

Do not treat the historical UAT patch folder as a PROD run list.

These UAT-specific / obsolete files must **not** be applied to PROD:

```text
2026-09-09-smk069-16-fix-shipment-endpoint-and-hold-scheduler.sql  -> UAT endpoint
2026-09-09-smk069-17-arm-controlled-uat-p96331.sql                -> UAT DN / arm state
2026-09-10-smk069-18-taskman-runtime-status.sql                   -> withdrawn/no-op
```

Patch 13 is audit only. Patch 12 is a legacy Run Now wait helper and is not referenced by the current REV8 form.

## What must already exist before the incremental pack

The repository still does not contain authoritative standalone current source for every original Shipment baseline object. Therefore a clean PROD tenant must first receive the **exact current UAT baseline** for:

```text
dbo.SMK069_ShipmentAPI_mst
dbo.ue_SMK069_shipment_api_config_mst
dbo.ue_SMK069_shipment_api_log_mst
dbo.SMK069BuildShipmentJsonSp
dbo.SMK069PrepareShipmentSendSp
dbo.SMK069CompleteShipmentSendSp
ue_SMK069ShipmentTransport
SMK069ShipmentTransportExtension
```

Do not rebuild these from stale historical standalone files.

Use `EXPORT_FROM_UAT_CHECKLIST.md` to capture/import the exact current definitions.

### Mongoose-owned custom tables

Create/migrate `ue_SMK069_*` custom tables through the **SQL Tables** form / Mongoose metadata path, not by raw `CREATE TABLE`, so Mongoose application-schema metadata and the standard `Del`, `Insert`, and `UpdatePenultimate` triggers are present. If a physical table was already created by SQL, use **SQL Tables > Update Current Table** before continuing, then verify the generated triggers. The SQL files under `baseline/` for these tables are schema-reference artifacts only, not the authoritative PROD creation path.

If PROD already has that baseline, run `query-select/001-prod-preflight.sql` first and use the incremental Apply Database files only where needed.

## Apply Database order

Each file under `apply-database/` is shaped for the Cloud tenant rule: **one executable batch, no GO**.

Run in numeric order:

```text
010..016  scheduler config columns (skip on clean PROD baseline that already has them)
017       retry table raw-DDL fallback only; clean PROD uses SQL Tables
020..022  scheduler policy procedures
030       schedule table raw-DDL fallback only; clean PROD uses SQL Tables
031..038  schedule seed + control/runner procedures
040..041  dashboard/queue views
050       Prepare DN string contract
060       DOC_NO non-blocking (skip on clean PROD when exact current Build SP baseline is installed)
061       Complete prefixed-DN mapping
070       OPTIONAL Patch 19 only; NOT part of current verified TRN baseline
071       STORE_ORDER_NO non-blocking (skip on clean PROD when exact current Build SP baseline is installed)
072       fixed 1-minute retry, max 1440
073       block PRICE NULL/0/negative before HTTP (skip on clean PROD when exact current Build SP baseline is installed)
080       PROD URL/config template, safe OFF state
090       emergency business-gate stop; use only when needed
```

Before file 080, replace:

```text
__PROD_LOGIN_URL__
__PROD_SHIPMENT_URL__
```

with values confirmed by the POS team. File 080 explicitly rejects UAT URLs and leaves:

```text
Master SchedulerEnabled = 0
HOURLY IsEnabled        = 0
MaxShipments            = 1
```

No username/password belongs in SQL or GitHub.

## Query Select verification

All files under `query-select/` are pure SELECT and have no trailing semicolon:

```text
001-prod-preflight.sql
  baseline/runtime object and rule checks

002-prod-postdeploy-config.sql
  PROD URL/config/retry/safe-OFF validation

003-prod-smoke-retry.sql
  replace __PROD_DN__; verify retry state for controlled DN

004-prod-smoke-api-history.sql
  replace __PROD_DN__; verify HTTP/response history

005-prod-smoke-view.sql
  replace __PROD_DN__; verify source Api_post, qty, price, lot/expiry
```

## Application metadata to migrate from UAT

Migrate the exact current UAT definitions, not reconstructed approximations:

```text
Form
  ue_SMK069ShipmentScheduler
  current behavior = REV8 filter/date-time UX

IDOs
  ue_SMK069ShipmentTransport
  ue_SMK069ShipmentApiConfigs
  ue_SMK069ShipmentSchedules
  ue_SMK069ShipmentRetries
  ue_SMK069ShipmentApiLogs
  ue_SMK069ShipmentSchedulerDashboard
  ue_SMK069ShipmentSchedulerQueue

Built-in runtime read source
  ActiveBGTasks
  do not create a custom replacement

Background Task Definition
  Task Name       = SMK069ShipmentScheduler
  Executable Type = IDOMTH
  Executable Name = ue_SMK069ShipmentTransport.SMK069RunDueShipmentSchedule
  Max Concurrent  = 1
```

Do **not** migrate the current ActiveBGTasks runtime row/task number from UAT. PROD START must create its own recurring instance.

## Extension requirement

PROD must contain the exact current UAT extension source/assembly with all current Shipment methods, including:

```text
SMK069SendPendingShipments
SMK069RunDueShipmentSchedule
SMK069PostShipmentPayload
SMK069SendOneShipment
```

and the idempotent duplicate rule:

```text
Shipment response only:
HTTP 400 + code 1010 + message "data is exist"
=> BusinessSuccess = 1
```

Reference diff:

```text
extension-classes/shipment/SMK069ShipmentDuplicateAlreadyExists.patch
```

The repository `SMK069ShipmentSenderExtension.rev3.cs` is **not** authoritative enough to replace a newer tenant source wholesale. Export/import the exact UAT custom assembly or diff the tenant source first.

## Form artifact

Current sanitized artifact:

```text
SMK069ShipmentScheduler_REV8_FILTER_DATETIME.xml
```

It uses placeholders:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Real PROD credentials must never be committed.

Important: hidden form variables / TaskMan parameters are not encryption. Credential storage for PROD requires explicit operational/security approval. If the current design is retained, inject credentials only in the target tenant/local import artifact and restrict access to task diagnostics.

## Data that must NOT move from UAT to PROD

Do not copy:

```text
ue_SMK069_shipment_retry_mst rows
ue_SMK069_shipment_api_log_mst UAT rows
ue_SMK069_shipment_schedule_mst runtime history fields
ActiveBGTasks instances / TaskNumber
UAT EndpointUrl / LoginUrl
UAT credentials / token / AuthValue
P963xx controlled UAT retry state
```

Schema/config can migrate; UAT runtime history must not.

## Cutover sequence

1. STOP Shipment scheduler in UAT and keep PROD scheduler OFF.
2. Export/backup current UAT Form, IDOs, Custom Assembly, Task Definition, and exact baseline DB definitions using `EXPORT_FROM_UAT_CHECKLIST.md`.
3. Run `query-select/001-prod-preflight.sql`.
4. Migrate missing baseline Shipment objects. For Mongoose-owned custom tables, use **SQL Tables** / metadata tooling and verify standard triggers; do not rely on raw `CREATE TABLE` alone.
5. For clean PROD, create `ue_SMK069_shipment_retry_mst` and `ue_SMK069_shipment_schedule_mst` through **SQL Tables** and verify Mongoose triggers. Skip raw table files 017 and 030. Then run the remaining Apply Database files as required, in order. On a clean PROD built from the exact current UAT `SMK069BuildShipmentJsonSp` baseline captured 2026-09-28, do **not** replay 060/071/073 because those rules are already present in the baseline procedure.
6. Import IDOs and register all required methods on `ue_SMK069ShipmentTransport`.
7. Import/compile the exact current UAT Shipment Custom Assembly.
8. Confirm the `data is exist` rule is present.
9. Create/import Background Task Definition.
10. Import REV8 form.
11. Run file 080 with confirmed PROD URLs; scheduler remains OFF.
12. Run `query-select/002-prod-postdeploy-config.sql`; all rule/config columns should PASS.
13. Open form and confirm Actual TaskMan is NOT REGISTERED before first START.
14. Keep Shipments / Run = 1.
15. Run one controlled Shipment smoke test only after PROD form/IDO/extension behavior is verified against current TRN. Do not assume Patch 19 Run Once bypass is present.
16. Replace `__PROD_DN__` in queries 003/004/005 and verify one real PROD DN end-to-end.
17. Verify API history, retry state, source `Api_post`, and `shipment_mst.SMK069_Uf_api_post`.
18. Verify duplicate response behavior if a safe known duplicate test is available.
19. Verify PRICE <= 0 stops locally and does not create a new Shipment POST.
20. Only after smoke PASS: START SCHEDULER.
21. Verify one new PROD Task Number, REGISTERED/WAITING, 1-minute heartbeat and business schedule enabled.

Do not raise `Shipments / Run` above 1 during the initial PROD observation window. Capacity can be increased later as an explicit operational decision.

## Emergency stop / rollback

Use `ROLLBACK.md` as the operational rollback guide.

Fast path:

1. Use **STOP SCHEDULER** on the form.
2. If the UI cannot be used quickly, run `apply-database/090-emergency-stop.sql`.
3. Refresh until business/master are OFF.
4. If TaskMan is READY/RUNNING, allow the in-flight call to finish, then STOP again once it is WAITING so the recurring instance can be removed.
5. Preserve API/retry logs for diagnosis; do not delete history as rollback.

## Go-live blockers still requiring evidence

Before declaring PROD GO, record evidence for:

- PROD LoginUrl and Shipment EndpointUrl confirmed by POS team.
- PROD credential handling approved.
- exact current UAT Custom Assembly exported/imported.
- exact current UAT baseline DB definitions available if PROD is clean.
- runtime PASS for the extension `data is exist` classification.
- Patch 22 PRICE guard PASS in UAT/target before recurring scheduler activation.
- one controlled real PROD DN RUN ONCE PASS.

The migration pack is designed to fail safely rather than invent missing tenant definitions or endpoint values.
