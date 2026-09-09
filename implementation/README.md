# Implementation Notes Router

Implementation notes sekarang dikelompokkan per workstream:

```text
implementation/csv-to-co/
implementation/shipment/
```

Nomor file tetap dipertahankan sebagai chronology development, tetapi **folder domain adalah boundary utama**.

- CSV/JSON inbound, validation, staging, Customer Order, partial success, CSV POS-402 → `csv-to-co`
- Shipment sender, KACS/POS transport, scheduler, dashboard, TaskMan, retry → `shipment`

Untuk development baru, buat note langsung pada folder modul yang sesuai. Jangan menambah note campuran di root `implementation/`.
