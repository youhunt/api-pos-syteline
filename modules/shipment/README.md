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
  Complete exception: nvarchar -> bigint

P96331 WAITING_BACKOFF attempt 3/5 HTTP 0
  sebelumnya berhenti karena DOC_NO kosong

P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
  POS API HTTP error 404; Response=404 page not found
  Complete exception: nvarchar -> bigint
```

**Jangan Reset Retry / Run Now sampai endpoint 404 dibereskan.**

## Endpoint dan login

Konfigurasi UAT terakhir yang tercatat:

```text
LoginUrl    = https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl = https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
```

Ada histori ambiguity:

```text
/inventory/v1/infor_dn
/inventory-phi/v1/infor_dn
```

HTTP 404 terbaru berarti route aktif harus diverifikasi dari tenant + evidence POS yang benar sebelum retry.

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

## Patch 15 — Complete Shipment string DN fix

Root cause Complete sudah dibuktikan dari exact tenant source.

Pre-fix source:

```sql
DECLARE @ShipmentId BIGINT;

SELECT
    @ShipmentId = ShipmentId
FROM dbo.ue_SMK069_shipment_api_log_mst
```

Karena `ShipmentId` pada log sekarang berisi `P96330`/`P96332`, SQL Server melakukan implicit conversion `nvarchar -> bigint` dan gagal.

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

Historical numeric-only log tetap didukung melalui `TRY_CONVERT(BIGINT, @ShipmentDn)` fallback.

Patch 15 tidak mengubah endpoint, tidak Reset Retry, dan tidak melakukan HTTP call.

### Verification Patch 15 — Query Select

Tenant Query Select membungkus supplied SQL. Gunakan pure SELECT, tanpa `ORDER BY`, tanpa trailing `;`:

```sql
SELECT
    CASE
        WHEN CHARINDEX(
            N'SMK069-COMPLETE-DN-STRING-R1',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')), N'')
        ) > 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS Patch15Marker,
    CASE
        WHEN CHARINDEX(
            N'@ShipmentId = ShipmentId',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')), N'')
        ) = 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS OldBigintAssignmentRemoved,
    CASE
        WHEN CHARINDEX(
            N'@ShipmentDn',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')), N'')
        ) > 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS StringDnPresent
```

Expected:

```text
PASS | PASS | PASS
```

## Current blocker matrix

```text
P96331 missing DOC_NO local Build gate    FIXED by Patch 14 Rev.2
Complete nvarchar -> bigint               PATCH 15 ready to apply/verify
HTTP 404 page not found                   STILL OPEN
```

Jadi walaupun Patch 15 sudah PASS, **belum boleh retry** sampai HTTP 404 route dikonfirmasi/diperbaiki.

## Retry policy

Setelah endpoint dan Complete path bersih:

```text
Max/Run = 1
Reset ONE DN only
Controlled UAT
```

P96331 boleh menjadi kandidat pertama karena local DOC_NO blocker sudah dihilangkan.

Verify seluruh flow:

```text
Prepare
→ HTTP
→ Complete
→ API log
→ retry state
→ shipment_mst.SMK069_Uf_api_post
```

Jangan reset semua DN sekaligus.

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

1. Apply Patch 15.
2. Query Select Patch 15 -> target PASS/PASS/PASS.
3. Capture current active Shipment `EndpointUrl` dari tenant.
4. Cocokkan route dengan known-good POS evidence; fix HTTP 404 tanpa membakar retry.
5. Set Max/Run = 1.
6. Reset satu DN saja.
7. Controlled UAT dan verify full lifecycle.
