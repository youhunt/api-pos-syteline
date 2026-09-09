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

CSV parsing, `ue_SMK069_temp_sales_mst`, dan pembuatan Blanket Customer Order berada di modul `csv-to-co`. Modul CSV hanya boleh dibuka dari sini bila diperlukan untuk dependency data nyata, misalnya Shipment kehilangan `DOC_NO` karena upstream CO tidak ada.

## Runtime utama

```text
View       : dbo.SMK069_ShipmentAPI_mst
Service IDO: ue_SMK069ShipmentTransport
Extension  : SMK069ShipmentTransportExtension
Form       : Shipment Scheduler Control Center
```

Extension class Mongoose harus tetap satu class yang terikat ke `ue_SMK069ShipmentTransport`; jangan membuat extension class kedua untuk IDO yang sama.

## Endpoint dan login

Konfigurasi UAT terakhir:

```text
LoginUrl    = https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl = https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
```

Ada histori ambiguity base path:

```text
/inventory/v1/infor_dn
/inventory-phi/v1/infor_dn
```

Jangan mengganti EndpointUrl tanpa evidence dari POS team atau UAT. HTTP 404 terbaru menunjukkan endpoint/path harus diverifikasi lagi.

## DN contract

DN sekarang adalah string berprefiks, contoh:

```text
P96330
P96331
P96332
```

Patch 11 sudah mengubah `SMK069PrepareShipmentSendSp.@DN_No` menjadi `NVARCHAR(40)`. IDO metadata Prepare juga harus bertipe String.

## Queue terakhir — 9 Sep 2026

```text
P96330 WAITING_BACKOFF attempt 3/5 HTTP 404
  POS API HTTP error 404; Response=404 page not found
  + Complete Shipment exception:
    Error converting data type nvarchar to bigint.
    dbo.SMK069CompleteShipmentSendSp:36

P96331 WAITING_BACKOFF attempt 3/5 HTTP 0
  Shipment DN P96331 tidak mempunyai DOC_NO/Customer Order.

P96332 WAITING_BACKOFF attempt 2/5 HTTP 404
  POS API HTTP error 404; Response=404 page not found
  + Complete Shipment exception:
    Error converting data type nvarchar to bigint.
    dbo.SMK069CompleteShipmentSendSp:36
```

**Jangan membakar sisa retry budget sebelum akar masalah diperbaiki.** Jangan `Reset Retry`, `Run Now`, atau invoke sender manual selama investigation gate ini.

## Audit repo 9 Sep — source drift ditemukan

Repo standalone source tertinggal dari runtime tenant setelah DN berubah menjadi string berprefiks:

```text
database/views/shipment/SMK069_ShipmentAPI_mst.sql
  masih: sh.shipment_id AS DN_No

database/procedures/shipment/SMK069BuildShipmentJsonSp.sql
  masih: @DN_No BIGINT

Patch 11 tenant evidence:
  SMK069BuildShipmentJsonSp.@DN_No = nvarchar

extension-classes/shipment/SMK069ShipmentSenderExtension.cs
  masih source legacy dengan DN long

extension-classes/shipment/SMK069ShipmentSenderExtension.rev3.cs
  sudah string DN, tetapi header-nya sendiri menyatakan harus dibandingkan
  dengan tenant sebelum mengganti source runtime.
```

Artinya file 4 Sep tersebut **bukan current tenant source-of-truth** untuk menebak `SMK069CompleteShipmentSendSp`.

Read-only root-cause capture sudah ditambahkan:

```text
database/patches/shipment/2026-09-09-smk069-13-shipment-root-cause-audit.sql
docs/shipment/31-shipment-root-cause-audit-2026-09-09.md
```

Audit ini tidak mengirim Shipment dan tidak mengubah retry/data. Ia harus dijalankan untuk capture exact tenant definition sebelum patch Complete dibuat.

## Tiga masalah yang harus dipisahkan

### 1. HTTP 404 — P96330 / P96332

Shipment sudah mencapai HTTP transport dan route menjawab `404 page not found`. Verifikasi configured `EndpointUrl` terhadap endpoint POS yang benar sebelum retry.

Jangan melakukan probe dengan Shipment retry. Cocokkan nilai tenant dengan URL POS yang memang pernah terbukti mencapai business response, atau evidence resmi POS team.

### 2. Complete Shipment masih punya BIGINT conversion

`SMK069CompleteShipmentSendSp` masih gagal pada line 36 dengan:

```text
Error converting data type nvarchar to bigint
```

Exact tenant source untuk Complete belum tersimpan di Git. Jangan menebak atau menulis ulang full procedure. Jalankan Patch 13 read-only audit untuk capture:

```text
sys.parameters
OBJECT_DEFINITION
line 36
API log column metadata
```

Setelah actual string→BIGINT crossing terbukti, buat patch minimal seperti Patch 11 dan preserve seluruh body tenant lainnya.

### 3. P96331 tidak punya DOC_NO / Customer Order

Ini data/upstream dependency, bukan HTTP error. Shipment tersebut tidak boleh dikirim sampai source Shipment memiliki `DOC_NO`/CO yang valid.

Cross ke workstream CSV→CO hanya jika tracing membuktikan Customer Order P96331 memang hilang karena upstream POS inbound creation.

## Retry

Shipment yang berada di `WAITING_BACKOFF` dapat diproses ulang **hanya setelah root cause diperbaiki**:

- tunggu `NextAttemptDate`, atau
- gunakan controlled `SMK069ResetShipmentRetrySp` / Reset Retry.

Reset retry tidak menyelesaikan root cause; jangan reset berulang hanya untuk mencoba endpoint yang sama.

Selama incident ini, pastikan scheduler tidak otomatis menghabiskan attempt berikutnya. Patch 13 audit menampilkan `SchedulerEnabled` dan schedule state. Jika masih aktif, hold melalui Shipment Scheduler Control Center sebelum `NextAttemptDate`.

## Scheduler

Scheduler mempunyai:

- master enable;
- schedule enable;
- max batch size / Max per Run;
- retry/backoff;
- Run Now via Background Task;
- dashboard + queue;
- helper wait/auto-refresh dari Patch 12.

TaskMan/HTTP extension method harus NON-TRANSACTIONAL.

## Source utama setelah pemisahan repo

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

## Aturan tenant SyteLine

- Apply Database: satu executable batch, tanpa `GO`.
- Verification SELECT terpisah di Query Select.
- Jangan pakai `System.Data` di extension class; tenant sebelumnya tidak menyediakan reference itu. Gunakan `Context.Commands.Invoke` untuk IDO/SP calls.
- Credentials POS tetap runtime/TaskMan concern, bukan static token config.
- Exact tenant definition harus dicapture ke Git setelah runtime object berubah; source lama tidak boleh dianggap authoritative hanya karena nama object sama.

## Next investigation

**Tidak ada retry sebelum langkah 1–4 selesai.**

1. jalankan `2026-09-09-smk069-13-shipment-root-cause-audit.sql` secara read-only;
2. verify configured `EndpointUrl` terhadap known-good POS evidence;
3. inspect exact tenant `SMK069CompleteShipmentSendSp` definition + parameter metadata + line 36 + API-log column types;
4. patch string handling minimal dan capture exact fixed Complete source ke Git;
5. trace P96331 `DOC_NO`/CO secara terpisah;
6. baru reset **satu** DN yang valid dan UAT dengan Max/Run = 1;
7. verify Prepare → HTTP → Complete → API log → retry state → `Api_post` sebelum memperluas batch.
