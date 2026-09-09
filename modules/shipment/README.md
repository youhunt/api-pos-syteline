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
  POS API HTTP error 404; Response=404 page not found
  Complete exception: nvarchar -> bigint (FIXED by Patch 15)

P96331 WAITING_BACKOFF attempt 3/5 HTTP 0
  sebelumnya berhenti karena DOC_NO kosong (FIXED by Patch 14 Rev.2)

P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
  POS API HTTP error 404; Response=404 page not found
  Complete exception: nvarchar -> bigint (FIXED by Patch 15)
```

## Endpoint evidence + Patch 16

Tenant Query Select before Patch 16 returned:

```text
SiteRef          Default
ApiName          SHIPMENT
IsActive         1
SchedulerEnabled 1
LoginUrl         https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl      https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
HttpMethod       POST
ContentType      application/json
SuccessMode      KACS_V1
```

P96330/P96332 using that active route returned:

```text
HTTP 404
Response=404 page not found
```

Repo evidence from 7 Sep preserves two POS-provided `infor_dn` candidates:

```text
https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
```

and records that one `infor_dn` attempt reached POS business validation (`1010 data is exist`). Because the currently active `/inventory/v1/infor_dn` is now proven to return route-level 404, Patch 16 moves UAT to the remaining documented candidate:

```text
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
```

Patch:

```text
database/patches/shipment/2026-09-09-smk069-16-fix-shipment-endpoint-and-hold-scheduler.sql
```

Documentation/evidence:

```text
docs/shipment/35-shipment-endpoint-404-fix-and-controlled-retry.md
tests/evidence/2026-09-09-smk069-active-shipment-config-before-patch16.md
```

Patch 16 also sets:

```text
SchedulerEnabled = 0
```

as a safety hold. It does **not** perform HTTP, Reset Retry, or alter retry counters.

Repo `SMK069ShipmentSenderExtension.rev3.cs` shows the batch sender reads `endpointUrl` from configuration and passes it directly to `SMK069SendOneShipment`; therefore the batch path can be corrected in config without rebuilding the extension.

## DN contract — current tenant evidence

DN adalah string berprefiks. Query Select current View pada 9 Sep menghasilkan:

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Sehingga:

```text
P96330 = P963 + shipment_id 30
P96331 = P963 + shipment_id 31
P96332 = P963 + shipment_id 32
```

**P96330 bukan shipment_id 96330.**

Patch 11 sudah mengubah `SMK069PrepareShipmentSendSp.@DN_No` menjadi `NVARCHAR(40)` dan IDO metadata Prepare harus String.

## Patch 14 Revision 2 — missing DOC_NO non-blocking

Patch:

```text
database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql
docs/shipment/32-shipment-missing-doc-no-nonblocking.md
```

Tenant verification:

```text
DN_No_Type        DocNoNonBlocking   EmptyStringJson
nvarchar          PASS               PASS
```

Artinya P96331 tidak lagi berhenti hanya karena `DOC_NO` kosong. Build tetap membentuk JSON dengan:

```json
"DOC_NO": ""
```

Proteksi multiple distinct DOC_NO tetap aktif.

Evidence:

```text
tests/evidence/2026-09-09-smk069-patch14-docno-nonblocking-pass.md
```

## Patch 15 — Complete Shipment string DN fix

Root cause Complete sudah dibuktikan dari exact tenant source.

Pre-fix source:

```sql
DECLARE @ShipmentId BIGINT;

SELECT
    @ShipmentId = ShipmentId
FROM dbo.ue_SMK069_shipment_api_log_mst
```

Karena `ShipmentId` pada log berisi `P96330`/`P96332`, SQL Server melakukan implicit conversion `nvarchar -> bigint` dan gagal.

Patch:

```text
database/patches/shipment/2026-09-09-smk069-15-fix-complete-shipment-dn-string.sql
```

Source:

```text
database/procedures/shipment/SMK069CompleteShipmentSendSp.tenant-2026-09-09.sql  # pre-fix tenant capture
database/procedures/shipment/SMK069CompleteShipmentSendSp.sql                    # fixed canonical source
```

Documentation:

```text
docs/shipment/34-complete-shipment-prefixed-dn-fix.md
```

Patch 15 memisahkan:

```text
@ShipmentDn NVARCHAR(40) -> P96330
@ShipmentId BIGINT       -> 30
```

Numeric `shipment_id` di-resolve menggunakan contract current View:

```text
PLG     -> P963 + shipment_id
non-PLG -> R975 + shipment_id
```

### Tenant verification Patch 15 — PASS

```text
Patch15Marker               OldBigintAssignmentRemoved   StringDnPresent
PASS                        PASS                         PASS
```

Dengan demikian error berikut dianggap **fixed at stored-procedure layer**:

```text
Error converting data type nvarchar to bigint.
dbo.SMK069CompleteShipmentSendSp:36
```

Evidence:

```text
tests/evidence/2026-09-09-smk069-patch15-complete-dn-pass.md
```

## Current blocker matrix

```text
P96331 missing DOC_NO local Build gate    FIXED + VERIFIED (Patch 14 Rev.2)
Complete nvarchar -> bigint               FIXED + VERIFIED (Patch 15)
HTTP 404 / active route                   PATCH 16 READY — endpoint switch + scheduler hold
```

## Controlled retry policy after Patch 16 verification

Do **not** re-enable scheduler immediately.

First verify tenant config:

```text
EndpointUrl      https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
SchedulerEnabled 0
```

Then:

```text
Max/Run = 1
Reset ONE DN only
Controlled UAT
```

Recommended first DN: **P96331**.

Reason: local DOC_NO blocker is fixed; Complete is fixed; it has not yet spent an attempt against the corrected route. If POS rejects `DOC_NO=""`, that becomes direct POS-contract evidence instead of a local SyteLine validation block.

Decision gate:

```text
HTTP 404 again
  -> STOP; do not try another DN

HTTP reaches POS business response
  -> route fixed; inspect business code/response

Business success
  -> verify Complete -> API log -> retry state -> shipment_mst.SMK069_Uf_api_post
```

Do not reset all DN together.

## Scheduler

Scheduler mempunyai:

- master/schedule enable;
- max batch / Max per Run;
- retry/backoff;
- Run Now via Background Task;
- dashboard/queue;
- Patch 12 wait/auto-refresh helper.

TaskMan/HTTP extension method harus NON-TRANSACTIONAL.

## Tenant Query Select limitations confirmed

`SMK Query Select Execution` tenant ini:

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

Untuk source capture panjang, gunakan `SUBSTRING` chunk kecil dan explicit chunk number.

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

Patch 05 dan Patch 06 berada di `database/patches/shipment/withdrawn/` dan **jangan dijalankan**.

## Next steps

1. Apply Patch 16.
2. Query Select config -> endpoint target + SchedulerEnabled=0.
3. Set Max/Run = 1 while scheduler remains held.
4. Reset **P96331 only**.
5. Controlled one-DN UAT.
6. Review HTTP/body + Complete/API log/retry state/Api_post.
7. Only after successful review, decide whether to re-enable scheduler and process P96330/P96332.
