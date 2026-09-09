# Database Patch Router

Patch SQL dipisahkan berdasarkan domain runtime.

## CSV → Blanket CO

Folder:

```text
database/patches/csv-to-co/
```

Active chain saat ini mencakup:

```text
2026-09-04-smk069-01-create-process-batch-customer-orders.sql
2026-09-04-smk069-02-patch-receive-and-process.sql
2026-09-04-smk069-03-patch-run-csv-test-batch.sql
2026-09-07-smk069-04-public-receive-multi-error.sql
2026-09-09-smk069-13-fix-csv-detail-siteref-before-one-hit.sql
```

## Shipment

Folder:

```text
database/patches/shipment/
```

Mencakup production-readiness audit, scheduler Patch 07–12, DN string fix, dashboard/queue views, dan patch Shipment berikutnya.

### Withdrawn Shipment patches

Folder:

```text
database/patches/shipment/withdrawn/
```

Patch 05 dan 06 disimpan hanya sebagai histori dan **JANGAN DIJALANKAN**.

## Shared

Folder:

```text
database/patches/shared/
```

Hanya untuk perubahan yang memang dipakai lintas dua domain, misalnya site-context hardening umum.

## Aturan Apply Database

Tenant `Apply Database` bukan SSMS. Untuk patch baru:

- desain sebagai satu executable batch;
- jangan gunakan `GO`;
- jangan gabungkan verification SELECT ke deployment bila UI tenant tidak mendukungnya;
- verification dilakukan terpisah melalui Query Select;
- jangan menulis ulang full tenant procedure bila exact installed definition belum source-controlled; buat patch minimal setelah evidence tenant tersedia.
