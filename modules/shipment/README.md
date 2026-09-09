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
P96331 WAITING_BACKOFF attempt 3/5 sebelumnya DOC_NO kosong
P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
```

Known blockers sekarang:

```text
P96331 missing DOC_NO local Build gate    FIXED + VERIFIED (Patch 14 Rev.2)
Complete nvarchar -> bigint               FIXED + VERIFIED (Patch 15)
Old /inventory/v1/infor_dn route          REPLACED + VERIFIED (Patch 16)
Scheduler automatic sending               HELD OFF (master SchedulerEnabled=0)
Controlled one-DN arm state               PATCH 17 READY
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

Patch 16 does not perform HTTP and does not reset retry counters.

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

## Patch 17 — arm controlled P96331 UAT only

Pre-UAT verification after Patch 16 showed:

```text
HOURLY MaxShipments    NULL
HOURLY IsEnabled       1
HOURLY RunRequested    0
HOURLY RunState        I
P96331 AttemptCount    3
P96331 RetryState      P
P96331 NextAttemptDate Sep 9 2026 9:24AM
```

Therefore the previous form operation did **not** reset P96331 and did not set the per-schedule max to 1.

Patch 17:

```text
database/patches/shipment/2026-09-09-smk069-17-arm-controlled-uat-p96331.sql
```

Documentation/evidence:

```text
docs/shipment/36-controlled-uat-p96331-arm.md
tests/evidence/2026-09-09-smk069-pre-uat-p96331-state.md
```

Patch 17 performs no HTTP. It requires master scheduler OFF and endpoint Patch 16 already active, then sets:

```text
HOURLY MaxShipments    = 1
HOURLY IsEnabled       = 1
HOURLY RunRequested    = 0
HOURLY RunState        = I
HOURLY NextRunDate     = GETDATE() + 1 day

P96331 AttemptCount    = 0
P96331 RetryState      = P
P96331 NextAttemptDate = NULL
```

Why park `NextRunDate` in the future: `SMK069ClaimDueShipmentScheduleSp` treats `NextRunDate IS NULL` or `NextRunDate <= GETDATE()` as due. Without parking it, merely turning master ON could let TaskMan claim HOURLY before the operator explicitly presses Run Now.

Historical LastHttpCode/LastError remain for audit, matching existing Reset Retry semantics.

## Controlled one-DN UAT policy

Do not enable normal scheduling yet.

Before any HTTP run:

```text
1. Apply Patch 17.
2. Verify master remains OFF.
3. Verify HOURLY MaxShipments=1 and NextRunDate is future.
4. Verify P96331 AttemptCount=0, RetryState=P, NextAttemptDate=NULL.
5. Verify queue ranking and confirm P96331 is the first candidate for MaxShipments=1.
```

Only then open the master/run path for one controlled run.

Decision gate:

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

1. Apply Patch 17.
2. Query Select Patch 17 state -> target master OFF, MaxShipments=1, P96331 attempt 0/pending.
3. Query Select candidate ranking -> confirm P96331 is candidate #1.
4. Only then enable the controlled one-run path.
5. Execute one run and immediately review HTTP/body + Complete/API log/retry state/Api_post.
6. Keep/restore master OFF after the one-DN run until results are reviewed.
7. Only after clean evidence decide whether to process P96330/P96332 and re-enable normal schedule.
