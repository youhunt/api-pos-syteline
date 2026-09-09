# Documentation Router

Dokumentasi aktif dipisahkan berdasarkan domain:

```text
docs/csv-to-co/   inbound CSV/JSON sampai Blanket Customer Order
docs/shipment/    Shipment outbound, HTTP, retry, scheduler
docs/shared/      konvensi Mongoose/SyteLine yang benar-benar lintas modul
docs/archive/     recap/handoff lama yang mencampur dua domain
```

Untuk sesi baru jangan mulai dari `archive`. Mulai dari:

```text
modules/csv-to-co/README.md
```

atau:

```text
modules/shipment/README.md
```

Nomor file lama tetap dipertahankan agar chronology/history mudah ditelusuri. Setelah reorg, folder domain lebih penting daripada nomor dokumen.
