# SMK069 Shipment — PROD Migration Pack

Prepared: 2026-09-24  
Scope: **Shipment outbound SyteLine -> POS API only**

This folder is the PROD cutover package. It deliberately does **not** include POS inbound / CSV-to-CO objects.

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

Do not rebuild these from the stale historical standalone files.

If PROD already has that baseline, run `query-select/001-prod-preflight.sql` first and use the incremental Apply Database files only where needed.

## Apply Database order

Each file under `apply-database/` is shaped for the Cloud tenant rule: **one executable batch, no GO**.

Run in numeric order:

```text
010..017  scheduler config columns + retry table
020..022  scheduler policy procedures
030..038  schedule table + control/runner procedures
040..041  dashboard/queue views
050       Prepare DN string contract
060       DOC_NO non-blocking
061       Complete prefixed-DN mapping
070       RUN ONCE independent of scheduler switches
071       STORE_ORDER_NO non-blocking
072       fixed 1-minute retry, max 1440
073       block PRICE NULL/0/negative before HTTP
080       PROD URL/config template, safe OFF state
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
2. Export/backup current UAT Form, IDOs, Custom Assembly, Task Definition, and exact baseline DB definitions.
3. Run PROD preflight.
4. Migrate missing baseline Shipment objects.
5. Run Apply Database files 010..073 as required, in order.
6. Import IDOs and register all required methods on `ue_SMK069ShipmentTransport`.
7. Import/compile the exact current UAT Shipment Custom Assembly.
8. Confirm the `data is exist` rule is present.
9. Create/import Background Task Definition.
10. Import REV8 form.
11. Run file 080 with confirmed PROD URLs; scheduler remains OFF.
12. Run `query-select/002-prod-postdeploy-config.sql`; all rule/config columns should PASS.
13. Open form and confirm Actual TaskMan is NOT REGISTERED before first START.
14. Keep Shipments / Run = 1.
15. Run one controlled **RUN ONCE (AUTO SAVE)** while recurring business schedule is still OFF.
16. Verify one real PROD DN end-to-end: payload, API history, retry state, `shipment_mst.SMK069_Uf_api_post`.
17. Verify duplicate response behavior if a safe known duplicate test is available.
18. Verify PRICE <= 0 stops locally and does not create a new Shipment POST.
19. Only after smoke PASS: START SCHEDULER.
20. Verify one new PROD Task Number, REGISTERED/WAITING, 1-minute heartbeat and business schedule enabled.

Do not raise `Shipments / Run` above 1 during the initial PROD observation window. Capacity can be increased later as an explicit operational decision.

## Emergency stop

If any unexpected PROD behavior occurs:

1. Use **STOP SCHEDULER** on the form.
2. If the UI cannot be used quickly, run:
   `apply-database/090-emergency-stop.sql`.
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

The migration pack is designed to fail safely rather than invent missing tenant definitions or endpoint values.
