# Patch 23 — Superseded by Patch 24

## Status

Patch 23 yang sebelumnya menambah field terpisah `syteline_co_num` **dibatalkan sebelum menjadi arah final**.

Keputusan bisnis 16 Sep 2026 adalah:

```text
ue_SMK069_temp_sales_mst.co_num = nomor Customer Order SyteLine aktual setelah berhasil diproses
cust_po                         = business linkage utama
R...                            = hanya transient pre-process selector lama
```

Karena itu active patch:

```text
database/patches/csv-to-co/2026-09-16-smk069-23-persist-syteline-co-number.sql
```

telah ditarik dari active patch set.

Jangan apply Patch 23 pada tenant yang belum pernah menerapkannya.

Jika Patch 23 sudah terlanjur pernah diterapkan di suatu tenant, Patch 24 tetap kompatibel: field legacy `syteline_co_num`, bila ada, hanya disinkronkan dengan `co_num`; field tersebut tidak lagi menjadi source of truth.

Lanjutkan ke:

```text
docs/csv-to-co/39-final-co-number-custpo-release-date.md
database/patches/csv-to-co/2026-09-16-smk069-24-co-number-custpo-release-date.sql
```
