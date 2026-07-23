# Test Workspace

Folder ini menyimpan payload sintetis, test case, expected result, dan bukti pengujian untuk integrasi POS → SyteLine.

## Structure

```text
tests/
├── README.md
├── test-cases.md
└── payloads/
    ├── minimal-valid.json
    ├── minimal-item-unmapped.json
    └── minimal-negative-qty.json
```

## First PoC Run

Gunakan urutan berikut:

1. buat mapping test untuk `PIZZA001`, `DRINK001`, dan `PIZZA002`;
2. kirim `payloads/minimal-valid.json`;
3. periksa satu inbound, satu batch, dan tiga raw lines;
4. pastikan terdapat dua distinct transactions;
5. pastikan batch total `350000`;
6. kirim payload yang sama lagi tanpa mengubah `idempotencyKey`;
7. pastikan tidak tercipta batch baru;
8. kirim `minimal-item-unmapped.json`;
9. pastikan item tidak dikenal menghasilkan status error dan message yang jelas;
10. tambahkan mapping item tersebut, jalankan retry, lalu pastikan source row tidak dibuat ganda.

## Evidence Folder

Saat eksekusi dimulai, buat folder per run:

```text
tests/evidence/YYYYMMDD-<environment>-<site>/
```

Simpan request, response, screenshot, reconciliation, preview, dan hasil Pass/Fail. Jangan menyimpan token, password, secret, PIN, CVV, atau nomor kartu lengkap.

## Important

Payload pada folder ini adalah data sintetis. Nilai, item, outlet, dan account harus disesuaikan dengan master test tenant sebelum dijalankan.
