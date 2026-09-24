# Shipment Outbound → POS API

## Scope

Modul ini hanya menangani **Shipment outbound SyteLine → POS API**:

```text
SMK069_ShipmentAPI_mst
→ Build / Prepare Shipment
→ POS login
→ HTTP POST
→ Complete Shipment
→ Retry
→ Scheduler / TaskMan
```

POS inbound / CSV-to-CO berada di modul `csv-to-co` dan tidak boleh dicampur ke workstream ini kecuali ada dependency data yang benar-benar nyata.

## Runtime utama

```text
View          : dbo.SMK069_ShipmentAPI_mst
Service IDO   : ue_SMK069ShipmentTransport
Extension     : SMK069ShipmentTransportExtension
Form          : ue_SMK069ShipmentScheduler
Task          : SMK069ShipmentScheduler
Runtime truth : built-in ActiveBGTasks
```

## Current status — 24 Sep 2026

```text
Patch 14 Rev.2  DOC_NO blank non-blocking            VERIFIED
Patch 15        Complete prefixed DN mapping          VERIFIED
Patch 18        SQL ActiveBGTasks runtime view         WITHDRAWN / NO-OP
Patch 19        RUN ONCE bypass scheduler switches    ACTIVE
Patch 20        STORE_ORDER_NO blank non-blocking     ACTIVE
Patch 21        retry 1 minute / max 1440             VERIFIED PASS
Patch 22        PRICE NULL/0/negative local blocker   CREATED; PROD GO requires target/UAT verification
REV8 Form       retry filters + date/time             CURRENT UX
Duplicate rule  HTTP400/code1010/data is exist        SOURCE PATCH APPLIED BY OPERATOR; runtime PASS still required
```

UAT route in use:

```text
LoginUrl    https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
HttpMethod  POST
SuccessMode KACS_V1
```

The old `/inventory/v1/infor_dn` route must not be reintroduced.

## DN contract

Current tenant evidence:

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Therefore `P96330` means prefix `P963` + internal `shipment_id = 30`; it is **not** numeric key 96330.

## Payload / validation contract

Current Shipment behavior:

```text
DOC_NO blank            -> allowed; JSON sends ""
STORE_ORDER_NO blank    -> allowed; JSON sends ""
BATCH null              -> allowed
EXPIRY_DATE null        -> allowed
PRODUCT_CODE blank      -> blocked locally
PRICE NULL / 0 / < 0    -> blocked locally by Patch 22
shipment_qty <= 0       -> not eligible for send
```

Patch 22 message:

```text
Terdapat detail shipment dengan PRICE kosong atau <= 0. Shipment tidak dikirim ke POS.
```

A local Build validation failure prevents the Shipment POST itself, but the current scheduler attempt lifecycle may still record the run as failed/pending. Do not interpret `HTTP 0` local-validation rows as an HTTP call.

## Success contract

Normal Shipment success:

```text
HTTP 201 + body code 200 + message Success
→ BusinessSuccess = 1
```

Idempotent duplicate success:

```text
Shipment POST stage only
AND SuccessMode = KACS_V1
AND HTTP = 400
AND code = 1010
AND message = "data is exist"
→ BusinessSuccess = 1
→ Complete success
→ api_post = 1
→ RetryState = S
→ NextAttemptDate = NULL
→ LastError = NULL
```

The original HTTP 400 response remains in API history for audit.

Do **not** generalize `code=1010` to all endpoints. Login can also use code 1010 for invalid credentials and must remain a login failure.

Reference:

```text
extension-classes/shipment/SMK069ShipmentDuplicateAlreadyExists.patch
docs/shipment/47-idempotent-data-is-exist-success.md
```

## Retry policy

Current confirmed policy:

```text
MaxAttempts         = 1440
BackoffBaseMinutes  = 1
BackoffCapMinutes   = 1
Business interval   = 1 minute
TaskMan heartbeat   = 1 minute
```

`MaxAttempts` is a per-DN retry budget.

`MaxBatchSize` is only the default/config batch size.

`MaxShipments` / form **Shipments / Run** limits how many DNs one scheduler execution may process. For controlled UAT/initial PROD smoke test keep it at `1`.

## Scheduler runtime truth

Do not infer TaskMan existence from custom table flags.

Use the standard Mongoose IDO:

```text
ActiveBGTasks
FILTERPERM(TaskName = 'SMK069ShipmentScheduler')
```

Runtime interpretation:

```text
0 rows  -> NOT REGISTERED
1 WAITING/RUNNING/READY row -> REGISTERED with actual state
>1 rows -> duplicate scheduler warning
```

Do not create a custom SQL replacement for `ActiveBGTasks`.

## START / STOP / RUN ONCE

Current one-form behavior:

```text
START:
  if no matching TaskMan instance exists
  -> create recurring SMK069ShipmentScheduler
  -> configure 1-minute heartbeat
  -> verify exactly one ActiveBGTasks row
  -> enable business schedule/master

STOP:
  -> master OFF first
  -> business schedule OFF
  -> remove matching WAITING recurring instance
  -> if READY/RUNNING, let in-flight execution finish and STOP again when WAITING

RUN ONCE (AUTO SAVE):
  -> saves schedule fields first
  -> requests one manual run
  -> can run while recurring master/business switches are OFF
```

A recurring TaskMan captures credentials/recurrence when it is created. Changing credentials or heartbeat in the form does **not** rewrite an existing recurring task; STOP until NOT REGISTERED, then START to recreate it.

## REV8 form

Current UI generation source:

```text
tools/shipment/upgrade_scheduler_rev8_filters_datetime.py
docs/shipment/46-rev8-retry-filter-and-datetime.md
```

Retry tab:

```text
OPEN       -> RetryState <> S
SUCCESS    -> S
EXHAUSTED  -> X
ALL        -> all states
DN filter  -> partial ShipmentId
```

Successful retry rows are retained for audit; they are only hidden by the default OPEN filter.

Operational timestamps display date **and** time.

## Credentials

Sanitized form artifacts use:

```text
__POS_USERNAME__
__POS_PASSWORD__
```

Real values must never be committed.

`Hidden=True` and TaskMan parameters are **not encryption**. Production credential handling requires an approved operational/security approach. Do not store a production password in GitHub, SQL migration scripts, API logs, or visible task diagnostics.

## PROD migration

The dedicated production package is authoritative for PROD cutover:

```text
deployment/shipment/prod/README.md
deployment/shipment/prod/apply-database/
deployment/shipment/prod/query-select/
```

Key rules:

- historical UAT patches 16/17 must not be used as a PROD run list;
- Patch 18 remains withdrawn;
- PROD URL values are intentionally placeholders until confirmed by the POS team;
- config is prepared in **safe OFF** state;
- initial PROD `Shipments / Run = 1`;
- do not copy UAT retry/API-log/ActiveBGTasks runtime rows into PROD;
- perform one controlled PROD RUN ONCE before enabling recurring scheduling.

Emergency stop:

```text
deployment/shipment/prod/apply-database/090-emergency-stop.sql
```

## Source-control readiness warning

The repository contains patch history and a PROD incremental migration pack, but not every original Shipment baseline object is yet preserved as an authoritative standalone current UAT definition.

Known source-control gaps include the exact current tenant definition/source for some of:

```text
dbo.SMK069_ShipmentAPI_mst
dbo.SMK069BuildShipmentJsonSp
dbo.SMK069PrepareShipmentSendSp
dbo.ue_SMK069_shipment_api_log_mst
current compiled Shipment extension source/assembly
```

Therefore, for a **clean PROD tenant**, export the exact current UAT definitions/artifacts before cutover. Do not reconstruct them from stale historical standalone files.

See:

```text
database/shipment/SMK069_SHIPMENT_SOURCE_INVENTORY.md
deployment/shipment/prod/README.md
```

## Tenant execution limitations

### Apply Database

```text
one executable batch/object per submission
NO GO
```

### SMK Query Select Execution

```text
pure SELECT only
no DECLARE
no SET
no EXEC
no BEGIN/END
no GO
no trailing semicolon
avoid plain trailing ORDER BY
keep large result cells short
```

## PROD GO gate

Before recurring PROD activation, require evidence for all of these:

```text
PROD LoginUrl confirmed
PROD Shipment EndpointUrl confirmed
production credential handling approved
exact current UAT baseline exports available/imported as needed
exact current UAT Shipment custom assembly compiled in PROD
data-is-exist idempotent rule runtime PASS
Patch 22 PRICE guard PASS
post-deploy config Query Select PASS
one real PROD DN controlled RUN ONCE PASS
ActiveBGTasks shows exactly one new PROD recurring task after START
```

Do not increase `Shipments / Run` above 1 until the initial PROD observation window has passed and capacity is explicitly approved.
