# Patch 23 — Superseded by Patch 24 + Patch 25

## Status

Patch 23 yang sebelumnya menambah field terpisah `syteline_co_num` **dibatalkan sebelum menjadi arah final**.

Keputusan bisnis 16 Sep 2026 adalah:

```text
ue_SMK069_temp_sales_mst.co_num = nomor Customer Order SyteLine aktual setelah berhasil diproses
cust_po                         = business linkage utama
R...                            = hanya transient/legacy compatibility value
```

Karena itu patch berikut sudah ditarik dari active patch set:

```text
database/patches/csv-to-co/2026-09-16-smk069-23-persist-syteline-co-number.sql
```

Jangan apply Patch 23 pada tenant yang belum pernah menerapkannya.

Jika Patch 23 sudah terlanjur pernah diterapkan di suatu tenant, field legacy `syteline_co_num` bukan lagi source of truth.

Lanjutkan dengan active final sequence:

```text
database/patches/csv-to-co/2026-09-16-smk069-24-co-number-custpo-release-date.sql
database/patches/csv-to-co/2026-09-16-smk069-25-canonical-custpo-linkage.sql
```

Dokumentasi final:

```text
docs/csv-to-co/39-final-co-number-custpo-release-date.md
```

Patch 24 mengatur nomor CO final `PYYMMDD###`, staging `co_num`, dan Release Date. Patch 25 memastikan downstream processing benar-benar memakai `cust_po` sebagai business/process key dan tidak lagi membawa legacy `R...` pada Batch → per-order flow.