# Shipment Outbound → POS API

## Scope

Modul ini hanya menangani **Shipment outbound SyteLine → POS API**:

```text
SMK069_ShipmentAPI_mst
→ Build / Prepare Shipment
→ POS login
→ HTTP POST
→ Complete Shipment
→ Retry / Backoff
→ Scheduler / TaskMan
```

CSV parsing, `ue_SMK069_temp_sales_mst`, dan pembuatan Blanket Customer Order berada di modul `csv-to-co`. Modul CSV hanya boleh dibuka dari sini bila benar-benar diperlukan untuk dependency data Shipment.

## Runtime utama

```text
View       : dbo.SMK069_ShipmentAPI_mst
Service IDO: ue_SMK069ShipmentTransport
Extension  : SMK069ShipmentTransportExtension
Form       : Shipment Scheduler Control Center
```

## Queue incident — 9 Sep 2026

```text
P96330 WAITING_BACKOFF attempt 3/5 HTTP 404
P96331 sebelumnya WAITING_BACKOFF attempt 3/5 karena DOC_NO kosong
P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
```

Known blockers/status sekarang:

```text
P96331 missing DOC_NO local Build gate    FIXED + VERIFIED (Patch 14 Rev.2)
Complete nvarchar -> bigint               FIXED + VERIFIED (Patch 15)
Old /inventory/v1/infor_dn route          REPLACED + VERIFIED (Patch 16)
Scheduler automatic sending               HELD OFF (master SchedulerEnabled=0)
Controlled P96331 arm state               VERIFIED (Patch 17)
```

## Endpoint — Patch 16 verified

Tenant Query Select setelah Patch 16:

```text
SiteRef             Default
ApiName             SHIPMENT
IsActive            1
SchedulerEnabled    0
LoginUrl            https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl         https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
HttpMethod          POST
ContentType         application/json
SuccessMode         KACS_V1
```

Patch:

```text
database/patches/shipment/2026-09-09-smk069-16-fix-shipment-endpoint-and-hold-scheduler.sql
```

Evidence:

```text
tests/evidence/2026-09-09-smk069-active-shipment-config-before-patch16.md
tests/evidence/2026-09-09-smk069-patch16-endpoint-hold-pass.md
```

## DN contract — current tenant evidence

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Therefore:

```text
P96330 = P963 + shipment_id 30
P96331 = P963 + shipment_id 31
P96332 = P963 + shipment_id 32
```

**P96330 bukan shipment_id 96330.**

## Patch 14 Revision 2 — missing DOC_NO non-blocking

Tenant verification:

```text
DN_No_Type        DocNoNonBlocking   EmptyStringJson
nvarchar          PASS               PASS
```

Missing DOC_NO no longer hard-stops Build; JSON becomes `"DOC_NO":""` when still blank. Multiple distinct nonblank DOC_NO protection remains active.

Patch/evidence:

```text
database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql
docs/shipment/32-shipment-missing-doc-no-nonblocking.md
tests/evidence/2026-09-09-smk069-patch14-docno-nonblocking-pass.md
```

## Patch 15 — Complete Shipment string DN fix

Patch 15 separates external DN text from internal numeric shipment key:

```text
@ShipmentDn NVARCHAR(40) -> P96330
@ShipmentId BIGINT       -> 30
```

Tenant verification:

```text
Patch15Marker               OldBigintAssignmentRemoved   StringDnPresent
PASS                        PASS                         PASS
```

Patch/source/evidence:

```text
database/patches/shipment/2026-09-09-smk069-15-fix-complete-shipment-dn-string.sql
database/procedures/shipment/SMK069CompleteShipmentSendSp.tenant-2026-09-09.sql
database/procedures/shipment/SMK069CompleteShipmentSendSp.sql
docs/shipment/34-complete-shipment-prefixed-dn-fix.md
tests/evidence/2026-09-09-smk069-patch15-complete-dn-pass.md
```

## Patch 17 — controlled P96331 UAT arm verified

Patch:

```text
database/patches/shipment/2026-09-09-smk069-17-arm-controlled-uat-p96331.sql
```

Tenant verification after Patch 17:

```text
MasterEnabled     0
EndpointUrl       https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
ScheduleCode      HOURLY
MaxShipments      1
ScheduleEnabled   1
RunRequested      0
RunState          I
NextRunDate       Sep 10 2026 10:35AM
ShipmentId        P96331
AttemptCount      0
RetryState        P
NextAttemptDate   NULL
LastHttpCode      0
```

Interpretation:

- master remains OFF;
- endpoint Patch 16 remains active;
- one-run cap is 1;
- HOURLY is not requested/running;
- NextRunDate is parked in the future;
- P96331 has been reset to pending attempt 0;
- no HTTP was sent by Patch 17.

Documentation/evidence:

```text
docs/shipment/36-controlled-uat-p96331-arm.md
tests/evidence/2026-09-09-smk069-pre-uat-p96331-state.md
tests/evidence/2026-09-09-smk069-patch17-arm-state-pass.md
```

## Controlled one-DN UAT policy

Before any HTTP run, one final gate remains: verify the actual first candidate under `SMK069GetPendingShipmentsSp` ordering:

```text
AttemptCount ASC
NextAttemptDate ASC
ShipmentId ASC
```

With `MaxShipments=1`, the first row is the only DN that will be attempted. Do not enable master / Run Now until P96331 is proven to be candidate #1.

Decision gate after one-DN send:

```text
HTTP 404 again
  -> STOP; do not consume P96330/P96332

HTTP reaches POS business response
  -> endpoint route is proven; inspect business response

Business success
  -> verify Complete -> API log -> retry state -> shipment_mst.SMK069_Uf_api_post
```

## Scheduler / form

Control Center exposes:

```text
Master Scheduler ON/OFF
Default Max / Run
Max Attempts
Schedule Max Shipments / Run
Schedule Active
Run Now
Retry Queue / Reset Retry
```

`Run Now` only marks the selected schedule due; secure background TaskMan owns POS credentials.

TaskMan/HTTP extension method must remain NON-TRANSACTIONAL.

## Tenant Query Select limitations confirmed

```text
pure SELECT only
no DECLARE
no SET
no EXEC
no BEGIN/END
no GO
no plain ORDER BY
no trailing semicolon
short output values only
```

`ORDER BY` is only safe in this form when SQL Server permits it inside the wrapper, e.g. together with `TOP`.

## Source utama

```text
database/patches/shipment/
database/procedures/shipment/
database/views/shipment/
database/shipment/
extension-classes/shipment/
forms/shipment/
ido/shipment/
docs/shipment/
implementation/shipment/
```

Patch 05 and Patch 06 under `database/patches/shipment/withdrawn/` must not be run.

## Next steps

1. Query Select candidate ranking and confirm P96331 is candidate #1.
2. Only then enable master and request exactly one HOURLY run.
3. Execute one controlled run and immediately review HTTP/body + Complete/API log/retry state/Api_post.
4. Keep/restore master OFF after the one-DN run until results are reviewed.
5. Only after clean evidence decide whether to process P96330/P96332 and re-enable normal schedule.
