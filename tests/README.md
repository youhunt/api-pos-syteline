# Test Evidence Router

Folder `tests/` berisi evidence historis dari dua workstream. Untuk menghindari churn besar pada bukti UAT lama, file evidence historis **belum dipindahkan secara fisik** pada reorg 9 Sep 2026.

Gunakan routing berikut:

## CSV → CO / inbound

Secara umum:

- evidence Jul–Aug tentang inbound, staging, customer validation, `CreateCoAndLines`, Customer Order, CSV/import;
- payload `minimal-*`;
- test case Customer Order / inbound.

## Shipment

Secara umum:

- evidence mulai 3 Sep yang nama filenya memuat `shipment`, `kacs`, `scheduler`, `taskman`, atau `dashboard`;
- payload `dn*` dan `shipment-*`;
- tools `Get-SmkShipmentPayload.ps1` dan `Test-Kacs*.ps1`.

## Aturan baru

Test/evidence baru harus dibuat pada:

```text
tests/csv-to-co/
tests/shipment/
```

Legacy evidence dibiarkan di lokasi lama supaya referensi histori/commit tidak berubah lebih banyak dari yang diperlukan.
