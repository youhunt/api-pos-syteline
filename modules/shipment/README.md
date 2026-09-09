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

Jangan membakar sisa retry budget sebelum akar masalah diperbaiki.

## Tiga masalah yang harus dipisahkan

### 1. HTTP 404 — P96330 / P96332

Shipment sudah mencapai HTTP transport dan route menjawab `404 page not found`. Verifikasi configured `EndpointUrl` terhadap endpoint POS yang benar sebelum retry.

### 2. Complete Shipment masih punya BIGINT conversion

`SMK069CompleteShipmentSendSp` masih gagal pada line 36 dengan:

```text
Error converting data type nvarchar to bigint
```

Exact tenant source untuk Complete belum tersimpan di Git. Jangan menebak atau menulis ulang full procedure. Capture/inspect tenant definition dan parameter/column types dulu, lalu buat patch minimal seperti Patch 11 untuk Prepare.

### 3. P96331 tidak punya DOC_NO / Customer Order

Ini data/upstream dependency, bukan HTTP error. Shipment tersebut tidak boleh dikirim sampai source Shipment memiliki `DOC_NO`/CO yang valid.

## Retry

Shipment yang berada di `WAITING_BACKOFF` dapat diproses ulang setelah root cause diperbaiki:

- tunggu `NextAttemptDate`, atau
- gunakan controlled `SMK069ResetShipmentRetrySp` / Reset Retry.

Reset retry tidak menyelesaikan root cause; jangan reset berulang hanya untuk mencoba endpoint yang sama.

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

## Next investigation

Sebelum retry P96330/P96332:

1. verify configured EndpointUrl;
2. inspect exact tenant `SMK069CompleteShipmentSendSp` definition + parameter metadata + line 36 conversion;
3. patch string handling minimal;
4. baru reset satu DN dan UAT dengan Max/Run = 1.
