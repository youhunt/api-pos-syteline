# Chat Starter — Shipment Outbound

Copy seluruh prompt berikut ke chat baru agar pembahasan Shipment tidak bercampur dengan CSV → CO:

```text
Kita lanjut project private GitHub `youhunt/api-pos-syteline`, tetapi CHAT INI KHUSUS WORKSTREAM:

SHIPMENT OUTBOUND SYTELINE → POS API

Jangan membawa pembahasan CSV parsing, CSV Test Console, temp_sales, atau Blanket Customer Order ke chat ini kecuali saya secara eksplisit memintanya atau memang diperlukan untuk dependency data Shipment seperti DOC_NO/Customer Order.

Repository sudah dipisahkan. Mulai dari:
- modules/shipment/README.md
- docs/shipment/
- database/patches/shipment/
- database/procedures/shipment/
- database/views/shipment/
- extension-classes/shipment/
- forms/shipment/
- ido/shipment/
- implementation/shipment/

Flow:
SMK069_ShipmentAPI_mst → Build/Prepare → POS login → HTTP POST → Complete → Retry/Backoff → Scheduler/TaskMan.

Runtime penting:
- Service IDO: ue_SMK069ShipmentTransport
- Extension: SMK069ShipmentTransportExtension
- DN_No sekarang STRING seperti P96330.
- Patch 11 sudah memperbaiki SMK069PrepareShipmentSendSp.@DN_No menjadi NVARCHAR(40).
- Jangan reintroduce System.Data; gunakan Context.Commands.Invoke.

Endpoint UAT terakhir:
- Login: https://api-uat.pizzahut.co.id/service-auth/login-once
- Shipment config: https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
- Namun base path sebelumnya masih diperdebatkan dengan /inventory-phi/v1/infor_dn. Jangan ganti endpoint tanpa evidence.

Queue terakhir 9 Sep 2026:
P96330 | WAITING_BACKOFF | attempt 3/5 | HTTP 404
  POS API HTTP error 404; Response=404 page not found
  Complete Shipment exception: Error converting data type nvarchar to bigint.:dbo.SMK069CompleteShipmentSendSp:36

P96331 | WAITING_BACKOFF | attempt 3/5 | HTTP 0
  Shipment DN P96331 tidak mempunyai DOC_NO/Customer Order.

P96332 | WAITING_BACKOFF | attempt 2/5 | HTTP 404
  POS API HTTP error 404; Response=404 page not found
  Complete Shipment exception: Error converting data type nvarchar to bigint.:dbo.SMK069CompleteShipmentSendSp:36

Jangan retry dulu sampai root cause diperbaiki karena attempt budget maksimum 5.

Tiga investigation terpisah:
1. P96330/P96332: verify EndpointUrl karena HTTP 404.
2. SMK069CompleteShipmentSendSp: masih ada nvarchar→bigint di line 36. Exact tenant definition belum source-controlled; inspect/capture definition + sys.parameters dulu, lalu patch minimal. Jangan reconstruct full SP dari ingatan.
3. P96331: source data tidak punya DOC_NO/Customer Order; ini upstream data issue, bukan transport issue.

Setelah fix, retry controlled satu DN saja (Max/Run=1) melalui Reset Retry atau tunggu backoff.

Scheduler:
- master/schedule enable
- max batch / Max per Run
- retry/backoff
- Run Now memakai Background Task
- dashboard/queue
- Patch 12 helper wait/auto-refresh

Keterbatasan tenant:
- Apply Database bukan SSMS; patch harus satu executable batch dan tanpa GO.
- Verification SELECT dilakukan terpisah di Query Select.

Cara kerja yang saya inginkan:
1. Audit source repo dan evidence tenant dulu.
2. Kalau ada bug, patch langsung ke GitHub `main`.
3. Jangan invent schema/endpoint yang belum terbukti.
4. Setelah patch laporkan Commit SHA, file berubah, ringkasan, cara apply/test, SQL/migration bila ada.
5. Update dokumentasi repo setiap fix.

Lanjutkan dari error Shipment terbaru yang saya kirim setelah prompt ini.
```
