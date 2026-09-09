# SMK069 POS ↔ SyteLine Integration

Repository ini sekarang dipisahkan menjadi **dua workstream yang independen** agar perubahan, UAT, patch SQL, IDO, form, dan diskusi tidak saling tercampur.

## 1. CSV / POS Inbound → Blanket Customer Order

Masuk dari CSV atau JSON/Postman, lalu diproses sampai membuat **Blanket Customer Order type `B`**.

Baca mulai dari:

- [`modules/csv-to-co/README.md`](modules/csv-to-co/README.md)
- [`modules/csv-to-co/CHAT-STARTER.md`](modules/csv-to-co/CHAT-STARTER.md)
- [`docs/csv-to-co/30-csv-to-customer-order-one-hit.md`](docs/csv-to-co/30-csv-to-customer-order-one-hit.md)

Batas modul:

```text
CSV / POS JSON
→ Receive / Validate
→ ue_SMK069_temp_sales_mst
→ SMK069ProcessBatchCustomerOrdersSp
→ SMK069ProcessCustomerOrderSp
→ co_mst + coitem_mst + co_bln_mst
```

## 2. Shipment Outbound → POS API

Mengambil Shipment SyteLine, membangun payload, mengirim ke API POS, mencatat hasil, retry/backoff, dan scheduler/TaskMan.

Baca mulai dari:

- [`modules/shipment/README.md`](modules/shipment/README.md)
- [`modules/shipment/CHAT-STARTER.md`](modules/shipment/CHAT-STARTER.md)
- [`docs/shipment/29-shipment-scheduler.md`](docs/shipment/29-shipment-scheduler.md)

Batas modul:

```text
SMK069_ShipmentAPI_mst
→ Prepare Shipment
→ HTTP POST POS
→ Complete Shipment
→ Retry / Backoff
→ Shipment Scheduler
```

## Aturan batas modul

1. **CSV → CO tidak boleh menggunakan source/mapping Shipment.**
2. **Shipment tidak boleh menggunakan inbound POS mapping sebagai reverse mapping.**
3. Patch baru wajib masuk ke salah satu folder:
   - `database/patches/csv-to-co/`
   - `database/patches/shipment/`
   - `database/patches/shared/` hanya jika benar-benar dipakai dua modul.
4. Extension class, form, IDO, procedure, dokumentasi, dan implementation note baru juga wajib ditempatkan pada subfolder modul masing-masing.
5. Dokumen handoff lama yang mencampur dua modul disimpan sebagai **archive/history**, bukan continuation source utama.

## Struktur utama

```text
modules/
├── csv-to-co/
└── shipment/

docs/
├── csv-to-co/
├── shipment/
├── shared/
└── archive/

database/
├── patches/
│   ├── csv-to-co/
│   ├── shipment/
│   │   └── withdrawn/
│   └── shared/
├── procedures/
│   ├── csv-to-co/
│   └── shipment/
├── stored-procedures/
│   └── csv-to-co/
├── tables/
│   ├── csv-to-co/
│   └── shared/
└── views/
    └── shipment/

extension-classes/
├── csv-to-co/
└── shipment/

forms/
├── csv-to-co/
└── shipment/

ido/
├── csv-to-co/
└── shipment/

implementation/
├── csv-to-co/
└── shipment/
```

## Shared history

`CHANGELOG.md`, sebagian `tests/`, dan dokumen archive tetap menyimpan sejarah lintas workstream. Untuk development baru, **jangan mulai dari dokumen history campuran**; mulai dari README modul masing-masing.

Repository: `youhunt/api-pos-syteline`
